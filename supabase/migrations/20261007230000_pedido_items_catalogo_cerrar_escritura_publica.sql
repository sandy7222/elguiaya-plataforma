-- Seguridad: cerrar la lectura/escritura pública de pedido_items, categorias, rubros y envio_domicilio (hallazgo del 2026-10-07).
--
-- Problema:
--  · categorias y rubros: "Admin full access ..." (FOR ALL, TO public, USING true): cualquiera con la clave anónima podía crear, cambiar o borrar categorías y rubros del catálogo.
--  · envio_domicilio (nombre, teléfono, correo y dirección de entrega de los compradores): "Admin gestiona envio_domicilio" (FOR ALL, TO public, USING true): cualquiera
--    podía leer y modificar todas las direcciones.
--  · pedido_items: "Ver items pedidos" (SELECT true) mostraba los ítems de TODOS los pedidos y "Crear items pedidos" (INSERT true) dejaba insertar ítems en cualquier pedido
--    (cada INSERT dispara el descuento de stock). Además las políticas "propias" miraban solo pedidos.usuario_id, y los viajes se crean con pescador_id (usuario_id nulo).
--
-- Qué se conserva:
--  · la lectura pública de categorias y rubros (el catálogo la necesita, también sin sesión);
--  · el dueño de una dirección sigue gestionándola (las dos políticas "propias" de envio_domicilio no se tocan);
--  · el comprador / pescador / cliente de un pedido crea y ve los ítems de SU pedido (el capitán también los ve);
--  · el administrador (public.is_admin()) puede todo; las Edge Functions (service_role) no pasan por RLS.
-- Lo que deja de funcionar a propósito: que alguien sin sesión o ajeno al pedido lea o escriba estos datos.

begin;

-- ── categorias ────────────────────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "Admin full access categorias" on public.categorias;
drop policy if exists "Admins gestionan categorias" on public.categorias;
create policy "Admins gestionan categorias" on public.categorias
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ── rubros ────────────────────────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "Admin full access rubros" on public.rubros;
drop policy if exists "Admins gestionan rubros" on public.rubros;
create policy "Admins gestionan rubros" on public.rubros
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ── envio_domicilio ───────────────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "Admin gestiona envio_domicilio" on public.envio_domicilio;
create policy "Admins gestionan envio_domicilio" on public.envio_domicilio
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- ── pedido_items ──────────────────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "Ver items pedidos" on public.pedido_items;
drop policy if exists "Crear items pedidos" on public.pedido_items;
drop policy if exists "Usuarios ven sus propios items de pedidos" on public.pedido_items;
drop policy if exists "Usuarios crean sus propios items de pedidos" on public.pedido_items;
drop policy if exists "Admins gestionan todos los items de pedidos" on public.pedido_items;

create policy "Admins gestionan todos los items de pedidos" on public.pedido_items
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "Participantes ven los items de su pedido" on public.pedido_items
  for select to authenticated
  using (exists (
    select 1 from public.pedidos p
    where p.id = pedido_items.pedido_id
      and (p.usuario_id = (select auth.uid())
        or p.pescador_id = (select auth.uid())
        or p.cliente_id = (select auth.uid())
        or p.capitan_id = (select auth.uid()))
  ));

create policy "Participantes crean los items de su pedido" on public.pedido_items
  for insert to authenticated
  with check (exists (
    select 1 from public.pedidos p
    where p.id = pedido_items.pedido_id
      and (p.usuario_id = (select auth.uid())
        or p.pescador_id = (select auth.uid())
        or p.cliente_id = (select auth.uid()))
  ));

commit;
