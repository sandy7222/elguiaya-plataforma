-- Arreglo: la tienda (elguiaya.com/tienda) no cargaba porque la lectura pública del blog fallaba (hallazgo del 2026-10-08).
--
-- Causa: la política "Lectura de articulos" (SELECT, TO public) decía  activo = true OR (es admin: consulta public.profiles).
-- La Fase 2 de seguridad (20261001000000) le quitó al visitante anónimo el permiso de leer public.profiles, así que Postgres cancela
-- TODA la consulta con "permission denied for table profiles" aunque el artículo esté activo. La tienda pide productos, categorías,
-- banners y blog juntos: si falla una, muestra "Error al cargar la tienda".
--
-- Arreglo: separar en dos políticas. El visitante lee solo artículos activos (sin tocar profiles). El administrador (usuario con sesión)
-- sigue viendo todos, con la misma condición de antes (el correo legado o profiles.admin).
-- No cambia quién puede escribir (las políticas de insertar, actualizar y eliminar no se tocan).

begin;

drop policy if exists "Lectura de articulos" on public.blog_articulos;

create policy "Lectura publica de articulos activos" on public.blog_articulos
  for select to anon, authenticated
  using (activo = true);

create policy "Admins leen todos los articulos" on public.blog_articulos
  for select to authenticated
  using (
    ((select auth.jwt()) ->> 'email') = 'admin@capitanya.com'
    or exists (
      select 1 from public.profiles p
      where p.user_id = (select auth.uid()) and p.admin = true
    )
  );

commit;
