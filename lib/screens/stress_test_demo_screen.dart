

import 'package:flutter/material.dart';

import '../services/stress_test_service.dart';
import '../widgets/safe_button.dart';

class StressTestDemoScreen extends StatefulWidget {
  const StressTestDemoScreen({super.key});

  @override
  State<StressTestDemoScreen> createState() => _StressTestDemoScreenState();
}

class _StressTestDemoScreenState extends State<StressTestDemoScreen> {
  bool _isRunning = false;
  String _log = '';
  Map<String, dynamic>? _resultados;

  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  void _addLog(String message) {
    setState(() {
      _log += '[${DateTime.now().toString().substring(11, 19)}] $message\n';
    });
    print(message); // Tambien imprimir en consola
  }

  Future<void> _ejecutarPruebaDeEstres() async {
    setState(() {
      _isRunning = true;
      _log = '';
      _resultados = null;
    });

    _addLog('?? INICIANDO PRUEBA DE ESTRES COMPLETA - EL GUIA YA');
    _addLog('=' * 70);

    try {
      // Ejecutar prueba completa
      final resultados = await StressTestService.ejecutarPruebaDeEstresCompleta();
      
      setState(() {
        _resultados = resultados;
      });

      if (resultados['prueba_completada'] == true) {
        _addLog('\n?? PRUEBA COMPLETADA EXITOSAMENTE');
        _addLog('? Todos los pasos ejecutados sin errores');
        _addLog('? Datos guardados correctamente en Supabase (simulado)');
        
        // Mostrar resumen
        final solicitudes = resultados['solicitudes_enviadas'] as List;
        final respuesta = resultados['respuesta_capitan'] as Map;
        final pago = resultados['pago_procesado'] as Map;
        final puntuacion = resultados['puntuacion_registrada'] as Map;
        
        _addLog('\n?? RESUMEN DE RESULTADOS:');
        _addLog('� Solicitudes enviadas: ${solicitudes.length}');
        _addLog('� Precio cotizado: \$${respuesta['precio_cotizado'].toStringAsFixed(0)}');
        _addLog('� Pagos generados: ${pago['pagos_generados'].length}');
        _addLog('� Calificacion del servicio: ${puntuacion['calificacion']}/5');
        _addLog('� Comentario del pescador: "${puntuacion['comentario']}"');
        
      } else {
        _addLog('\n? ERROR EN PRUEBA DE ESTRES');
        _addLog('Error: ${resultados['error']}');
      }
    } catch (e) {
      _addLog('\n?? ERROR CRITICO: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.speed, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Prueba de Estres - Flujo Completo',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informacion de la prueba
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _azulVibrante.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _azulVibrante.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: _azulVibrante),
                      const SizedBox(width: 8),
                      const Text(
                        '?? Prueba de Estres y Flujo de Cierre',
                        style: TextStyle(
                          color: _azulVibrante,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esta prueba simula el flujo completo del sistema:',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPasoItem('1??', 'Generacion de 5 solicitudes desde Portal Pescador'),
                  _buildPasoItem('2??', 'Validacion de Inbox con Baqueano-IA'),
                  _buildPasoItem('3??', 'Cierre de ciclo: Marcar como "Pagada"'),
                  _buildPasoItem('4??', 'Ejecutar "Finalizar Mision"'),
                  _buildPasoItem('5??', 'Completar formulario de puntuacion'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Boton de ejecucion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _ejecutarPruebaDeEstres,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azulVibrante,
                  foregroundColor: _blancoPuro,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: SafeButtonLoadingContent(
                  loading: _isRunning,
                  icon: Icons.play_arrow,
                  iconColor: _blancoPuro,
                  idleLabel: 'Ejecutar prueba de estr�s',
                  loadingLabel: 'Ejecutando prueba...',
                  textStyle: const TextStyle(
                    color: _blancoPuro,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  spinnerColor: _blancoPuro,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs de la prueba
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: _blancoPuro.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blancoPuro.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _blancoPuro.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal, color: _blancoPuro, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          '?? Logs de Consola',
                          style: TextStyle(
                            color: _blancoPuro,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (_log.isNotEmpty)
                          IconButton(
                            onPressed: () {
                                setState(() => _log = '');
                              },
                            icon: const Icon(Icons.clear, color: _blancoPuro, size: 16),
                            tooltip: 'Limpiar logs',
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _log.isEmpty ? 'Esperando ejecucion de prueba...' : _log,
                        style: TextStyle(
                          color: _blancoPuro.withOpacity(0.9),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Resultados
            if (_resultados != null) ...[
              const SizedBox(height: 16),
              _buildResultadosCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasoItem(String numero, String descripcion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            numero,
            style: const TextStyle(
              color: _azulVibrante,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              descripcion,
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadosCard() {
    final resultados = _resultados!;
    final exito = resultados['prueba_completada'] == true;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exito ? _verdeBrillante.withOpacity(0.1) : _rojoFuerte.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exito ? _verdeBrillante.withOpacity(0.3) : _rojoFuerte.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exito ? Icons.check_circle : Icons.error,
                color: exito ? _verdeBrillante : _rojoFuerte,
              ),
              const SizedBox(width: 8),
              Text(
                exito ? '? Prueba Completada Exitosamente' : '? Error en Prueba',
                style: TextStyle(
                  color: exito ? _verdeBrillante : _rojoFuerte,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (exito) ...[
            const SizedBox(height: 12),
            _buildResultadoItem('Solicitudes Enviadas', '${resultados['solicitudes_enviadas'].length}'),
            _buildResultadoItem('Precio Cotizado', '\$${resultados['respuesta_capitan']['precio_cotizado'].toStringAsFixed(0)}'),
            _buildResultadoItem('Pagos Generados', '${resultados['pago_procesado']['pagos_generados'].length}'),
            _buildResultadoItem('Calificacion', '${resultados['puntuacion_registrada']['calificacion']}/5'),
            _buildResultadoItem('Guardado en Supabase', resultados['puntuacion_registrada']['guardado_en_supabase'] ? '? Si' : '? No'),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Error: ${resultados['error']}',
              style: const TextStyle(
                color: _rojoFuerte,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultadoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: _blancoPuro,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
