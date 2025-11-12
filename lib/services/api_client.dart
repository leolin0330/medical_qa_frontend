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
// 放在 class ApiClient 裡，覆蓋原本的 ask()
  Future<Map<String, dynamic>> ask({
    String? query,
    String? url,
    String? instruction,
    int topK = 5,
    String? collectionId,
    List<String>? sources, // 可選：對應後端的 ?source=a&source=b
  }) async {
    // 組 query string（多個 source）
    var base = '$kBaseUrl/ask';
    if (sources != null && sources.isNotEmpty) {
      final qs =
          sources.map((s) => 'source=${Uri.encodeQueryComponent(s)}').join('&');
      base = '$base?$qs';
    }

    final uri = Uri.parse(base);

    // x-www-form-urlencoded
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'accept': 'application/json',
    };

    // 清理掉 "string/null/undefined"
    String? _clean(String? v) {
      if (v == null) return null;
      final t = v.trim();
      if (t.isEmpty) return null;
      final low = t.toLowerCase();
      if (low == 'string' ||
          low == 'null' ||
          low == 'none' ||
          low == 'undefined') {
        return null;
      }
      return t;
    }

    final body = <String, String>{
      if (_clean(query) != null) 'query': _clean(query)!,
      if (_clean(url) != null) 'url': _clean(url)!,
      if (_clean(instruction) != null) 'instruction': _clean(instruction)!,
      'top_k': topK.toString(),
      if (_clean(collectionId) != null) 'collectionId': _clean(collectionId)!,
    };

    final res = await http.post(uri, headers: headers, body: body);
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
    required String query,
    int topK = 5,
  }) async {
    final uri = Uri.parse('$kBaseUrl/fetch_url');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'accept': 'application/json'
      },
      body: {
        'url': url,
        'query': query,
        'top_k': topK.toString(),
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch URL failed: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  void close() => _client.close();

  // =======================
  // 4) WHO 新聞列表
  // =======================
  /// 呼叫後端 GET /news?source=who&limit=10
  /// 回傳那個 JSON 裡的 items：
  ///   [
  ///     { "title": ..., "url": ..., "published": ..., "summary": ..., "image": ..., "source": "WHO" },
  ///     ...
  ///   ]
  Future<List<Map<String, dynamic>>> fetchNews({
    String source = 'who',
    int limit = 10,
  }) async {
    final uri = Uri.parse('$kBaseUrl/news').replace(queryParameters: {
      'source': source,
      'limit': limit.toString(),
    });

    final res = await http.get(
      uri,
      headers: const {
        'accept': 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch news failed: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }
}
