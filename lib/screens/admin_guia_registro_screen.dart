import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/guia_logger.dart';

/// Registro anónimo de las preguntas a El Guía (Fase 2, 2.2 sin tocar la base).
///
/// Muestra cuántas preguntas hay, cuántas cayeron en "no tengo ese dato" y permite
/// **exportar el CSV** para mandarlo a mano (por WhatsApp, mail...). Lo exportado ya
/// está anonimizado: sin correos, teléfonos, números largos ni nombres dichos con "me
/// llamo" o "soy", y con el día (no la hora). Sirve para armar el conjunto de evaluación
/// con preguntas reales de los usuarios de prueba.
class AdminGuiaRegistroScreen extends StatefulWidget {
  const AdminGuiaRegistroScreen({super.key});

  @override
  State<AdminGuiaRegistroScreen> createState() => _AdminGuiaRegistroScreenState();
}

class _AdminGuiaRegistroScreenState extends State<AdminGuiaRegistroScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topFallbacks = [];
  List<File> _archivos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (kIsWeb) {
      setState(() => _cargando = false);
      return;
    }
    final stats = await GuiaLogger.estadisticas();
    final top = await GuiaLogger.leerTopFallbacks(n: 15);
    final archivos = await GuiaLogger.archivosParaExportar();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _topFallbacks = top;
      _archivos = archivos;
      _cargando = false;
    });
  }

  int get _total => (_stats['total'] as int?) ?? 0;

  Future<void> _exportar() async {
    await Share.shareXFiles(
      [for (final a in _archivos) XFile(a.path, mimeType: 'text/csv', name: a.uri.pathSegments.last)],
      subject: 'Preguntas a El Guía (anónimo)',
      text: 'Registro anónimo de preguntas a El Guía YA: sin datos personales y con el día, sin la hora.',
    );
  }

  Future<void> _borrar() async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar el registro?'),
        content: const Text('Se borran las preguntas guardadas en ESTE celular. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (seguro != true) return;
    await GuiaLogger.borrarRegistros();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(color: Colors.white70, fontSize: 13);
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Registro de preguntas', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : kIsWeb
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('El registro se guarda en el celular: abrí este panel desde la app de Android.', style: estilo),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Es un registro anónimo: se borran correos, teléfonos, números largos y los nombres dichos con '
                      '"me llamo" o "soy", y se guarda el día, no la hora.',
                      style: estilo,
                    ),
                    const SizedBox(height: 16),
                    if (_total == 0)
                      Text('Todavía no hay preguntas guardadas en este celular.', style: estilo)
                    else ...[
                      Text(
                        '$_total preguntas · ${_stats['fallbacks'] ?? 0} sin respuesta (${_stats['porcentaje_fallback'] ?? 0} %)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      if (_topFallbacks.isNotEmpty) ...[
                        Text('LO QUE MÁS NO SUPO CONTESTAR',
                            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        for (final f in _topFallbacks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${f['veces']} × ${f['texto']}', style: estilo),
                          ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        onPressed: _exportar,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('EXPORTAR CSV'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _borrar,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Borrar el registro de este celular'),
                      ),
                    ],
                  ],
                ),
    );
  }
}
