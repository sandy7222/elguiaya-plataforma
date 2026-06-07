-- SQL Migration: Creación de tabla config_sistema y políticas RLS robustas usando auth.jwt()
CREATE TABLE IF NOT EXISTS config_sistema (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mp_public_key TEXT,
  mp_access_token TEXT,
  is_sandbox BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE config_sistema ENABLE ROW LEVEL SECURITY;

-- 1. Eliminar políticas antiguas si existen
DROP POLICY IF EXISTS "Only admins can select config_sistema" ON config_sistema;
DROP POLICY IF EXISTS "Only admins can insert config_sistema" ON config_sistema;
DROP POLICY IF EXISTS "Only admins can update config_sistema" ON config_sistema;
DROP POLICY IF EXISTS "Only admins can delete config_sistema" ON config_sistema;

-- 2. Crear nuevas políticas seguras basadas en auth.jwt() sin consultar auth.users
CREATE POLICY "Only admins can select config_sistema" ON config_sistema
  FOR SELECT USING (
    auth.role() = 'authenticated' AND (
      (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
      auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
      auth.jwt() ->> 'role' = 'admin' OR
      auth.jwt() ->> 'rol' = 'admin'
    )
  );

CREATE POLICY "Only admins can insert config_sistema" ON config_sistema
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND (
      (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
      auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
      auth.jwt() ->> 'role' = 'admin' OR
      auth.jwt() ->> 'rol' = 'admin'
    )
  );

CREATE POLICY "Only admins can update config_sistema" ON config_sistema
  FOR UPDATE USING (
    auth.role() = 'authenticated' AND (
      (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
      auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
      auth.jwt() ->> 'role' = 'admin' OR
      auth.jwt() ->> 'rol' = 'admin'
    )
  );

CREATE POLICY "Only admins can delete config_sistema" ON config_sistema
  FOR DELETE USING (
    auth.role() = 'authenticated' AND (
      (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
      auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
      auth.jwt() ->> 'role' = 'admin' OR
      auth.jwt() ->> 'rol' = 'admin'
    )
  );

-- Insertar registro semilla inicial si no existe
INSERT INTO config_sistema (mp_public_key, mp_access_token, is_sandbox)
SELECT 'APP_USR-dummy-public-key', 'APP_USR-dummy-access-token', true
WHERE NOT EXISTS (SELECT 1 FROM config_sistema);
