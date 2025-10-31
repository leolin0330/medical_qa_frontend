import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_client.dart';

class QAPage extends StatefulWidget {
  const QAPage({super.key});

  @override
  State<QAPage> createState() => _QAPageState();
}

class _QAPageState extends State<QAPage> {
  final _api = ApiClient();
  final _qCtrl = TextEditingController();

  String? _lastCollectionId; // 最近一次上傳成功的 collectionId（例如 "_default"）
  String? _uploadMessage; // 顯示上傳結果
  bool _busy = false;

  // 回答顯示
  String? _answer;
  String? _mode; // "doc" / "general"
  List<dynamic>? _sources; // 後端回來的來源清單
  num _costTotal = 0, _costEmbed = 0, _costChat = 0, _costTrans = 0;

  @override
  void dispose() {
    _qCtrl.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    try {
      setState(() => _busy = true);

      final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final name = file.name;
      Uint8List? bytes = file.bytes;
      String? path = file.path;

      // Web → 用 bytes；行動/桌面 → 用 path
      final res = await _api.uploadFile(
        filename: name,
        bytes: kIsWeb ? bytes : null,
        filepath: kIsWeb ? null : path,
        // collectionId: null,  // 留空讓後端回傳 _default
        mode: 'overwrite',
      );

      setState(() {
        _uploadMessage = res['message'] as String?;
        _lastCollectionId = (res['collectionId'] as String?)?.trim();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '上傳完成：${_uploadMessage ?? name}（collectionId: ${_lastCollectionId ?? "-"}）')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ask() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入問題')),
      );
      return;
    }

    try {
      setState(() {
        _busy = true;
        _answer = null;
        _mode = null;
        _sources = null;
        _costTotal = _costEmbed = _costChat = _costTrans = 0;
      });

      final res = await _api.ask(
        query: q,
        topK: 5,
        collectionId: _lastCollectionId, // 只有有值才會真的帶給後端
      );

      setState(() {
        _answer = res['answer'] as String?;
        _mode = res['mode'] as String?;
        _sources = (res['sources'] as List?)?.toList();

        _costTotal = (res['cost_usd'] ?? 0) as num;
        _costEmbed = (res['embedding_cost'] ?? 0) as num;
        _costChat = (res['chat_cost'] ?? 0) as num;
        _costTrans = (res['transcribe_cost'] ?? 0) as num;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提問失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearDocs() {
    setState(() {
      _lastCollectionId = null;
      _uploadMessage = null;
      _sources = null;
      _answer = null;
      _mode = null;
      _costTotal = _costEmbed = _costChat = _costTrans = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除文件狀態（改用一般知識回答）')),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _qCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '輸入問題（例如：糖尿病是什麼？）',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.send),
          label: const Text('送出'),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _pickAndUpload,
          icon: const Icon(Icons.upload_file),
          label: const Text('上傳文件 / 影片'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _clearDocs,
          icon: const Icon(Icons.delete_outline),
          label: const Text('清除文件狀態'),
        ),
        if (_lastCollectionId != null)
          Chip(
            avatar: const Icon(Icons.folder, size: 18),
            label: Text('使用中文件：${_lastCollectionId!}'),
          ),
      ],
    );
  }

  Widget _buildAnswer() {
    if (_answer == null && _uploadMessage == null) {
      return const Text('尚未提問。你可以先上傳文件，或直接提問讓我用一般知識回答。');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_uploadMessage != null) ...[
          Text('上傳結果：${_uploadMessage!}'),
          const SizedBox(height: 6),
        ],
        if (_mode != null) Text('模式：${_mode == "doc" ? "📄 文件模式" : "🧠 一般模式"}'),
        const SizedBox(height: 8),
        if (_answer != null) ...[
          const Text('回答：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SelectableText(_answer!),
          const SizedBox(height: 12),
        ],
        if (_sources != null && _sources!.isNotEmpty) ...[
          const Text('來源（前幾段）：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ..._sources!.map((s) => _SourceTile(s)).toList(),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            _CostTag('total', _costTotal),
            const SizedBox(width: 6),
            _CostTag('embed', _costEmbed),
            const SizedBox(width: 6),
            _CostTag('chat', _costChat),
            const SizedBox(width: 6),
            _CostTag('trans', _costTrans),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width > 640 ? 16.0 : 12.0;
    return Scaffold(
      appBar: AppBar(title: const Text('醫學問答')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _busy ? 0.6 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildToolbar(),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildAnswer(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final Map data;
  const _SourceTile(this.data);

  @override
  Widget build(BuildContext context) {
    final snippet = (data['snippet'] ?? data['text'] ?? '') as String? ?? '';
    final src = (data['source'] ?? '') as String? ?? '';
    final page = data['page'];
    final score = data['score'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (src.isNotEmpty)
              Text('來源：$src',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if (page != null) Text('頁碼：$page'),
            if (score != null) Text('分數：$score'),
            const SizedBox(height: 6),
            Text(snippet),
          ],
        ),
      ),
    );
  }
}

class _CostTag extends StatelessWidget {
  final String label;
  final num value;
  const _CostTag(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(6)}'),
    );
  }
}
