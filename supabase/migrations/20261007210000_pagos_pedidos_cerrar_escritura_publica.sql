-- Seguridad: cerrar la escritura (y la lectura) pública de public.pagos y public.pedidos (hallazgo del 2026-10-07).
--
-- Problema:
--  · pedidos: la política "Admin gestiona pedidos" (FOR ALL, TO public, USING true) dejaba que CUALQUIERA con la clave anónima leyera
--    (dirección, CUIT/DNI de facturación, pagos de Mercado Pago), modificara o borrara pedidos.
--  · pagos: "Permitir crear pagos" (INSERT true), "Permitir actualizar pagos" (UPDATE true) y "Permitir lectura general" (SELECT true)
--    dejaban crear, cambiar (por ejemplo marcar "reembolsado") y leer todos los pagos.
--
-- Qué se conserva (la app lo necesita; los viajes se crean con pescador_id, no con usuario_id: los 5 pedidos actuales tienen usuario_id nulo):
--  · el comprador / pescador / cliente / capitán de un pedido sigue pudiendo crearlo y actualizarlo;
--  · el administrador (public.is_admin()) puede todo;
--  · las Edge Functions (service_role) no pasan por RLS;
--  · las políticas de lectura propias de pedidos no se tocan.
-- Lo que deja de funcionar a propósito: que alguien sin sesión, o ajeno al pedido, lea o escriba pedidos y pagos.
-- Pendiente (otro paso): un participante todavía puede cambiar columnas sensibles de SU pedido (estado, montos, mp_*); hay que limitarlo.

begin;

-- ── pagos (0 filas: nunca se usó; la app guarda el pago real en pedidos.mp_*) ──────────────────────────────────────────────
drop policy if exists "Permitir crear pagos" on public.pagos;
drop policy if exists "Permitir lectura general" on public.pagos;
drop policy if exists "Permitir actualizar pagos" on public.pagos;

create policy "Usuarios ven sus pagos" on public.pagos
  for select to authenticated
  using (usuario_id = (select auth.uid()) or (select public.is_admin()));

create policy "Usuarios crean sus pagos" on public.pagos
  for insert to authenticated
  with check (usuario_id = (select auth.uid()) or (select public.is_admin()));

create policy "Admins gestionan pagos" on public.pagos
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ── pedidos ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "Admin gestiona pedidos" on public.pedidos;
-- La política de admin por claims del token ("role"/"rol" = 'admin') no la cumple ningún usuario real: se reemplaza por is_admin().
drop policy if exists "Admins gestionan todos los pedidos" on public.pedidos;

create policy "Admins gestionan todos los pedidos" on public.pedidos
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- Crear: quien figura como usuario, pescador o cliente del pedido (los viajes se crean con pescador_id).
create policy "Participantes crean sus pedidos" on public.pedidos
  for insert to authenticated
  with check (
    usuario_id = (select auth.uid())
    or pescador_id = (select auth.uid())
    or cliente_id = (select auth.uid())
  );

-- Actualizar: solo quienes participan del pedido. El WITH CHECK impide "regalar" el pedido a otra persona y quedar afuera.
create policy "Participantes actualizan sus pedidos" on public.pedidos
  for update to authenticated
  using (
    usuario_id = (select auth.uid())
    or pescador_id = (select auth.uid())
    or cliente_id = (select auth.uid())
    or capitan_id = (select auth.uid())
  )
  with check (
    usuario_id = (select auth.uid())
    or pescador_id = (select auth.uid())
    or cliente_id = (select auth.uid())
    or capitan_id = (select auth.uid())
  );

commit;
