import 'package:flutter/material.dart';

import 'screens/start_screen.dart';
import 'theme/westeros_theme.dart';

class WesterosApp extends StatelessWidget {
  const WesterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WesterosLige',
      theme: westerosTheme(),
      home: const StartScreen(),
    );
  }
}
