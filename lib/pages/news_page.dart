// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../services/api_client.dart';

// class NewsPage extends StatefulWidget {
//   const NewsPage({super.key});

//   @override
//   State<NewsPage> createState() => _NewsPageState();
// }

// class _NewsPageState extends State<NewsPage> {
//   final _api = ApiClient();
//   late Future<List<Map<String, dynamic>>> _future;

//   @override
//   void initState() {
//     super.initState();
//     _future = _load();
//   }

//   @override
//   void dispose() {
//     _api.close();
//     super.dispose();
//   }

//   Future<List<Map<String, dynamic>>> _load() {
//     return _api.fetchNews(source: 'who', limit: 10);
//   }

//   Future<void> _refresh() async {
//     setState(() {
//       _future = _load();
//     });
//     await _future;
//   }

//   Future<void> _openUrl(String? url) async {
//     if (url == null || url.isEmpty) return;
//     final uri = Uri.parse(url);
//     final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
//     if (!ok && mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('無法開啟連結')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('WHO 快訊'),
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refresh,
//         child: FutureBuilder<List<Map<String, dynamic>>>(
//           future: _future,
//           builder: (context, snap) {
//             if (snap.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snap.hasError) {
//               return ListView(
//                 children: [
//                   const SizedBox(height: 80),
//                   Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
//                   const SizedBox(height: 12),
//                   Center(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       child: Text(
//                         '載入失敗：${snap.error}',
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Center(
//                     child: TextButton.icon(
//                       onPressed: _refresh,
//                       icon: const Icon(Icons.refresh),
//                       label: const Text('重新整理'),
//                     ),
//                   ),
//                 ],
//               );
//             }

//             final items = snap.data ?? const [];
//             if (items.isEmpty) {
//               return ListView(
//                 children: const [
//                   SizedBox(height: 120),
//                   Center(child: Text('目前沒有可顯示的新聞')),
//                 ],
//               );
//             }

//             return ListView.separated(
//               itemCount: items.length,
//               separatorBuilder: (_, __) => const Divider(height: 1),
//               itemBuilder: (context, i) {
//                 final item = items[i];
//                 final title = (item['title'] as String? ?? '').trim();
//                 final date = (item['published'] as String? ?? '').trim();
//                 final summary = (item['summary'] as String? ?? '').trim();
//                 final imageUrl = (item['image'] as String? ?? '').trim();
//                 final url = (item['url'] as String? ?? '').trim();

//                 return InkWell(
//                   onTap: () => _openUrl(url),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // 左側縮圖
//                         SizedBox(
//                           width: 72,
//                           height: 72,
//                           child: ClipRRect(
//                             borderRadius: BorderRadius.circular(8),
//                             child: imageUrl.isNotEmpty
//                                 ? Image.network(
//                                     imageUrl,
//                                     fit: BoxFit.cover,
//                                     errorBuilder: (_, __, ___) =>
//                                         const Icon(Icons.article_outlined, size: 36),
//                                   )
//                                 : const DecoratedBox(
//                                     decoration: BoxDecoration(color: Color(0xFFEFEFEF)),
//                                     child: Center(
//                                       child: Icon(Icons.article_outlined, size: 36),
//                                     ),
//                                   ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         // 右側文字
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               if (date.isNotEmpty)
//                                 Text(
//                                   date,
//                                   style: theme.textTheme.bodySmall?.copyWith(
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 title,
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: theme.textTheme.titleMedium?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//                               if (summary.isNotEmpty) ...[
//                                 const SizedBox(height: 6),
//                                 Text(
//                                   summary,
//                                   maxLines: 3,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: theme.textTheme.bodyMedium,
//                                 ),
//                               ],
//                               const SizedBox(height: 6),
//                               Row(
//                                 children: [
//                                   Text(
//                                     '查看原文',
//                                     style: theme.textTheme.bodySmall?.copyWith(
//                                       color: theme.colorScheme.primary,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Icon(Icons.open_in_new,
//                                       size: 14, color: theme.colorScheme.primary),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

// 讓頁面在 IndexedStack 中保持存活，不會重新請求
class _NewsPageState extends State<NewsPage> with AutomaticKeepAliveClientMixin {
  final _api = ApiClient();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    // 只在第一次建立時取資料；切頁回來不會重跑
    _future = _api.fetchNews(source: 'who', limit: 10);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  // ★ 關鍵：保持狀態
  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    setState(() {
      _future = _api.fetchNews(source: 'who', limit: 10);
    });
    await _future;
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('無法開啟連結')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ★ 使用 keep-alive 時要呼叫
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('WHO 快訊')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('載入失敗：${snap.error}',
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新整理'),
                    ),
                  ),
                ],
              );
            }

            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('目前沒有可顯示的新聞')),
                ],
              );
            }

            return ListView.separated(
              key: const PageStorageKey('news-list'), // 再保險一次
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final it = items[i];
                final title = (it['title'] as String? ?? '').trim();
                final date = (it['published'] as String? ?? '').trim();
                final summary = (it['summary'] as String? ?? '').trim();
                final imageUrl = (it['image'] as String? ?? '').trim();
                final url = (it['url'] as String? ?? '').trim();

                return InkWell(
                  onTap: () => _openUrl(url),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 縮圖
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl.isNotEmpty &&
                                    !imageUrl.contains('h-logo-blue')
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.article_outlined, size: 36),
                                  )
                                : const DecoratedBox(
                                    decoration:
                                        BoxDecoration(color: Color(0xFFEFEFEF)),
                                    child: Center(
                                      child:
                                          Icon(Icons.article_outlined, size: 36),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 文字
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date.isNotEmpty)
                                Text(
                                  date,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (summary.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  summary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '查看原文',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.open_in_new,
                                      size: 14, color: theme.colorScheme.primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
