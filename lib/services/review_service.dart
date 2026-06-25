import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Inserta una calificación multidimensional en la base de datos de Supabase.
  /// Obtiene automáticamente el id del capitán a partir del viaje [pedidoId].
  static Future<void> submitReview({
    required String pedidoId,
    required double puntualidad,
    required double embarcacion,
    required double guiaPesca,
    required double trato,
    required double equipamiento,
    required String comentario,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Inicie sesión para calificar el viaje.');
    }

    // 1. Obtener los detalles del viaje/pedido para extraer el ID del capitán
    final pedido = await _supabase
        .from('pedidos')
        .select('capitan_id')
        .eq('id', pedidoId)
        .single();

    final String? capitanId = pedido['capitan_id']?.toString();
    if (capitanId == null) {
      throw Exception('No se encontró el capitán asignado a este viaje.');
    }

    // 2. Calcular la calificación general redondeada
    final double promedio = (puntualidad + embarcacion + guiaPesca + trato + equipamiento) / 5.0;
    final int calificacion = promedio.round().clamp(1, 5);

    // 3. Insertar la reseña en la tabla calificaciones_viaje
    await _supabase.from('calificaciones_viaje').insert({
      'pedido_id': pedidoId,
      'calificador_id': currentUser.id,
      'calificado_id': capitanId,
      'calificador_rol': 'pescador',
      'calificacion': calificacion,
      'comentario': comentario,
      'aspectos_puntuados': {
        'puntualidad': puntualidad,
        'embarcacion': embarcacion,
        'guia_pesca': guiaPesca,
        'trato': trato,
        'equipamiento': equipamiento,
      },
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
