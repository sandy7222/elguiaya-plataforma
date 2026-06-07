
-- SCRIPT PARA REPARAR LA TABLA DE PERFILES (PGRST204)
-- Ejecutar esto en el SQL Editor de Supabase

-- 1. Agregar columnas faltantes para la documentación del Capitán
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS dni_url TEXT,
ADD COLUMN IF NOT EXISTS carnet_url TEXT,
ADD COLUMN IF NOT EXISTS seguro_url TEXT,
ADD COLUMN IF NOT EXISTS embarcacion_url TEXT,
ADD COLUMN IF NOT EXISTS es_capitan BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS estado TEXT DEFAULT 'activo',
ADD COLUMN IF NOT EXISTS verificado BOOLEAN DEFAULT false;

-- 2. Comentario de seguridad para RLS (opcional)
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 3. Forzar recarga del Schema Cache de PostgREST
NOTIFY pgrst, 'reload schema';
