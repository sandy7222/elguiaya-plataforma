import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado para gestionar las operaciones y simulaciones de mapas offline.
class MapaOfflineService {
  /// Calcula el tamaño estimado en MB de la descarga basado en el radio de acción en km.
  static int calcularTamanoEstimadoMB(double radioKm) {
    return (radioKm * 3.5).round();
  }

  /// Simula la descarga interactiva de los tiles de mapas.
  /// Retorna un [Timer] que puede ser cancelado en el dispose del widget.
  static Timer iniciarSimulacionDescarga({
    required double radioKm,
    required void Function(double progreso) onProgreso,
    required void Function() onCompletado,
  }) {
    double progreso = 0.0;
    
    return Timer.periodic(const Duration(milliseconds: 150), (timer) {
      progreso += 0.05;
      
      if (progreso >= 1.0) {
        progreso = 1.0;
        onProgreso(progreso);
        onCompletado();
        timer.cancel();
      } else {
        onProgreso(progreso);
      }
    });
  }

  /// Simula o realiza la descarga automática del mapa offline para un viaje programado,
  /// calculando el radio necesario basado en la distancia del trayecto.
  static Future<Timer> descargarMapaParaViajeProgramado({
    required String viajeId,
    required void Function(double progreso) onProgreso,
    required void Function(double radioCalculadoKm, int tamanoMB) onInicioDescarga,
    required void Function() onCompletado,
  }) async {
    double radioKm = 15.0; // Radio de cobertura por defecto (15km)
    
    try {
      final client = Supabase.instance.client;
      // Consultamos la distancia de la cotización asociada al pedido/viaje
      final response = await client
          .from('pedidos')
          .select('presupuestos(cotizaciones(distancia_km))')
          .eq('id', viajeId)
          .maybeSingle();

      if (response != null && response['presupuestos'] != null) {
        final presupuesto = response['presupuestos'];
        if (presupuesto['cotizaciones'] != null) {
          final cotizacion = presupuesto['cotizaciones'];
          final double? distancia = (cotizacion['distancia_km'] as num?)?.toDouble();
          if (distancia != null && distancia > 0) {
            // Radio necesario: la mitad de la distancia + 5km de margen de seguridad,
            // acotado entre 10km y 50km.
            radioKm = (distancia / 2 + 5.0).clamp(10.0, 50.0);
          }
        }
      }
    } catch (e) {
      // Fallback a logs de debug; la simulación sigue corriendo con el radio por defecto
      debugPrint('⚠️ [MapaOfflineService] Error buscando datos del viaje $viajeId: $e');
    }

    final int tamanoMB = calcularTamanoEstimadoMB(radioKm);
    onInicioDescarga(radioKm, tamanoMB);

    return iniciarSimulacionDescarga(
      radioKm: radioKm,
      onProgreso: onProgreso,
      onCompletado: onCompletado,
    );
  }
}
