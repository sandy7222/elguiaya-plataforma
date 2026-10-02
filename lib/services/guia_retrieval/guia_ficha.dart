import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Unidad mínima de conocimiento que el retriever puede devolver tal cual.
///
/// Se construye desde las librerías JSON (ver [GuiaCorpusBuilder]) y es
/// el equivalente Dart de la dataclass `Ficha` de
/// `mini_model_lab/retrieval/fichas.py`.
class GuiaFicha {
  /// Ej. "peces/dorado", "nudos/nudos/palomar", "como_se_hace_fritanga".
  final String id;

  /// Nombre del archivo de la librería (sin .json).
  final String libreria;

  /// Texto corto para el "¿te referís a...?".
  final String titulo;

  /// La respuesta que se muestra al usuario, sin modificar.
  final String texto;

  /// Activadores + preguntas canónicas. Se indexan con peso alto.
  final List<String> preguntas;

  /// Términos extra para la búsqueda léxica (no se muestran).
  final List<String> keywords;

  /// "tecnico" | "cocina" | "campamento" | "especies" | "condiciones".
  final String categoria;

  const GuiaFicha({
    required this.id,
    required this.libreria,
    required this.titulo,
    required this.texto,
    required this.preguntas,
    required this.keywords,
    required this.categoria,
  });

  /// Huella del contenido que afecta al índice semántico. Si cambia el
  /// texto o las preguntas, cambia el hash y hay que re-vectorizar.
  String get hash =>
      md5.convert(utf8.encode('$titulo\u0000$texto\u0000${preguntas.join('\u0000')}')).toString();

  /// Todo lo que se indexa léxicamente, en un solo string (para depurar).
  String get textoIndexable => [titulo, ...preguntas, texto, ...keywords].join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'libreria': libreria,
        'titulo': titulo,
        'texto': texto,
        'preguntas': preguntas,
        'keywords': keywords,
        'categoria': categoria,
      };

  factory GuiaFicha.fromJson(Map<String, dynamic> j) => GuiaFicha(
        id: j['id'] as String,
        libreria: j['libreria'] as String,
        titulo: j['titulo'] as String,
        texto: j['texto'] as String,
        preguntas: List<String>.from(j['preguntas'] as List? ?? const []),
        keywords: List<String>.from(j['keywords'] as List? ?? const []),
        categoria: j['categoria'] as String? ?? 'tecnico',
      );

  @override
  String toString() => 'GuiaFicha($id)';
}
