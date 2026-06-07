-- =========================================================================
-- MIGRACIÓN SQL: Habilitar Visibilidad de Solicitudes para el Administrador
-- =========================================================================

-- 1. Crear política que permite a los Administradores leer todas las cotizaciones
--    (Necesario para el módulo 'SOLICITUDES' del Admin Command Center)
DROP POLICY IF EXISTS "Admins ver todas las cotizaciones" ON public.cotizaciones;

CREATE POLICY "Admins ver todas las cotizaciones"
ON public.cotizaciones FOR SELECT
USING (
  auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
  (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- 2. Crear política que permite a los Administradores actualizar cotizaciones si es necesario
DROP POLICY IF EXISTS "Admins actualizar todas las cotizaciones" ON public.cotizaciones;

CREATE POLICY "Admins actualizar todas las cotizaciones"
ON public.cotizaciones FOR UPDATE
USING (
  auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
  (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- Forzar limpieza y actualización de caché de esquemas en PostgREST
NOTIFY pgrst, 'reload schema';
