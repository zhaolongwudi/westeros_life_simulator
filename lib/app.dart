import 'package:flutter/material.dart';

import 'screens/start_screen.dart';

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
      home: const StartScreen(),
    );
  }
}
