-- SCRIPT PARA AGREGAR LA COLUMNA motivo_suspension EN LA TABLA profiles
-- Ejecutar esto en el SQL Editor de Supabase para solucionar el error PGRST204 al activar un Capitán

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS motivo_suspension TEXT;

-- Forzar recarga del Schema Cache de PostgREST para que Supabase reconozca la nueva columna de inmediato
NOTIFY pgrst, 'reload schema';
