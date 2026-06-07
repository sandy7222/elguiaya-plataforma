
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('YOUR_SUPABASE_URL', 'YOUR_SUPABASE_KEY');

  print('--- INICIANDO CARGA DE PRUEBA PRO 2026 ---');

  // 1. Crear Atributos en el Diccionario (si no existen)
  final attrRes = await supabase.from('atributos').upsert([
    {'nombre': 'Rulemanes', 'unidad': 'BB'},
    {'nombre': 'Relación', 'unidad': ':1'},
    {'nombre': 'Freno Máximo', 'unidad': 'kg'},
    {'nombre': 'Peso', 'unidad': 'gr'},
    {'nombre': 'Acción', 'unidad': null},
  ]).select();

  print('Diccionario actualizado.');

  // 2. Crear Producto
  final prodRes = await supabase.from('productos').insert({
    'nombre': 'Reel Shimano Curado K 200',
    'descripcion': 'El estándar de oro para el baitcasting. Engranajes MicroModule, sistema de frenado SVS Infinity y durabilidad legendaria.',
    'precio': 345000.0,
    'stock': 5,
    'rubro': 'PESCA',
    'categoria_id': '00000000-0000-0000-0000-000000000000', // Reemplazar con ID real si es necesario
    'imagen_url': 'https://images.unsplash.com/photo-1622321453228-2d88a442750e?q=80&w=1974&auto=format&fit=crop',
    'activo': true,
  }).select().single();

  final prodId = prodRes['id'];
  print('Producto creado: $prodId');

  // 3. Vincular Atributos a la Ficha Técnica
  final List<Map<String, dynamic>> fichaTecnica = [];
  
  for (var attr in attrRes) {
    String valor = '';
    if (attr['nombre'] == 'Rulemanes') valor = '6+1';
    if (attr['nombre'] == 'Relación') valor = '7.4';
    if (attr['nombre'] == 'Freno Máximo') valor = '5';
    if (attr['nombre'] == 'Peso') valor = '215';
    if (attr['nombre'] == 'Acción') valor = 'Fast';

    fichaTecnica.add({
      'producto_id': prodId,
      'atributo_id': attr['id'],
      'valor': valor,
    });
  }

  await supabase.from('producto_atributos').insert(fichaTecnica);

  print('Ficha Técnica vinculada exitosamente.');
  print('--- PRUEBA COMPLETADA ---');
}
