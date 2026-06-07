-- 1. Enable Realtime for profiles and cotizaciones
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cotizaciones'
  ) then
    alter publication supabase_realtime add table cotizaciones;
  end if;
end;
$$;

-- 2. Add public SELECT policy to cotizaciones so the dashboard can stream them
do $$
begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'cotizaciones' and policyname = 'Permitir lectura general de cotizaciones'
  ) then
    create policy "Permitir lectura general de cotizaciones"
    on cotizaciones for select
    using (true);
  end if;
end;
$$;

-- 3. Forzar recarga del Schema Cache
NOTIFY pgrst, 'reload schema';

-- 4. Asegurar que punto_destino exista en cotizaciones
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS punto_destino JSONB;

-- 5. Backfill existing quotes that have null punto_partida but non-null coordenadas_partida
update cotizaciones
set punto_partida = coordenadas_partida,
    punto_destino = coordenadas_destino
where punto_partida is null and coordenadas_partida is not null;


