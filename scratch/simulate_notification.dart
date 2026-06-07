
import 'package:flutter/material.dart';
import 'package:capitanya_master/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  final userId = SupabaseService.currentUserId;
  
  if (userId != null) {
    print('🚀 Enviando notificación de prueba para el usuario: $userId');
    await SupabaseService.enviarNotificacion(
      usuarioId: userId,
      titulo: '¡Zarpamos!',
      mensaje: 'El Capitán Seba Borrego ha aceptado tu solicitud de pesca nocturna.',
      tipo: 'viaje',
    );
    print('✅ Notificación enviada con éxito.');
  } else {
    print('❌ No hay usuario logueado. Por favor, logueate en la app primero.');
  }
}
