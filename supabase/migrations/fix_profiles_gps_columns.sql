-- ============================================================
-- MIGRACIÓN: Asegurar columnas GPS en profiles y tabla tracking
-- Proyecto: CapitanYA / ElGuiaYa
-- EJECUTAR en Supabase SQL Editor
-- ============================================================

-- PASO 1: Agregar columnas GPS en profiles (safe — no falla si existen)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zona_lat DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zona_lng DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zona_radio_km DOUBLE PRECISION DEFAULT 50;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS disponible BOOLEAN DEFAULT false;

-- PASO 2: Verificar que quedó bien
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name IN ('zona_lat', 'zona_lng', 'zona_radio_km', 'disponible')
ORDER BY column_name;

-- PASO 3: Crear tabla tracking_gps si no existe
-- Guarda el historial de posiciones durante el viaje
CREATE TABLE IF NOT EXISTS tracking_gps (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_id TEXT NOT NULL,
  capitan_id TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  velocidad_kmh DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PASO 4: Habilitar RLS en tracking_gps
ALTER TABLE tracking_gps ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario autenticado puede insertar su propia posición
DROP POLICY IF EXISTS "tgps_insert" ON tracking_gps;
CREATE POLICY "tgps_insert"
ON tracking_gps FOR INSERT TO authenticated
WITH CHECK (auth.uid()::text = capitan_id);

-- El capitán y el pescador del pedido pueden leer el tracking
DROP POLICY IF EXISTS "tgps_select" ON tracking_gps;
CREATE POLICY "tgps_select"
ON tracking_gps FOR SELECT TO authenticated
USING (
  auth.uid()::text = capitan_id
  OR EXISTS (
    SELECT 1 FROM pedidos p 
    WHERE p.id::text = tracking_gps.pedido_id
      AND p.pescador_id::text = auth.uid()::text
  )
);

-- PASO 5: Verificar tabla y políticas
SELECT COUNT(*) as filas FROM tracking_gps;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'tracking_gps' ORDER BY cmd;

