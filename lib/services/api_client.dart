import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // defaultValue: 'http://10.0.2.2:8000',// 安卓模擬
  defaultValue: 'http://192.168.4.205:8000', //CHROME
  // defaultValue: 'http://127.0.0.1:8000'',//手機
  // defaultValue: 'https://medical-qa-backend-426112254627.asia-east1.run.app'
);

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // ✅ 改良版上傳：支援 fromBytes (Web)
  Future<Map<String, dynamic>> uploadFile({
    File? file,
    Uint8List? bytes,
    String? filename,
    String? collectionId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/upload');
    final req = http.MultipartRequest('POST', uri);

    if (collectionId != null && collectionId.isNotEmpty) {
      req.fields['collection_id'] = collectionId;
    }

    final name =
        filename ?? (file != null ? file.path.split('/').last : 'upload.bin');
    final contentType = _guessContentType(name);
    final mediaType = contentType == null ? null : MediaType.parse(contentType);

    if (bytes != null) {
      req.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: name, contentType: mediaType));
    } else if (file != null) {
      req.files.add(await http.MultipartFile.fromPath('file', file.path,
          filename: name, contentType: mediaType));
    } else {
      throw ArgumentError('Either file or bytes must be provided.');
    }

    final streamed = await req.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    }
    throw HttpException('Upload failed: ${streamed.statusCode} - $respStr');
  }

  Future<Map<String, dynamic>> ask({
    required String question,
    String mode = 'auto',
  }) async {
    final uri = Uri.parse('$kBaseUrl/ask');
    final req = http.MultipartRequest('POST', uri);
    req.fields['query'] = question;
    req.fields['mode'] = mode;

    final streamed = await req.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    }
    throw HttpException('Ask failed: ${streamed.statusCode} - $respStr');
  }

  String? _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx'))
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.pptx'))
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.md')) return 'text/markdown';
    return null;
  }

  /// 工具函式：判斷是否為網址
  bool isUrl(String input) {
    final t = input.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  Future<Map<String, dynamic>> fetchUrl({
    required String url,
    required String query,
    int topK = 5,
    String mode = 'auto',
  }) async {
    final uri = Uri.parse('$kBaseUrl/fetch_url');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'url': url,
        'query': query,
        'top_k': topK.toString(),
        'mode': mode,
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch URL: ${response.body}');
    }
  }
}
