// Fase 2 (2.2): la migración de la tabla del registro anónimo está escrita, es segura y NO se aplicó.
//
// No hay base de datos en los tests: se revisa el TEXTO de la migración contra las reglas del plan
// (solo inserción, sin lectura desde la app, sin ID ni hora) y que lo marque como no aplicada.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final archivo = File('supabase/migrations/20261006100000_guia_registro_anonimo.sql');
  late String sql;
  late String sinComentarios;

  setUpAll(() {
    sql = archivo.readAsStringSync();
    sinComentarios = sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n').toLowerCase();
  });

  test('existe y avisa que NO está aplicada y espera el OK del dueño', () {
    expect(archivo.existsSync(), isTrue);
    expect(sql, contains('NO APLICADA'));
    expect(sql, contains('OK'));
  });

  test('la tabla tiene solo texto, decision, version_app y dia (sin ID de usuario ni hora)', () {
    final cuerpo = RegExp(r'create table if not exists public\.guia_registro_anonimo \((.*?)\);', dotAll: true)
        .firstMatch(sinComentarios)!
        .group(1)!;
    final columnas = RegExp(r'^\s*(\w+)\s+(?:text|date|timestamp|timestamptz|uuid|bigint|int|integer)\b', multiLine: true)
        .allMatches(cuerpo)
        .map((m) => m.group(1))
        .toList();
    expect(columnas, ['texto', 'decision', 'version_app', 'dia']);
    expect(cuerpo, isNot(contains('user_id')));
    expect(cuerpo, isNot(contains('auth.uid')));
    expect(cuerpo, isNot(contains('timestamp')));
  });

  test('tiene RLS prendida y solo una política: insertar', () {
    expect(sinComentarios, contains('enable row level security'));
    final politicas = RegExp(r'create policy').allMatches(sinComentarios).length;
    expect(politicas, 1);
    expect(sinComentarios, contains('for insert'));
    for (final prohibido in ['for select', 'for update', 'for delete', 'for all']) {
      expect(sinComentarios, isNot(contains(prohibido)), reason: prohibido);
    }
  });

  test('saca todos los permisos y da SOLO insertar a authenticated (nada a anon)', () {
    expect(sinComentarios, contains('revoke all on table public.guia_registro_anonimo from public, anon, authenticated'));
    expect(sinComentarios, contains('grant insert on table public.guia_registro_anonimo to authenticated'));
    expect(sinComentarios, isNot(contains('to anon')));
    expect(sinComentarios, isNot(contains('grant select')));
    expect(sinComentarios, isNot(contains('grant all')));
  });

  test('limita el largo del texto y exige un día cercano a hoy', () {
    expect(sinComentarios, contains('char_length(texto) between 1 and 300'));
    expect(sinComentarios, contains('current_date'));
  });

  test('trae las consultas de verificación del plan (sin datos del usuario)', () {
    expect(sql, contains('information_schema.columns'));
    expect(sql, contains('pg_policies'));
  });

  test('no hay código de subida en la app todavía (espera la tabla y el OK)', () {
    final hay = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .any((f) => f.readAsStringSync().contains('guia_registro_anonimo'));
    expect(hay, isFalse, reason: 'el subidor no se escribe hasta que el dueño dé el OK de la migración');
  });
}
