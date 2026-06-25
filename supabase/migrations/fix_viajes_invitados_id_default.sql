-- ============================================================
-- MIGRACIÓN: Fix columna id en viajes_invitados
-- Proyecto: CapitanYA / ElGuiaYa
-- EJECUTAR en Supabase SQL Editor
-- ============================================================

-- El error: "null value in column id violates not-null constraint"
-- Causa: la columna 'id' no tiene DEFAULT uuid autogenerado

-- PASO 1: Agregar default UUID a la columna id
ALTER TABLE viajes_invitados 
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- PASO 2: Verificar que quedó bien
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'viajes_invitados'
  AND column_name = 'id';
