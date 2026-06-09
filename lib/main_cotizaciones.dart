

import 'package:flutter/material.dart';

import 'screens/cotizaciones_capitan_screen.dart';
import 'screens/cotizaciones_formulario_fixed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const El Guia YA());
}

class El Guia YA extends StatelessWidget {
  const El Guia YA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EL GUIA YA - Portal de Cotizaciones',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF002366),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF002366),
          foregroundColor: Colors.white,
        ),
      ),
      home: const CotizacionesCapitanScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/cotizaciones': (context) => const CotizacionesCapitanScreen(),
        '/cotizaciones_formulario': (context) => const CotizacionesFormularioScreen(),
      },
    );
  }
}
