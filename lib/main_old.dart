import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const MyApp());
}

/// === 請依執行環境調整 ===
/// - Android 模擬器連本機： http://10.0.2.2:8000
/// - iOS 模擬器連本機：    http://127.0.0.1:8000
/// - 實機連雲端：         你的雲端網址
const String kBaseUrl = 'http://10.0.2.2:8000';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _pickedFile;
  double? _costUsd; // 總成本
  double? _embedCost; // 嵌入階段成本
  double? _chatCost; // 問答階段成本
  bool _uploading = false;
  String _uploadMsg = '';
  String _answer = '';
  final TextEditingController _q = TextEditingController();

  // 依副檔名推測 Content-Type（很重要，避免上傳時都被當成 PDF）
  MediaType _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    if (lower.endsWith('.docx')) {
      return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
    }
    if (lower.endsWith('.pptx')) {
      return MediaType('application',
          'vnd.openxmlformats-officedocument.presentationml.presentation');
    }
    if (lower.endsWith('.txt')) {
      return MediaType('text', 'plain');
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return MediaType('text', 'html');
    }
    return MediaType('application', 'octet-stream');
  }

  Future<void> _pickFile() async {
    setState(() {
      _uploadMsg = '';
      _answer = '';
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'html', 'htm'],
      withData: false,
    );
    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_pickedFile == null) {
      setState(() => _uploadMsg = '請先選擇文件');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadMsg = '上傳中…';
    });

    try {
      final uri = Uri.parse('$kBaseUrl/upload');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          _pickedFile!.path,
          contentType: _guessContentType(_pickedFile!.path),
        ));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _uploadMsg =
              '✅ ${data['message']}（索引段落：${data['paragraphs_indexed']}）';
        });
      } else {
        setState(() {
          _uploadMsg = '❌ 上傳失敗：${resp.statusCode} ${resp.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadMsg = '❌ 例外：$e');
    } finally {
      if (!mounted) return;
      setState(() => _uploading = false);
    }
  }

  Future<void> _ask() async {
    final query = _q.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _answer = '思考中…';
      _costUsd = _embedCost = _chatCost = null;
    });

    try {
      final uri = Uri.parse('$kBaseUrl/ask');
      final req = http.MultipartRequest('POST', uri)
        ..fields['query'] = query
        ..fields['top_k'] = '5'
        ..fields['mode'] = 'auto'; // 有文件走文件；否則一般知識

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _answer = data['answer']?.toString() ?? '(沒有回覆)';
          _costUsd = (data['cost_usd'] is num)
              ? (data['cost_usd'] as num).toDouble()
              : null;
          _embedCost = (data['embedding_cost'] is num)
              ? (data['embedding_cost'] as num).toDouble()
              : null;
          _chatCost = (data['chat_cost'] is num)
              ? (data['chat_cost'] as num).toDouble()
              : null;
        });
      } else {
        setState(() => _answer = '❌ 失敗：${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _answer = '❌ 例外：$e');
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickedName = _pickedFile?.path.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical QA Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) 選檔 + 上傳
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const Text('步驟 1：選擇文件（PDF / DOCX / PPTX / TXT / HTML）',
                  const Text('步驟 1：選擇文件 (可跳過)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('選擇文件'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pickedName ?? '尚未選擇',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _uploadFile,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_uploading ? '上傳中…' : '上傳並建立索引'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadMsg,
                    style: TextStyle(
                      color: _uploadMsg.startsWith('✅')
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2) 提問
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('步驟 2：輸入問題',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _q,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '例如：這份文件的治療重點是什麼？',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _ask,
                    icon: const Icon(Icons.search),
                    label: const Text('送出問題'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3) 回答
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('回答',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    _answer.isEmpty ? '（尚無內容）' : _answer,
                  ),
                  const SizedBox(height: 8),
                  if (_costUsd != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💵 本次總花費：約 \$${_costUsd!.toStringAsFixed(6)} USD',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_embedCost != null)
                          Text(
                            '🔴 上傳嵌入費用：\$${_embedCost!.toStringAsFixed(6)} USD',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        if (_chatCost != null)
                          Text(
                            '🔴 問答生成費用：\$${_chatCost!.toStringAsFixed(6)} USD',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
