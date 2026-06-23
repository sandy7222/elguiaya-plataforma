-- 1. Habilitar Realtime para las tablas de notificaciones
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notificaciones'
  ) then
    alter publication supabase_realtime add table notificaciones;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notificaciones_globales'
  ) then
    alter publication supabase_realtime add table notificaciones_globales;
  end if;
end;
$$;

-- 2. Habilitar RLS en ambas tablas
alter table if exists public.notificaciones enable row level security;
alter table if exists public.notificaciones_globales enable row level security;

-- 3. Crear Políticas de Seguridad para la tabla public.notificaciones
do $$
begin
  -- SELECT
  drop policy if exists "Usuarios pueden leer sus propias notificaciones" on public.notificaciones;
  create policy "Usuarios pueden leer sus propias notificaciones" 
  on public.notificaciones for select 
  using (auth.uid() = usuario_id or (auth.jwt() ->> 'role' = 'service_role'));

  -- UPDATE (para marcar como leída)
  drop policy if exists "Usuarios pueden actualizar sus propias notificaciones" on public.notificaciones;
  create policy "Usuarios pueden actualizar sus propias notificaciones" 
  on public.notificaciones for update 
  using (auth.uid() = usuario_id or (auth.jwt() ->> 'role' = 'service_role'));

  -- INSERT (para que el sistema u otros usuarios envíen avisos)
  drop policy if exists "Cualquier usuario o sistema puede insertar notificaciones" on public.notificaciones;
  create policy "Cualquier usuario o sistema puede insertar notificaciones" 
  on public.notificaciones for insert 
  with check (true);

  -- DELETE
  drop policy if exists "Usuarios pueden borrar sus propias notificaciones" on public.notificaciones;
  create policy "Usuarios pueden borrar sus propias notificaciones" 
  on public.notificaciones for delete 
  using (auth.uid() = usuario_id);
end;
$$;

-- 4. Crear Políticas de Seguridad para la tabla public.notificaciones_globales
do $$
begin
  -- SELECT
  drop policy if exists "Usuarios pueden leer sus notificaciones globales" on public.notificaciones_globales;
  create policy "Usuarios pueden leer sus notificaciones globales" 
  on public.notificaciones_globales for select 
  using (auth.uid() = receptor_id or (auth.jwt() ->> 'role' = 'service_role'));

  -- UPDATE
  drop policy if exists "Usuarios pueden actualizar sus notificaciones globales" on public.notificaciones_globales;
  create policy "Usuarios pueden actualizar sus notificaciones globales" 
  on public.notificaciones_globales for update 
  using (auth.uid() = receptor_id or (auth.jwt() ->> 'role' = 'service_role'));

  -- INSERT
  drop policy if exists "Cualquier usuario o sistema puede insertar notificaciones globales" on public.notificaciones_globales;
  create policy "Cualquier usuario o sistema puede insertar notificaciones globales" 
  on public.notificaciones_globales for insert 
  with check (true);

  -- DELETE
  drop policy if exists "Usuarios pueden borrar sus notificaciones globales" on public.notificaciones_globales;
  create policy "Usuarios pueden borrar sus notificaciones globales" 
  on public.notificaciones_globales for delete 
  using (auth.uid() = receptor_id);
end;
$$;

-- 5. Recargar schema cache
notify pgrst, 'reload schema';
