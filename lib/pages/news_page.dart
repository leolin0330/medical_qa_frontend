// lib/pages/news_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart'; // 只用到 kBaseUrl

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late Future<List<NewsItem>> _futureNews;

  @override
  void initState() {
    super.initState();
    _futureNews = _fetchNews();
  }

  Future<List<NewsItem>> _fetchNews() async {
    final uri = Uri.parse('$kBaseUrl/news?source=who&limit=10');
    final res = await http.get(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('載入快訊失敗：${res.statusCode} ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('快訊（WHO）'),
      ),
      body: FutureBuilder<List<NewsItem>>(
        future: _futureNews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '載入失敗：${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('目前沒有快訊'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              return _NewsCard(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class NewsItem {
  final String title;
  final String summary;
  final String link;
  final String published;
  final String source;

  NewsItem({
    required this.title,
    required this.summary,
    required this.link,
    required this.published,
    required this.source,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      link: json['link'] as String? ?? '',
      published: json['published'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText =
        item.published.isNotEmpty ? item.published : '最新快訊 · ${item.source}';

    return InkWell(
      onTap: () => _openLink(context, item.link),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側縮圖區塊（目前沒有圖片，就先放顏色+icon）
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.public, size: 36),
              ),
              const SizedBox(width: 12),
              // 右側文字區
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期 + 類型
                    Text(
                      '$dateText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 標題
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟連結')),
      );
    }
  }
}
