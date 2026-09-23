import 'package:flutter/material.dart';

class WesterosApp extends StatelessWidget {
  const WesterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WesterosLige',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WesterosLige')),
      body: const Center(
        child: Text('阶段 3 骨架已就绪，等待数据层与 UI 层实现。'),
      ),
    );
  }
}
