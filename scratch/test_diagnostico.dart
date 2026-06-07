import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = ElGuiaEngine();
  await engine.inicializar();

  final query = 'porque no pica nada en el rio?';
  final textoNormalizado = engine.contexto.ultimaConsulta = query; // wait, let's check normalizer
  final texto = engine.contexto.ultimaConsulta; // or call private method if we can, but we can call responder or use public methods.
  
  print('Original: $query');
  final resp = await engine.responder(query);
  print('Response: ${resp.texto}');
  
  final intenciones = engine.detectarIntenciones(query);
  print('Intenciones detected for "$query": $intenciones');
}
