-- ============================================================
-- MIGRACIÓN: Fix RLS + columnas para viajes_invitados
-- Proyecto: CapitanYA / ElGuiaYa
-- EJECUTAR COMPLETO en Supabase SQL Editor
-- ============================================================

-- PASO 1: Agregar columnas faltantes (seguro si ya existen)
ALTER TABLE viajes_invitados ADD COLUMN IF NOT EXISTS pedido_id TEXT;
ALTER TABLE viajes_invitados ADD COLUMN IF NOT EXISTS es_titular BOOLEAN DEFAULT false;
ALTER TABLE viajes_invitados ADD COLUMN IF NOT EXISTS foto_dni_url TEXT;

-- PASO 2: Habilitar RLS
ALTER TABLE viajes_invitados ENABLE ROW LEVEL SECURITY;

-- PASO 3: Eliminar TODAS las políticas existentes de un golpe
DO $$
DECLARE
  pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'viajes_invitados'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON viajes_invitados', pol);
  END LOOP;
END;
$$;

-- PASO 4: Crear políticas correctas
-- NOTA: pescador_id es tipo TEXT, auth.uid() es UUID → se castea con ::text

CREATE POLICY "vi_insert"
ON viajes_invitados FOR INSERT TO authenticated
WITH CHECK (auth.uid()::text = pescador_id);

CREATE POLICY "vi_select"
ON viajes_invitados FOR SELECT TO authenticated
USING (auth.uid()::text = pescador_id);

CREATE POLICY "vi_update"
ON viajes_invitados FOR UPDATE TO authenticated
USING (auth.uid()::text = pescador_id)
WITH CHECK (auth.uid()::text = pescador_id);

CREATE POLICY "vi_delete"
ON viajes_invitados FOR DELETE TO authenticated
USING (auth.uid()::text = pescador_id);

-- PASO 5: Verificar que quedó bien
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'viajes_invitados' ORDER BY cmd;
