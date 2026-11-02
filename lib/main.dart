import 'package:flutter/material.dart';

void main() => runApp(const TheomythApp());

class TheomythApp extends StatelessWidget {
  const TheomythApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theomyth: Idle RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14122B),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFF2C14E)),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'THEOMYTH',
            style: TextStyle(
              color: Color(0xFFF3EEDC),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
