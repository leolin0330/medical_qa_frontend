

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';

// // A simple data model for a Paper (if not already defined elsewhere in the project)
// class Paper {
//   final double score;
//   final String title;
//   final String url;
//   final String journal;
//   final int year;
//   final int citations;
//   final String abstractText;
//   Paper({
//     required this.score,
//     required this.title,
//     required this.url,
//     required this.journal,
//     required this.year,
//     required this.citations,
//     required this.abstractText,
//   });
//   factory Paper.fromJson(Map<String, dynamic> json) {
//     return Paper(
//       score: (json['gpt_score'] ?? json['score'] ?? 0).toDouble(),
//       title: json['title'] ?? 'Untitled',
//       url: json['url'] ?? '',
//       journal: json['journal'] ?? 'Unknown Journal',
//       year: json['year'] ?? 0,
//       citations: json['citations'] ?? 0,
//       abstractText: json['abstract'] ?? '',
//     );
//   }
// }

// // Riverpod FutureProvider (family) to fetch papers for a given query
// final papersSearchProvider = FutureProvider.family<List<Paper>, String>((ref, query) async {
//   // Replace BASE_URL with the actual base URL of the backend if needed
//   final Uri apiUri = Uri.parse(/* BASE_URL + */ '/find_papers');
//   final response = await http.post(
//     apiUri,
//     headers: {'Content-Type': 'application/json'},
//     body: jsonEncode({'query': query, 'top_k': 5}),
//   );
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     // Expecting data to be a list of paper info
//     if (data is List) {
//       return data.map((item) => Paper.fromJson(item)).toList();
//     } else if (data is Map && data.containsKey('papers')) {
//       // If response has a nested structure { "papers": [...] }
//       final papersList = data['papers'] as List;
//       return papersList.map((item) => Paper.fromJson(item)).toList();
//     } else {
//       // Unexpected format
//       return [];
//     }
//   } else {
//     // If the API returns an error status, throw exception to trigger error state
//     throw Exception('Failed to load papers (status ${response.statusCode})');
//   }
// });

// class LearningPage  extends ConsumerStatefulWidget {
//   const LearningPage ({Key? key}) : super(key: key);

//   @override
//   ConsumerState<LearningPage > createState() => _LearningPageState();
// }

// class _LearningPageState extends ConsumerState<LearningPage > {
//   late TextEditingController _queryController;
//   String? _searchQuery; // The current query to search for
//   List<bool> _isExpandedList = []; // Track abstract expansion for each result

//   @override
//   void initState() {
//     super.initState();
//     _queryController = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _queryController.dispose();
//     super.dispose();
//   }

//   Future<void> _launchPaperUrl(String url) async {
//     if (url.isEmpty) return;
//     final Uri uri = Uri.parse(url);
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri);
//     } else {
//       // Could not launch URL – handle gracefully (e.g., show a snackbar)
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('无法打开论文链接')),
//       );
//     }
//   }

//   void _onSearchPressed() {
//     final queryText = _queryController.text.trim();
//     if (queryText.isEmpty) {
//       // If query is empty, you might show a message or just do nothing
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('请输入查询关键字')),
//       );
//       return;
//     }
//     // Update the search query and trigger provider fetch
//     setState(() {
//       _searchQuery = queryText;
//       _isExpandedList = []; // reset expansion states for new search
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Watch the search provider only when a query is set
//     final AsyncValue<List<Paper>> papersAsync = (_searchQuery != null)
//         ? ref.watch(papersSearchProvider(_searchQuery!))
//         : const AsyncValue.data([]); // empty data when no search yet

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('论文百科'), // "Paper Encyclopedia" title (adjust as needed)
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Search input field and button
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _queryController,
//                     decoration: const InputDecoration(
//                       hintText: '输入关键词搜索论文...', // hint in Chinese for "Enter keywords..."
//                       border: OutlineInputBorder(),
//                       contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     ),
//                     textInputAction: TextInputAction.search,
//                     onSubmitted: (_) => _onSearchPressed(),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: _onSearchPressed,
//                   child: const Text('搜索'), // "Search" button text in Chinese
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             // Results area
//             Expanded(
//               child: papersAsync.when(
//                 data: (papers) {
//                   // Initialize expansion state list if not yet (e.g., first time data comes in)
//                   if (_isExpandedList.length != papers.length) {
//                     _isExpandedList = List.filled(papers.length, false);
//                   }
//                   if (papers.isEmpty) {
//                     return const Center(
//                       child: Text('未找到相关论文'), // "No papers found"
//                     );
//                   }
//                   // Use ListView to display paper cards
//                   return ListView.builder(
//                     itemCount: papers.length,
//                     itemBuilder: (context, index) {
//                       final paper = papers[index];
//                       final bool isExpanded = _isExpandedList[index];
//                       // Short preview of abstract (for collapsed state)
//                       String previewText = paper.abstractText;
//                       if (!isExpanded && previewText.length > 150) {
//                         // truncate to 150 chars for preview
//                         previewText = '${previewText.substring(0, 150)}...';
//                       }
//                       return Card(
//                         elevation: 2,
//                         margin: const EdgeInsets.symmetric(vertical: 8),
//                         child: Padding(
//                           padding: const EdgeInsets.all(12.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // Title (clickable link)
//                               GestureDetector(
//                                 onTap: () => _launchPaperUrl(paper.url),
//                                 child: Text(
//                                   paper.title,
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                     color: Theme.of(context).colorScheme.primary,
//                                     decoration: TextDecoration.underline,
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               // Meta information: Journal, Year, Citations, Score
//                               Text(
//                                 '${paper.journal} (${paper.year})',
//                                 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                               ),
//                               Text(
//                                 '引用次数: ${paper.citations}    GPT评分: ${paper.score.toStringAsFixed(2)}',
//                                 style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
//                               ),
//                               const SizedBox(height: 8),
//                               // Abstract (expandable)
//                               Text(
//                                 isExpanded ? paper.abstractText : previewText,
//                                 style: const TextStyle(fontSize: 14),
//                               ),
//                               if (paper.abstractText.length > 150) // only show toggle if text is long
//                                 Align(
//                                   alignment: Alignment.centerRight,
//                                   child: TextButton(
//                                     onPressed: () {
//                                       setState(() {
//                                         _isExpandedList[index] = !_isExpandedList[index];
//                                       });
//                                     },
//                                     child: Text(isExpanded ? '收起摘要' : '展开摘要'), // "Collapse abstract" / "Expand abstract"
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//                 loading: () => const Center(child: CircularProgressIndicator()),
//                 error: (error, stackTrace) {
//                   return Center(
//                     child: Text('搜索出错：$error'), // "Search error: $error"
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

/// Learning 分頁：先保留作為「學習入口」(之後放 Quiz / Flashcard / 進度等)
class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('學習功能準備中（Quiz / Flashcard / 進度）'),
      ),
    );
  }
}
