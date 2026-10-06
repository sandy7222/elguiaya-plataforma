-- =============================================================================
-- Registro anónimo de las preguntas a El Guía (Fase 2, paso 2.2)
--
--   ⚠️  NO APLICADA. Escrita y revisada, pero NO se corrió en producción: espera el OK explícito
--   del dueño (AGENTS.md, regla 4). Mientras tanto vale la alternativa sin tocar la base:
--   Admin → Sistema → "Registro de preguntas" → EXPORTAR CSV, y mandar el archivo a mano.
--
-- Qué hace:
--   Crea UNA tabla donde los usuarios de prueba pueden SUBIR (solo insertar) las preguntas que le
--   hacen a El Guía, ya limpias de datos personales (ver lib/services/guia_anonimizador.dart).
--   · Sin ID de usuario, sin hora (solo el día), sin ningún dato que identifique a la persona.
--   · La app NO puede leer, modificar ni borrar lo subido: no hay política de select/update/delete.
--   · Solo el dueño lee, desde el SQL Editor de Supabase (que usa el rol de servicio).
--
-- Cómo se aplica (cuando el dueño dé el OK): pegar este archivo en Supabase → SQL Editor → Run.
-- Cómo se deshace: `drop table public.guia_registro_anonimo;` (no la usa nada más).
--
-- Del lado de la app falta: el subidor y el flag `guia_registro_anonimo` (apagado por defecto), y
-- ANTES DEL LANZAMIENTO el aviso al usuario y la opción de no participar en el perfil. No se escribió
-- el subidor todavía: sin esta tabla no tendría adónde subir.
-- =============================================================================

create table if not exists public.guia_registro_anonimo (
  texto       text not null
              check (char_length(texto) between 1 and 300),
  decision    text not null
              check (decision in ('directa', 'aclarar', 'ninguna', 'reglas', 'seguridad', 'nube', 'fallback')),
  version_app text not null
              check (char_length(version_app) between 1 and 40),
  dia         date not null
);

comment on table public.guia_registro_anonimo is
  'Preguntas a El Guía, anónimas (sin usuario ni hora). Solo inserción desde la app; lectura solo con rol de servicio.';

alter table public.guia_registro_anonimo enable row level security;

-- Nadie hereda permisos por defecto: se saca todo y se da SOLO insertar a los usuarios con sesión.
revoke all on table public.guia_registro_anonimo from public, anon, authenticated;
grant insert on table public.guia_registro_anonimo to authenticated;

-- Única política: insertar. El día tiene que ser de hoy (±1 por la zona horaria): evita cargar
-- filas con fechas inventadas. No hay política de select, update ni delete.
drop policy if exists guia_registro_anonimo_insertar on public.guia_registro_anonimo;
create policy guia_registro_anonimo_insertar
  on public.guia_registro_anonimo
  for insert
  to authenticated
  with check (
    dia between (current_date - 1) and (current_date + 1)
    and char_length(texto) between 1 and 300
  );

-- =============================================================================
-- VERIFICACIÓN (después de aplicar; correr de a un bloque en el SQL Editor)
-- =============================================================================
--
-- 1) La tabla no tiene ninguna columna que identifique a una persona (esperado: texto, decision,
--    version_app, dia):
--
--      select column_name, data_type
--      from information_schema.columns
--      where table_schema = 'public' and table_name = 'guia_registro_anonimo'
--      order by ordinal_position;
--
-- 2) La app no puede leer: no hay ninguna política de select (esperado: una sola fila, cmd = INSERT):
--
--      select policyname, cmd, roles
--      from pg_policies
--      where schemaname = 'public' and tablename = 'guia_registro_anonimo';
--
-- 3) Una fila de prueba (la sube el dueño, sin ningún dato suyo) y se ve sin identificarlo:
--
--      insert into public.guia_registro_anonimo (texto, decision, version_app, dia)
--      values ('qué carnada uso para el dorado', 'directa', 'prueba', current_date);
--
--      select * from public.guia_registro_anonimo order by dia desc limit 5;
--
-- 4) Permisos: el rol authenticated solo tiene INSERT (esperado: una fila, privilege_type = INSERT):
--
--      select grantee, privilege_type
--      from information_schema.role_table_grants
--      where table_schema = 'public' and table_name = 'guia_registro_anonimo'
--        and grantee in ('anon', 'authenticated');
-- =============================================================================
