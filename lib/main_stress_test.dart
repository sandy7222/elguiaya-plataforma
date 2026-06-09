

import 'package:flutter/material.dart';

import 'screens/stress_test_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const El Guia YA());
}

class El Guia YA extends StatelessWidget {
  const El Guia YA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EL GUIA YA - Prueba de Estres',
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
