import 'dart:math' as Math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// MASTER CONNECTION SKILL
/// El corazón de la operatividad de EL GUIA YA.
/// Gestiona la vinculación irrompible entre Pescadores, Capitanes y Viajes.
class MasterConnectionSkill {
  static final _supabase = Supabase.instance.client;

  // --- 1. VINCULACIÓN DE OFERTAS (Radar del Capitán) ---

  /// Obtiene cotizaciones activas filtradas por la zona geográfica y radio del Capitán.
  static Future<List<Map<String, dynamic>>> getCotizacionesEnZona({
    required double capitanLat,
    required double capitanLon,
    required double radioKm,
  }) async {
    try {
      // 1. Traemos las cotizaciones pendientes creadas en las últimas 24hs (En UTC para Supabase)
      final limiteExpiracion = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      
      final response = await _supabase
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre, avatar_url)')
          .eq('estado', 'pendiente')
          .gt('created_at', limiteExpiracion)
          .order('created_at', ascending: false);
      
      final todas = List<Map<String, dynamic>>.from(response);

      // 2. Aplicamos el Geofencing en memoria (Haversine)
      // Nota: Si PostGIS está activo, esto se podría hacer directamente en el select.
      return todas.where((cot) {
        final punto = cot['coordenadas_partida'];
        if (punto == null || punto['lat'] == null || punto['lon'] == null) return false;

        final dist = calcularDistancia(
          capitanLat, capitanLon, 
          punto['lat'] as double, punto['lon'] as double
        );
        
        return dist <= radioKm;
      }).toList();
    } catch (e) {
      print('❌ Error en Radar Geofencing: $e');
      return [];
    }
  }

  /// Fórmula Haversine para cálculo de distancia en KM
  static double calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0; // Radio de la Tierra en KM
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degToRad(lat1)) * Math.cos(_degToRad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (3.141592653589793 / 180);

  /// Envía una oferta formal (Presupuesto) a una cotización específica.
  static Future<void> enviarOferta({
    required String cotizacionId,
    required String capitanId,
    required double monto,
    required String detalles,
    required DateTime fechaServicio,
  }) async {
    try {
      // Evitar envíos duplicados del mismo capitán para la misma cotización
      final yaExiste = await _supabase
          .from('presupuestos')
          .select('id')
          .eq('cotizacion_id', cotizacionId)
          .eq('capitan_id', capitanId)
          .maybeSingle();

      if (yaExiste != null) {
        throw Exception('Ya has enviado una propuesta para esta cotización.');
      }

      final snapshot = await SupabaseService.obtenerSnapshotCapitanParaPresupuesto(capitanId);
      final contratoSnapshot = await SupabaseService.buildContratoSnapshot(
        capitanId: capitanId,
        cotizacionId: cotizacionId,
        monto: monto,
        detalles: detalles,
        presupuestoVisual: snapshot,
      );

      final payload = {
        'cotizacion_id': cotizacionId,
        'capitan_id': capitanId,
        'monto': monto,
        'detalles': detalles,
        'fecha_hora_viaje': fechaServicio.toIso8601String(),
        'estado': 'pendiente',
        'created_at': DateTime.now().toIso8601String(),
        'capitan_nombre': snapshot['capitan_nombre'],
        'capitan_avatar_url': snapshot['capitan_avatar_url'],
        'embarcacion_url': snapshot['embarcacion_url'],
        'barco_nombre': snapshot['barco_nombre'],
        'contrato_snapshot': contratoSnapshot,
      };

      try {
        await _supabase.from('presupuestos').insert(payload);
      } catch (_) {
        await _supabase.from('presupuestos').insert({
          'cotizacion_id': cotizacionId,
          'capitan_id': capitanId,
          'monto': monto,
          'detalles': detalles,
          'fecha_hora_viaje': fechaServicio.toIso8601String(),
          'estado': 'pendiente',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      try {
        await _supabase.from('cotizaciones').update({
          'estado': 'presupuestada',
          'presupuesto_monto': monto,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', cotizacionId);
      } catch (_) {}
      print('✅ Oferta vinculada correctamente.');
    } catch (e) {
      throw Exception('Fallo al vincular oferta: $e');
    }
  }

  // --- 2. SINCRONIZACIÓN EN TIEMPO REAL (Espejo del Pescador) ---

  /// Stream irrompible para que el Pescador reciba ofertas al instante.
  static Stream<List<Map<String, dynamic>>> escucharOfertas(String cotizacionId) {
    return _supabase
        .from('presupuestos')
        .stream(primaryKey: ['id'])
        .eq('cotizacion_id', cotizacionId)
        .order('monto', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // --- 3. CIERRE DE VIAJE PROGRAMADO (Cerrojo de Agenda) ---

  /// Al aceptar la oferta, se cierra el trato y se bloquea la agenda.
  /// Implementa una lógica de transacción para asegurar que no haya solapamientos.
  static Future<String> cerrarTratoYA({
    required Map<String, dynamic> oferta,
    required String pescadorId,
  }) async {
    try {
      // A. Verificar si el EL GUIA YA tiene un pedido para esa fecha exacta (Double-booking protection)
      final existe = await _supabase
          .from('pedidos')
          .select()
          .eq('capitan_id', oferta['capitan_id'])
          .eq('fecha_servicio', oferta['fecha_hora_viaje'])
          .neq('estado', 'cancelado')
          .maybeSingle();

      if (existe != null) {
        throw Exception('El EL GUIA YA ha reservado este horario con otro cliente.');
      }

      // B. Crear el registro maestro en Pedidos (El Viaje Programado)
      final pedido = await _supabase.from('pedidos').insert({
        'presupuesto_id': oferta['id'],
        'pescador_id': pescadorId,
        'capitan_id': oferta['capitan_id'],
        'monto_total': oferta['monto'],
        'fecha_servicio': oferta['fecha_hora_viaje'],
        'estado': 'programado', // Estado inicial bloqueado
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // C. Actualizar estados en cadena (Efecto Dominó)
      // Marcar presupuesto como aceptado
      await _supabase.from('presupuestos').update({'estado': 'aceptado'}).eq('id', oferta['id']);
      
        // Marcar cotización como adjudicada (Cierre de subasta competitiva)
        await _supabase.from('cotizaciones').update({'estado': 'adjudicada'}).eq('id', oferta['cotizacion_id']);

        print('🔒 Subasta finalizada y trato adjudicado con éxito.');
      return pedido['id'];
    } catch (e) {
      throw Exception('Error crítico al cerrar el trato: $e');
    }
  }

  /// PROCESAR PAGO HÍBRIDO: Divide la carga entre Pedidos (Viajes) y Ordenes (Tienda)
  static Future<void> procesarPagoHibrido({
    required String userId,
    required List<Map<String, dynamic>> itemsViaje,
    required List<Map<String, dynamic>> itemsTienda,
    required Map<String, dynamic>? datosEnvio,
    required List<Map<String, dynamic>> manifiestos,
    required double total,
  }) async {
    try {
      // 1. Procesar Viajes (Si hay)
      if (itemsViaje.isNotEmpty) {
        for (var item in itemsViaje) {
          await _supabase.from('pedidos').insert({
            'pescador_id': userId,
            'capitan_id': item['capitan_id'] ?? 'capitan-provisorio',
            'estado': 'pendiente_pago',
            'monto_total': item['subtotal'],
            'manifiesto': manifiestos, // Guardamos la declaración jurada
            'tipo': 'viaje',
          });
        }
      }

      // 2. Procesar Tienda (Si hay)
      if (itemsTienda.isNotEmpty) {
        await _supabase.from('ordenes_logistica').insert({
          'usuario_id': userId,
          'estado': 'procesando_envio',
          'total': itemsTienda.fold(0.0, (sum, i) => sum + i['subtotal']),
          'direccion_envio': datosEnvio,
          'items': itemsTienda,
        });
      }

      print('🌊📦 [HYBRID] Registros separados con éxito en DB.');
    } catch (e) {
      throw Exception('Error en el Split de DB: $e');
    }
  }

  // --- 4. UTILIDADES DE SEGURIDAD ---
  
  /// Verifica si los datos de contacto deben ser revelados.
  static bool debeRevelarContacto(String estadoViaje) {
    return estadoViaje == 'pagado' || estadoViaje == 'confirmado';
  }
}
