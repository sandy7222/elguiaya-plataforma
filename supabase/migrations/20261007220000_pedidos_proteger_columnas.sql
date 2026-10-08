-- Seguridad: columnas sensibles de public.pedidos que un participante (comprador, pescador, cliente, capitán) NO puede cambiar solo.
--
-- Contexto: después de cerrar la escritura pública (20261007210000), un participante todavía puede actualizar CUALQUIER columna de SU pedido. Este
-- disparador limita las que ninguna pantalla de cliente escribe legítimamente (revisado en el código de la app el 2026-10-07):
--   1. identidad del pedido: capitan_id, pescador_id, cliente_id (y usuario_id salvo que sea para ponerse uno mismo);
--   2. cierre manual y observaciones del administrador: cierre_manual_admin / _por / _at, admin_observaciones;
--   3. despacho y seguimiento (los carga el administrador): tracking_codigo / _url / _cargado_at / _transportista, despachado_at, entregado_at;
--   4. estado_logistico: un cliente solo puede dejarlo en pendiente_pago, preparando o sin_envio (despachado / entregado son del administrador);
--   5. con un pago APROBADO registrado: mp_payment_id, monto_total, total, tarifa_envio, envio_tarifa_monto, envio_tarifa_id (no se cambia el importe de lo ya pagado).
--
-- Pasan sin restricción: administradores (public.is_admin()), la clave de servicio (Edge Functions), las funciones internas SECURITY DEFINER (corren con otro rol)
-- y las migraciones. Solo se vigila al rol `authenticated` / `anon` que escribe directo desde la app.
--
-- NO se limitan `estado` ni los datos mp_* mientras no haya pago registrado: hoy la confirmación de un pago la hace la app del cliente (confirmarPagoPedido) y
-- webhook_logs tiene 0 filas (el webhook de Mercado Pago nunca procesó nada). Cerrarlo requiere pasar esa confirmación al servidor (ver docs/ESTADO.md).

begin;

create or replace function public.trg_pedidos_proteger_columnas()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_col text;
  v_pago_aprobado boolean;
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if (select public.is_admin()) then
    return new;
  end if;

  -- Un pago "registrado" cuenta como aprobado salvo que Mercado Pago haya dicho otra cosa (rechazado, pendiente...): así se puede reintentar tras un rechazo.
  v_pago_aprobado := old.mp_payment_id is not null
                     and coalesce(old.mp_raw_response ->> 'status', 'approved') = 'approved';

  if new.capitan_id is distinct from old.capitan_id then
    v_col := 'capitan_id';
  elsif new.pescador_id is distinct from old.pescador_id then
    v_col := 'pescador_id';
  elsif new.cliente_id is distinct from old.cliente_id then
    v_col := 'cliente_id';
  elsif new.usuario_id is distinct from old.usuario_id and new.usuario_id is distinct from (select auth.uid()) then
    v_col := 'usuario_id';
  elsif new.cierre_manual_admin is distinct from old.cierre_manual_admin then
    v_col := 'cierre_manual_admin';
  elsif new.cierre_manual_por is distinct from old.cierre_manual_por then
    v_col := 'cierre_manual_por';
  elsif new.cierre_manual_at is distinct from old.cierre_manual_at then
    v_col := 'cierre_manual_at';
  elsif new.admin_observaciones is distinct from old.admin_observaciones then
    v_col := 'admin_observaciones';
  elsif new.tracking_codigo is distinct from old.tracking_codigo then
    v_col := 'tracking_codigo';
  elsif new.tracking_url is distinct from old.tracking_url then
    v_col := 'tracking_url';
  elsif new.tracking_cargado_at is distinct from old.tracking_cargado_at then
    v_col := 'tracking_cargado_at';
  elsif new.tracking_transportista is distinct from old.tracking_transportista then
    v_col := 'tracking_transportista';
  elsif new.despachado_at is distinct from old.despachado_at then
    v_col := 'despachado_at';
  elsif new.entregado_at is distinct from old.entregado_at then
    v_col := 'entregado_at';
  elsif new.estado_logistico is distinct from old.estado_logistico
        and new.estado_logistico not in ('pendiente_pago', 'preparando', 'sin_envio') then
    v_col := 'estado_logistico';
  elsif v_pago_aprobado and new.mp_payment_id is distinct from old.mp_payment_id then
    v_col := 'mp_payment_id (con pago aprobado)';
  elsif v_pago_aprobado and new.monto_total is distinct from old.monto_total then
    v_col := 'monto_total (con pago aprobado)';
  elsif v_pago_aprobado and new.total is distinct from old.total then
    v_col := 'total (con pago aprobado)';
  elsif v_pago_aprobado and new.tarifa_envio is distinct from old.tarifa_envio then
    v_col := 'tarifa_envio (con pago aprobado)';
  elsif v_pago_aprobado and new.envio_tarifa_monto is distinct from old.envio_tarifa_monto then
    v_col := 'envio_tarifa_monto (con pago aprobado)';
  elsif v_pago_aprobado and new.envio_tarifa_id is distinct from old.envio_tarifa_id then
    v_col := 'envio_tarifa_id (con pago aprobado)';
  end if;

  if v_col is not null then
    raise exception 'No autorizado: la columna % del pedido solo la cambia un administrador', v_col
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pedidos_proteger_columnas on public.pedidos;
create trigger trg_pedidos_proteger_columnas
  before update on public.pedidos
  for each row
  execute function public.trg_pedidos_proteger_columnas();

commit;
