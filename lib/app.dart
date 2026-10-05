import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/westeros_theme.dart';

class WesterosApp extends StatelessWidget {
  const WesterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WesterosLige',
      theme: westerosTheme(),
      // Batch 10-105：App 启动先进开屏首页（主菜单），
      // 再经「开始新游戏」进入开局分步向导。
      home: const HomeScreen(),
    );
  }
}