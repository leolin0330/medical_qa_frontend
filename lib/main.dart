// import 'package:flutter/material.dart';
// import 'pages/qa_page.dart';
// import 'pages/encyclopedia_page.dart';
// import 'pages/learning_page.dart';
// import 'pages/news_page.dart';
// import 'pages/me_page.dart';

// // flutter build web --release  編譯 Web 版
// // 把整個 build/web 資料夾丟到Netlify Flutter Web

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Medical QA',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
//       home: const HomeShell(),
//     );
//   }
// }

// class HomeShell extends StatefulWidget {
//   const HomeShell({super.key});

//   @override
//   State<HomeShell> createState() => _HomeShellState();
// }

// class _HomeShellState extends State<HomeShell> {
//   int _index = 0;

//   final _pages = const [
//     const QAPage(),
//     const EncyclopediaPage(),
//     const LearningPage(),
//     const NewsPage(),
//     const MePage(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(child: _pages[_index]),
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _index,
//         onDestinationSelected: (i) => setState(() => _index = i),
//         destinations: const [
//           NavigationDestination(
//               icon: Icon(Icons.question_answer_outlined),
//               selectedIcon: Icon(Icons.question_answer),
//               label: '問答'),
//           NavigationDestination(
//               icon: Icon(Icons.menu_book_outlined),
//               selectedIcon: Icon(Icons.menu_book),
//               label: '百科'),
//           NavigationDestination(
//               icon: Icon(Icons.school_outlined),
//               selectedIcon: Icon(Icons.school),
//               label: '學習'),
//           NavigationDestination(
//               icon: Icon(Icons.flash_on_outlined),
//               selectedIcon: Icon(Icons.flash_on),
//               label: '快訊'),
//           NavigationDestination(
//               icon: Icon(Icons.person_outline),
//               selectedIcon: Icon(Icons.person),
//               label: '我的'),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

// 這些路徑依你的專案結構調整：
// （依你前面提供的檔案名）
import 'pages/qa_page.dart';
import 'pages/encyclopedia_page.dart';
import 'pages/learning_page.dart';
import 'pages/news_page.dart';
import 'pages/me_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical QA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32), // 可換你的主色
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // 用來保存各分頁的捲動位置與狀態
  final PageStorageBucket _bucket = PageStorageBucket();

  // 只建立一次頁面實例（放在成員，不要每次 build new）
  // 每頁給一個 PageStorageKey，捲動位置會被保存
  late final List<Widget> _pages = const [
    QAPage(key: PageStorageKey('qa')),
    EncyclopediaPage(key: PageStorageKey('encyclopedia')),
    LearningPage(key: PageStorageKey('learning')),
    NewsPage(key: PageStorageKey('news')),
    MePage(key: PageStorageKey('me')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        // 用 IndexedStack：非當前頁會保留在 widget 樹上，不會被銷毀
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '問答'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '百科'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: '學習'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: '快訊'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
