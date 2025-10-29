import 'package:flutter/material.dart';
import 'pages/qa_page.dart';
import 'pages/encyclopedia_page.dart';
import 'pages/learning_page.dart';
import 'pages/news_page.dart';
import 'pages/me_page.dart';

// flutter build web --release  編譯 Web 版
// 把整個 build/web 資料夾丟到Netlify Flutter Web

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
theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
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


final _pages = const [
QaPage(),
EncyclopediaPage(),
LearningPage(),
NewsPage(),
MePage(),
];


@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(child: _pages[_index]),
bottomNavigationBar: NavigationBar(
selectedIndex: _index,
onDestinationSelected: (i) => setState(() => _index = i),
destinations: const [
NavigationDestination(icon: Icon(Icons.question_answer_outlined), selectedIcon: Icon(Icons.question_answer), label: '問答'),
NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '百科'),
NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: '學習'),
NavigationDestination(icon: Icon(Icons.flash_on_outlined), selectedIcon: Icon(Icons.flash_on), label: '快訊'),
NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
],
),
);
}
}