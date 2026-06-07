-- =========================================================================
-- MIGRACIÓN SQL: Agregar Modo Mantenimiento a la Configuración del Sistema
-- =========================================================================

-- 1. Agregar columna 'mantenimiento_tienda' si no existe
ALTER TABLE public.config_sistema 
ADD COLUMN IF NOT EXISTS mantenimiento_tienda BOOLEAN DEFAULT FALSE;

-- 2. Modificar la política de SELECT para que todos los usuarios autenticados 
--    puedan cargar las credenciales de pago e inspeccionar el estado de mantenimiento.
DROP POLICY IF EXISTS "Only admins can select config_sistema" ON public.config_sistema;
DROP POLICY IF EXISTS "Anyone authenticated can select config_sistema" ON public.config_sistema;

CREATE POLICY "Anyone authenticated can select config_sistema" ON public.config_sistema
  FOR SELECT USING (
    auth.role() = 'authenticated'
  );

-- Aseguramos caché limpia en PostgREST
NOTIFY pgrst, 'reload schema';
