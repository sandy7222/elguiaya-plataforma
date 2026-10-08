-- Seguridad: cerrar la escritura pública de public.productos (hallazgo del 2026-10-07).
--
-- Problema: la política "Admin full access productos" (FOR ALL, TO public, USING true) dejaba que CUALQUIERA con la clave anónima
-- (que va dentro de la app web) insertara, modificara o borrara productos: precios, stock, activo, todo.
--
-- Por qué no alcanza con borrarla:
--  1. El disparador tr_descontar_stock (AFTER INSERT en pedido_items) ejecuta descontar_stock_pedido(), que NO era SECURITY DEFINER:
--     corría con los permisos del comprador y solo podía actualizar productos gracias a esa política abierta. Se la pasa a SECURITY DEFINER
--     (el search_path ya estaba fijado) para que el descuento de stock siga funcionando sin dar permisos de escritura a los compradores.
--     De paso arregla el descuento del stock de las variantes, que para un comprador ya estaba bloqueado por la política de producto_variantes.
--  2. La política "Admins gestionan productos" miraba claims `role`/`rol` = 'admin' en el token, que Supabase no trae (el rol es
--     'authenticated'); por eso el panel de admin dependía de la política abierta. Se la reemplaza por public.is_admin(), que ya usan
--     otras tablas (producto_variantes_admin) y que reconoce app_metadata.role = 'admin' o profiles.admin = true.
--
-- Lo que sigue funcionando: lectura pública del catálogo (políticas de SELECT, sin cambios), compras (el disparador), y todas las
-- pantallas de administrador (catálogo, inventario, banners, importación) con un usuario admin.
-- Lo que deja de funcionar a propósito: escribir en productos sin ser administrador.

begin;

alter function public.descontar_stock_pedido() security definer;
alter function public.descontar_stock_pedido() set search_path = public, pg_temp;

drop policy if exists "Admin full access productos" on public.productos;
drop policy if exists "Admins gestionan productos" on public.productos;

create policy "Admins gestionan productos"
  on public.productos
  for all
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

commit;
