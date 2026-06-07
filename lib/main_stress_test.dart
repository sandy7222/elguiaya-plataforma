

import 'package:flutter/material.dart';

import 'screens/stress_test_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const CapitanYA());
}

class CapitanYA extends StatelessWidget {
  const CapitanYA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capitan YA - Prueba de Estres',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF002366),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF002366),
          foregroundColor: Colors.white,
        ),
      ),
      home: const StressTestDemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
