import 'package:flutter/material.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/services/branding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  print('Actualizando configuracion...');
  final success = await BrandingService.actualizarConfiguracionLogin(
    backgroundUrl: 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg',
  );
  
  if (success) {
    print('Fondo actualizado con exito.');
  } else {
    print('Error al actualizar el fondo.');
  }
}
