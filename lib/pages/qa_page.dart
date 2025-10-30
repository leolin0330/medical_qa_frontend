import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class QaPage extends StatefulWidget {
  const QaPage({super.key});

  @override
  State<QaPage> createState() => _QaPageState();
}

class _QaPageState extends State<QaPage> {
  final _api = ApiClient();

  // 檔案狀態
  File? _file;               // Android / iOS
  Uint8List? _fileBytes;     // Web
  String? _fileName;         // 顯示檔名

  // UI 狀態
  String? _uploadMsg;
  bool _uploading = false;

  final _qCtrl = TextEditingController();
  String? _answer;
  List<dynamic>? _sources;
  Map<String, dynamic>? _cost; // { total_usd, embed_usd, chat_usd }
  Map<String, dynamic>? _lastUploadCost; // 上次上傳的成本資訊
  List<Map<String, dynamic>> _history = [];
  bool _asking = false;

  String _mode = 'auto';     // auto / doc / general
  String? _collectionId;     // 之後可從「我的」頁帶入
  List<String> _selectedSources=[]; // 若有多來源 UI，就用這個；沒有就保持空

  double? _analysisCost;

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // 選擇檔案（同時支援 Web 與 Android/iOS）
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true, // Web 需要 bytes
    );
    if (result == null) return;

    final f = result.files.single;
    setState(() {
      _fileName = f.name;
      if (kIsWeb) {
        _fileBytes = f.bytes;
        _file = null;
      } else {
        _file = (f.path != null) ? File(f.path!) : null;
        _fileBytes = null;
      }
      _uploadMsg = null;
      _answer = null;
      _sources = null;
      _cost = null;
      _history.clear();
      _lastUploadCost = null;
    });
  }

  // 上傳（Web 走 bytes；行動裝置走 path）
  Future<void> _upload() async {
    if (!kIsWeb && _file == null) return;
    if (kIsWeb && (_fileBytes == null || _fileName == null)) return;

    setState(() => _uploading = true);
    try {
      final resp = await _api.uploadFile(
        file: kIsWeb ? null : _file,
        bytes: kIsWeb ? _fileBytes : null,
        filename: _fileName,
        collectionId: _collectionId,
      );
      setState(() {
        _uploadMsg = '✅ 上傳完成：${resp['message'] ?? 'OK'}';
        final costMap = _parseCost(resp);
        _lastUploadCost = costMap.isNotEmpty ? costMap : null;
      });
    } catch (e) {
      setState(() => _uploadMsg = '❌ 上傳失敗：$e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Map<String, dynamic> _parseCost(Map<String, dynamic> m) {
    final flat = {
      'total_usd': m['cost_usd'] ?? m['total_cost_usd'],
      'embed_usd': m['embedding_cost'] ?? m['embed_cost_usd'],
      'chat_usd': m['chat_cost'] ?? m['chat_cost_usd'],
      'transcribe_cost': m['transcribe_cost'] ?? m['transcribe_cost_usd'],
      'vision_cost': m['vision_cost'] ?? m['vision_cost_usd'],
    }..removeWhere((k, v) => v == null);
    if (flat.isNotEmpty) return flat;
    for (final k in ['cost', 'usage']) {
      final c = m[k];
      if (c is Map) {
        final kk = {
          'total_usd': c['total_usd'] ?? c['total'] ?? c['cost_usd'],
          'embed_usd': c['embed_usd'] ?? c['embedding'] ?? c['embedding_cost'],
          'chat_usd': c['chat_usd'] ?? c['chat'] ?? c['chat_cost'],
          'transcribe_cost': c['transcribe_cost'] ?? c['transcribe'] ?? c['transcribe_cost_usd'],
          'vision_cost': c['vision_cost'] ?? c['vision'] ?? c['vision_cost_usd'],
        }..removeWhere((k, v) => v == null);
        if (kk.isNotEmpty) return kk;
      }
    }
    return {};
  }

// 發問
Future<void> _ask() async {
  final q = _qCtrl.text.trim();
  if (q.isEmpty) return;

  setState(() {
    _asking = true;
    _answer = null;
    _sources = null;
    _cost = null;
  });

  try {
    Map<String, dynamic> resp;
    final parts = q.split(RegExp(r'\s+'));

    if (parts.isNotEmpty && _api.isUrl(parts[0])) {
      // 🔹 URL 模式：不要帶 sources
      final url = parts[0];
      final query = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      resp = await _api.fetchUrl(url: url, query: query, mode: _mode);
    } else {
      // 🔹 一般提問：只有真的有來源時才帶 sources
      List<String>? activeSources;
      if (_selectedSources.isNotEmpty) {
        activeSources = _selectedSources;
      } else if (_collectionId != null && _collectionId!.isNotEmpty) {
        activeSources = [_collectionId!];
      } else {
        activeSources = null; // ← 關鍵：沒有來源就完全不傳
      }

      resp = await _api.ask(
        question: q,
        mode: _mode,
        sources: activeSources, // ← 新增參數
      );
    }

    setState(() {
      final answerText = resp['answer']?.toString();
      final sourcesList = (resp['sources'] as List<dynamic>?) ?? [];
      final costData = _parseCost(resp);
      final combinedCost = { ...?_lastUploadCost, ...costData };

      final total = [
        combinedCost['embed_usd'],
        combinedCost['chat_usd'],
        combinedCost['transcribe_cost'],
        combinedCost['vision_cost'],
      ].whereType<num>().fold(0.0, (sum, v) => sum + v);

      combinedCost['total_usd'] = double.parse(total.toStringAsFixed(6));

      _history.add({'answer': '👤 問：$q', 'sources': [], 'cost': {}});
      _history.add({'answer': answerText, 'sources': sourcesList, 'cost': combinedCost});

      _qCtrl.clear();
    });
  } catch (e) {
    setState(() {
      _history.add({'answer': '❌ 提問失敗：$e', 'sources': [], 'cost': {}});
    });
  } finally {
    setState(() => _asking = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 問答')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----------------- 上傳區 -----------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '上傳文件（PDF / DOCX / PPTX / TXT / HTML）',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(_fileName ?? '尚未選擇檔案'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _uploading ? null : _pickFile,
                        child: const Text('選擇檔案'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            (_fileName == null || _uploading) ? null : _upload,
                        child: _uploading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('上傳'),
                      ),
                    ],
                  ),
                  if (_uploadMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(_uploadMsg!),
                  ],
                  const SizedBox(height: 4),
                  const Text('提示：若為影音請先提供字幕檔（SRT/VTT）。'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ----------------- 問答區 -----------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('提問',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: '輸入問題…'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _mode,
                        items: const [
                          DropdownMenuItem(value: 'auto', child: Text('自動模式')),
                          DropdownMenuItem(value: 'doc', child: Text('僅文件')),
                          DropdownMenuItem(value: 'general', child: Text('一般知識')),
                        ],
                        onChanged: (v) => setState(() => _mode = v ?? 'auto'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _asking ? null : _ask,
                        child: _asking
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('送出'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in _history) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['cost'] != null && (item['cost'] as Map).isNotEmpty) ...[
                        if ((item['cost'] as Map).containsKey('total_usd'))
                          Text('總成本：\$${((item['cost'] as Map)['total_usd'] as num).toStringAsFixed(3)}'),
                        if ((item['cost'] as Map).containsKey('embed_usd'))
                          Text('嵌入成本：\$${((item['cost'] as Map)['embed_usd'] as num).toStringAsFixed(3)}'),
                        if ((item['cost'] as Map).containsKey('chat_usd'))
                          Text('聊天成本：\$${((item['cost'] as Map)['chat_usd'] as num).toStringAsFixed(3)}'),
                        if ((item['cost'] as Map).containsKey('transcribe_cost'))
                          Text('轉錄成本：\$${((item['cost'] as Map)['transcribe_cost'] as num).toStringAsFixed(3)}'),
                        if ((item['cost'] as Map).containsKey('vision_cost'))
                          Text('視覺成本：\$${((item['cost'] as Map)['vision_cost'] as num).toStringAsFixed(3)}'),
                        const SizedBox(height: 6),
                      ],
                      SelectableText(item['answer']?.toString() ?? ''),
                      // if (item['sources'] != null && (item['sources'] as List).isNotEmpty) ...[
                      //   const SizedBox(height: 8),
                      //   const Text('引用來源', style: TextStyle(fontWeight: FontWeight.bold)),
                      //   const SizedBox(height: 6),
                      //   for (final s in (item['sources'] as List))
                      //     _SourceTile(
                      //       data: (s is Map)
                      //           ? s.cast<String, dynamic>()
                      //           : <String, dynamic>{'text': s.toString()},
                      //     ),
                      // ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

// 引用來源項目
class _SourceTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SourceTile({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(cleanSnippet(data['text'] ?? '')),
      subtitle: data['source'] != null ? Text(data['source']) : null,
    );
  }

  String cleanSnippet(String s) {
    if (s.isEmpty) return s;
    var t = s;
    t = t.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    t = t.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    t = t.replaceAll(RegExp(r'[\[\(]\d{2}:\d{2}(?::\d{2})?[\]\)]'), '');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }
}
