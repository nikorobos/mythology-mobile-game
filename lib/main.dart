import 'package:flutter/material.dart';

import 'ui/splash_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const TheomythApp());

class TheomythApp extends StatelessWidget {
  const TheomythApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theomyth: Idle RPG',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
