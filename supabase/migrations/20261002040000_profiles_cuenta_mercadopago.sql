-- Cuenta de Mercado Pago del capitan (reemplaza CBU / banco en los formularios).
-- BORRADOR: revisar antes de aplicar. No contiene secretos.
--
--  * mp_cuenta_email : correo de la cuenta MP que declara el capitan (editable por el dueno).
--  * mp_user_id / mp_vinculado / mp_vinculado_at : resultado de la vinculacion OAuth. SOLO el
--    servidor los puede escribir (un usuario no puede declararse "vinculado").
-- No se tocan ni se borran cbu / banco_nombre / alias_pago: quedan por compatibilidad y para
-- el flujo de billetera existente hasta que se decida el modelo de cobro.

alter table public.profiles
  add column if not exists mp_cuenta_email text,
  add column if not exists mp_user_id text,
  add column if not exists mp_vinculado boolean not null default false,
  add column if not exists mp_vinculado_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_mp_cuenta_email_formato;
alter table public.profiles
  add constraint profiles_mp_cuenta_email_formato
  check (mp_cuenta_email is null or mp_cuenta_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

-- Campos de privilegio: se agregan los de vinculacion a la proteccion existente.
create or replace function public.profiles_proteger_privilegios()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.admin := false;
    new.verificado := false;
    new.es_capitan_verificado := false;
    new.esta_baneado := false;
    new.mp_user_id := null;
    new.mp_vinculado := false;
    new.mp_vinculado_at := null;
    return new;
  end if;

  if new.admin is distinct from old.admin
     or new.verificado is distinct from old.verificado
     or new.es_capitan_verificado is distinct from old.es_capitan_verificado
     or new.esta_baneado is distinct from old.esta_baneado
     or new.estado_cuenta is distinct from old.estado_cuenta
     or new.motivo_baneo is distinct from old.motivo_baneo
     or new.motivo_suspension is distinct from old.motivo_suspension
     or new.baneado_por_email is distinct from old.baneado_por_email
     or new.fecha_verificacion is distinct from old.fecha_verificacion
     or new.role is distinct from old.role
     or new.mp_user_id is distinct from old.mp_user_id
     or new.mp_vinculado is distinct from old.mp_vinculado
     or new.mp_vinculado_at is distinct from old.mp_vinculado_at then
    raise exception 'No autorizado a modificar campos de privilegio del perfil'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Si el capitan cambia su correo de MP, la vinculacion anterior deja de valer.
create or replace function public.profiles_invalidar_vinculo_mp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE'
     and new.mp_cuenta_email is distinct from old.mp_cuenta_email
     and old.mp_vinculado then
    new.mp_vinculado := false;
    new.mp_user_id := null;
    new.mp_vinculado_at := null;
  end if;
  return new;
end;
$$;

revoke all on function public.profiles_invalidar_vinculo_mp() from public, anon, authenticated;

-- El nombre empieza con "z" a proposito: Postgres ejecuta los triggers BEFORE en orden alfabetico y este
-- debe correr DESPUES de trg_profiles_proteger_privilegios (que compararia el reseteo como un cambio ajeno).
drop trigger if exists trg_profiles_z_invalidar_vinculo_mp on public.profiles;
create trigger trg_profiles_z_invalidar_vinculo_mp
  before update of mp_cuenta_email on public.profiles
  for each row execute function public.profiles_invalidar_vinculo_mp();
