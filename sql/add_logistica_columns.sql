-- =========================================================================
-- MIGRACIÓN SQL: Agregar Credenciales de Logística a la Configuración del Sistema
-- =========================================================================

-- 1. Agregar columnas para la pasarela/integrador logístico si no existen
ALTER TABLE public.config_sistema 
ADD COLUMN IF NOT EXISTS logistica_public_key TEXT,
ADD COLUMN IF NOT EXISTS logistica_access_token TEXT,
ADD COLUMN IF NOT EXISTS logistica_is_sandbox BOOLEAN DEFAULT TRUE;

-- Aseguramos caché limpia en PostgREST
NOTIFY pgrst, 'reload schema';
