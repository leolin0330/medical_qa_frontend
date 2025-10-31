// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart' show MediaType;

// const String kBaseUrl = String.fromEnvironment(
//   'API_BASE_URL',
//   // defaultValue: 'http://10.0.2.2:8000',// 安卓模擬
//   defaultValue: 'http://192.168.4.205:8000', //CHROME
//   // defaultValue: 'http://127.0.0.1:8000'',//手機
//   // defaultValue: 'https://medical-qa-backend-426112254627.asia-east1.run.app'
// );

// class ApiClient {
//   final http.Client _client;
//   ApiClient({http.Client? client}) : _client = client ?? http.Client();

//   // ✅ 改良版上傳：支援 fromBytes (Web)
//   Future<Map<String, dynamic>> uploadFile({
//     File? file,
//     Uint8List? bytes,
//     String? filename,
//     String? collectionId,
//   }) async {
//     final uri = Uri.parse('$kBaseUrl/upload');
//     final req = http.MultipartRequest('POST', uri);

//     if (collectionId != null && collectionId.isNotEmpty) {
//       req.fields['collection_id'] = collectionId;
//     }

//     final name =
//         filename ?? (file != null ? file.path.split('/').last : 'upload.bin');
//     final contentType = _guessContentType(name);
//     final mediaType = contentType == null ? null : MediaType.parse(contentType);

//     if (bytes != null) {
//       req.files.add(http.MultipartFile.fromBytes('file', bytes,
//           filename: name, contentType: mediaType));
//     } else if (file != null) {
//       req.files.add(await http.MultipartFile.fromPath('file', file.path,
//           filename: name, contentType: mediaType));
//     } else {
//       throw ArgumentError('Either file or bytes must be provided.');
//     }

//     final streamed = await req.send();
//     final respStr = await streamed.stream.bytesToString();
//     if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
//       return jsonDecode(respStr) as Map<String, dynamic>;
//     }
//     throw HttpException('Upload failed: ${streamed.statusCode} - $respStr');
//   }

//   // 只改 ask()：沒來源就完全不帶 source，避免被判定「有文件」
//   Future<Map<String, dynamic>> ask({
//     required String question,
//     String mode = 'auto',
//     int topK = 5,
//     List<String>? sources, // 可選：來源/collectionId 清單
//   }) async {
//     // 1) 先組 URL；只有在 sources 有值時才加到 query string
//     String url = '$kBaseUrl/ask';
//     if (sources != null && sources.isNotEmpty) {
//       final qs = sources
//           .map((s) => 'source=${Uri.encodeQueryComponent(s)}')
//           .join('&');
//       url = '$url?$qs';
//     }

//     // 2) 其餘用 Multipart fields（FastAPI: query/模式/top_k 走表單 OK）
//     final req = http.MultipartRequest('POST', Uri.parse(url))
//       ..fields['query'] = question
//       ..fields['mode'] = mode
//       ..fields['top_k'] = topK.toString();

//     final streamed = await req.send();
//     final respStr = await streamed.stream.bytesToString();
//     if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
//       return jsonDecode(respStr) as Map<String, dynamic>;
//     }
//     throw HttpException('Ask failed: ${streamed.statusCode} - $respStr');
//   }

//   String? _guessContentType(String filename) {
//     final lower = filename.toLowerCase();
//     if (lower.endsWith('.pdf')) return 'application/pdf';
//     if (lower.endsWith('.docx'))
//       return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
//     if (lower.endsWith('.pptx'))
//       return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
//     if (lower.endsWith('.txt')) return 'text/plain';
//     if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
//     if (lower.endsWith('.md')) return 'text/markdown';
//     return null;
//   }

//   /// 工具函式：判斷是否為網址
//   bool isUrl(String input) {
//     final t = input.trim().toLowerCase();
//     return t.startsWith('http://') || t.startsWith('https://');
//   }

//   Future<Map<String, dynamic>> fetchUrl({
//     required String url,
//     required String query,
//     int topK = 5,
//     String mode = 'auto',
//   }) async {
//     final uri = Uri.parse('$kBaseUrl/fetch_url');
//     final response = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//       body: {
//         'url': url,
//         'query': query,
//         'top_k': topK.toString(),
//         'mode': mode,
//       },
//     );
//     if (response.statusCode >= 200 && response.statusCode < 300) {
//       return json.decode(response.body) as Map<String, dynamic>;
//     } else {
//       throw Exception('Failed to fetch URL: ${response.body}');
//     }
//   }
// }
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // defaultValue: 'http://10.0.2.2:8000', // Android 模擬器
  defaultValue: 'http://192.168.4.205:8000', // 你目前的 CHROME 測試位址
  // defaultValue: 'http://127.0.0.1:8000',   // 手機接線測試
  // defaultValue: 'https://<your-cloud-run-url>',
);

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // ---- 小工具 ----
  bool _isInvalidCid(String? s) {
    if (s == null) return true;
    final v = s.trim().toLowerCase();
    return v.isEmpty ||
        v == 'string' ||
        v == 'null' ||
        v == 'undefined' ||
        v == 'none';
  }

  // =======================
  // 1) 上傳檔案
  // =======================
  /// 上傳任一檔案（Word/PDF/PPTX/音訊/影片）
  /// - [collectionId] 可不填：不填或無效時，後端會回傳 _default
  /// - 回傳包含：collectionId、paragraphs_indexed、成本等
  Future<Map<String, dynamic>> uploadFile({
    required String filename,
    Uint8List? bytes, // Web/記憶體
    String? filepath, // 手機/桌面路徑
    String? collectionId, // 可選；空或 'string' 等無效會被忽略
    String mode = 'overwrite', // 儲存策略：overwrite / append
    MediaType? contentType,
  }) async {
    final uri = Uri.parse('$kBaseUrl/upload');
    final req = http.MultipartRequest('POST', uri);

    // 僅在「有值且有效」時才傳 collectionId
    if (!_isInvalidCid(collectionId)) {
      req.fields['collectionId'] = collectionId!;
    }
    req.fields['mode'] = mode;

    if (bytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType, // 可不填
      ));
    } else if (filepath != null) {
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        filepath,
        contentType: contentType,
      ));
    } else {
      throw ArgumentError('uploadFile 需要 bytes 或 filepath 其中之一');
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upload failed: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // =======================
  // 2) 問答
  // =======================
  /// 問題 -> 後端自動決定用 doc 或 general
  /// - 僅在你有上傳文件且我們有記住 collectionId 時，才帶 collectionId
  Future<Map<String, dynamic>> ask({
    required String query,
    int topK = 5,
    String? collectionId,
    List<String>? sources, // 如需過濾來源，可日後擴充
  }) async {
    final uri = Uri.parse('$kBaseUrl/ask');

    // 後端收 form-urlencoded
    final body = <String, String>{
      'query': query,
      'top_k': '$topK',
    };

    if (!_isInvalidCid(collectionId)) {
      body['collectionId'] = collectionId!;
    }
    // 若要支援 sources，多個同名鍵需要特殊處理；目前先不傳（後端 Query(List[str]))。

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Ask failed: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // =======================
  // 3) URL 讀取 + 問答（臨時 collection）
  // =======================
  /// 後端已在 /fetch_url 內部建立臨時 collection，並在結束後清除
  /// 這裡不再傳 mode
  Future<Map<String, dynamic>> fetchUrl({
    required String url,
    String query = '請用上面網址內容條列重點並進行摘要',
    int topK = 5,
  }) async {
    final uri = Uri.parse('$kBaseUrl/fetch_url');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'url': url,
        'query': query,
        'top_k': '$topK',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch URL failed: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}
