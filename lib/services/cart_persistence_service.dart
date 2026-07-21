import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/producto.dart';
import '../models/tipo_checkout.dart';
import '../services/viaje_lifecycle_service.dart';

/// Persistencia local del carrito + hidratación desde pedidos pendientes de pago.
class CartPersistenceService {
  static const _prefsKey = 'elguia_cart_v1';

  static Future<void> guardar({
    required String? userId,
    required String? pedidoViajeId,
    required List<CartItem> items,
  }) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'user_id': userId,
        'pedido_viaje_id': pedidoViajeId,
        'items': items
            .map(
              (i) => {
                'id': i.id,
                'cantidad': i.cantidad,
                'addedAt': i.addedAt.toIso8601String(),
                'producto': i.producto.toMap(),
                'varianteId': i.varianteId,
                'varianteColor': i.varianteColor,
                'varianteImagenUrl': i.varianteImagenUrl,
                'precioUnitarioOverride': i.precioUnitarioOverride,
              },
            )
            .toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('⚠️ CartPersistenceService.guardar: $e');
    }
  }

  static Future<CartSnapshot?> cargar(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['user_id']?.toString() != userId) return null;

      final itemsRaw = data['items'] as List<dynamic>? ?? [];
      final items = itemsRaw.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return CartItem(
          id: map['id']?.toString() ?? '',
          cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
          addedAt: DateTime.tryParse(map['addedAt']?.toString() ?? '') ??
              DateTime.now(),
          producto: Producto.fromSupabase(
            Map<String, dynamic>.from(map['producto'] as Map),
          ),
          varianteId: map['varianteId']?.toString(),
          varianteColor: map['varianteColor']?.toString(),
          varianteImagenUrl: map['varianteImagenUrl']?.toString(),
          precioUnitarioOverride:
              (map['precioUnitarioOverride'] as num?)?.toDouble(),
        );
      }).toList();

      return CartSnapshot(
        pedidoViajeId: data['pedido_viaje_id']?.toString(),
        items: items,
      );
    } catch (e) {
      debugPrint('⚠️ CartPersistenceService.cargar: $e');
      return null;
    }
  }

  static Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Hidrata carrito desde un pedido pendiente de pago (viaje + productos).
  static Future<CartSnapshot?> hidratarDesdePedido(String pedidoId) async {
    try {
      final supabase = Supabase.instance.client;
      final pedido = await supabase
          .from('pedidos')
          .select(
            'id, estado, monto_total, presupuesto_id, presupuestos(cotizacion_id, monto, detalles, capitan_id), pedido_items(*, producto:productos(*))',
          )
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido == null) return null;
      final estado = pedido['estado']?.toString() ?? '';
      if (!ViajeLifecycleService.requierePago(estado)) return null;

      final items = <CartItem>[];
      final presupuesto = pedido['presupuestos'] as Map<String, dynamic>?;
      final cotizacionId = presupuesto?['cotizacion_id']?.toString() ?? '';

      if (cotizacionId.isNotEmpty) {
        final cot = await supabase
            .from('cotizaciones')
            .select('descripcion, fecha_ida, hora_encuentro')
            .eq('id', cotizacionId)
            .maybeSingle();

        final capitanId = presupuesto?['capitan_id']?.toString() ?? '';
        String nombreCapitan = 'Capitán';
        if (capitanId.isNotEmpty) {
          final perfil = await supabase
              .from('profiles')
              .select('nombre, avatar_url')
              .eq('user_id', capitanId)
              .maybeSingle();
          nombreCapitan = perfil?['nombre']?.toString() ?? nombreCapitan;
        }

        final montoViaje =
            (presupuesto?['monto'] as num?)?.toDouble() ??
            (pedido['monto_total'] as num?)?.toDouble() ??
            0.0;
        final descripcion =
            cot?['descripcion']?.toString() ??
            presupuesto?['detalles']?.toString() ??
            'Viaje náutico';
        final fechaIda = cot?['fecha_ida']?.toString().split('T').first ?? '';
        final hora = cot?['hora_encuentro']?.toString() ?? '';
        final fechaLabel = fechaIda.isNotEmpty
            ? (hora.isNotEmpty ? '$fechaIda $hora' : fechaIda)
            : 'Por confirmar';

        final productoViaje = Producto(
          id: 'viaje_$cotizacionId',
          nombre: 'VIAJE: $descripcion',
          descripcion: 'Capitán: $nombreCapitan - Fecha: $fechaLabel',
          precio: montoViaje,
          stock: 1,
          rubro: 'viaje',
          categoriaId: 'viajes',
          imagenUrl: 'assets/images/logo_elguiaya_white.png',
          activo: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        items.add(CartItem(
          id: 'viaje_${pedidoId}_item',
          producto: productoViaje,
          cantidad: 1,
          addedAt: DateTime.now(),
        ));
      }

      final pedidoItems = pedido['pedido_items'] as List<dynamic>? ?? [];
      for (final raw in pedidoItems) {
        final row = Map<String, dynamic>.from(raw as Map);
        final productoData = row['producto'] as Map<String, dynamic>?;
        if (productoData == null) continue;
        final producto = Producto.fromSupabase(productoData);
        items.add(CartItem(
          id: row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          producto: producto,
          cantidad: (row['cantidad'] as num?)?.toInt() ?? 1,
          addedAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
        ));
      }

      return CartSnapshot(pedidoViajeId: pedidoId, items: items);
    } catch (e) {
      debugPrint('⚠️ CartPersistenceService.hidratarDesdePedido: $e');
      return null;
    }
  }

  /// Busca el pedido pendiente de pago más reciente del pescador.
  static Future<CartSnapshot?> hidratarPedidoPendiente(String pescadorId) async {
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('pedidos')
          .select('id')
          .eq('pescador_id', pescadorId)
          .inFilter('estado', ['pendiente_pago', 'pago_pendiente'])
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return null;
      final pedidoId = rows.first['id']?.toString();
      if (pedidoId == null || pedidoId.isEmpty) return null;
      return hidratarDesdePedido(pedidoId);
    } catch (e) {
      debugPrint('⚠️ CartPersistenceService.hidratarPedidoPendiente: $e');
      return null;
    }
  }
}

class CartSnapshot {
  final String? pedidoViajeId;
  final List<CartItem> items;

  const CartSnapshot({this.pedidoViajeId, required this.items});

  TipoCheckout get tipoCheckout => combinarTipoCheckout(
        tieneTienda: items.any((i) => i.producto.rubro.toLowerCase() != 'viaje'),
        tieneViaje: items.any((i) => i.producto.rubro.toLowerCase() == 'viaje'),
      );
}
