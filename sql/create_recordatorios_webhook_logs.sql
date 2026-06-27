-- ============================================================
-- MIGRACIÓN URGENTE: Tablas faltantes para el sistema de viajes
-- Aplicar en Supabase Dashboard > SQL Editor
-- Fecha: 2026-06-25
-- ============================================================

-- 1. TABLA DE RECORDATORIOS (para WhatsApp 7d, 3d, 24h, 12h antes del viaje)
CREATE TABLE IF NOT EXISTS recordatorios (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reserva_id TEXT NOT NULL,
  cliente_id UUID NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('7dias', '3dias', '24hs', '1dia')),
  fecha_programada TIMESTAMPTZ NOT NULL,
  fecha_envio TIMESTAMPTZ,
  estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'enviado', 'fallido', 'cancelado')),
  mensaje_id TEXT,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para el scheduler (busca por estado + fecha)
CREATE INDEX IF NOT EXISTS idx_recordatorios_estado_fecha 
  ON recordatorios(estado, fecha_programada);

-- Índice para consultas por cliente
CREATE INDEX IF NOT EXISTS idx_recordatorios_cliente 
  ON recordatorios(cliente_id);

-- Índice para consultas por reserva
CREATE INDEX IF NOT EXISTS idx_recordatorios_reserva 
  ON recordatorios(reserva_id);

-- RLS: Solo el propio usuario o el admin puede ver sus recordatorios
ALTER TABLE recordatorios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recordatorios_select_own" ON recordatorios
  FOR SELECT USING (
    cliente_id = auth.uid() OR 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "recordatorios_insert_service" ON recordatorios
  FOR INSERT WITH CHECK (true); -- El servicio backend los crea

CREATE POLICY "recordatorios_update_service" ON recordatorios
  FOR UPDATE USING (true); -- El scheduler los actualiza

-- ============================================================

-- 2. TABLA DE WEBHOOK LOGS (para auditar Mercado Pago)
CREATE TABLE IF NOT EXISTS webhook_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  webhook_type TEXT,
  action TEXT,
  payment_id TEXT,
  reserva_id TEXT,
  request_body JSONB,
  response_body JSONB,
  status TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsqueda por payment_id
CREATE INDEX IF NOT EXISTS idx_webhook_logs_payment 
  ON webhook_logs(payment_id);

-- Índice para búsqueda por reserva
CREATE INDEX IF NOT EXISTS idx_webhook_logs_reserva 
  ON webhook_logs(reserva_id);

-- RLS: Solo admins pueden leer los logs
ALTER TABLE webhook_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "webhook_logs_admin_only" ON webhook_logs
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "webhook_logs_insert_service" ON webhook_logs
  FOR INSERT WITH CHECK (true); -- Cualquier servicio puede insertar logs

-- ============================================================

-- 3. VERIFICACIÓN: Ver estado actual de cotizaciones expiradas de Martha
SELECT 
  id,
  descripcion,
  estado,
  created_at,
  expira_en,
  CASE 
    WHEN expira_en < NOW() THEN '⏰ VENCIDA'
    ELSE '✅ ACTIVA'
  END AS vigencia
FROM cotizaciones
WHERE pescador_id = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf'
ORDER BY created_at DESC;

-- ============================================================

-- 4. EXTENDER expiración de cotizaciones activas de Martha a 7 días
-- (para pruebas futuras y como política general)
UPDATE cotizaciones 
SET expira_en = created_at + INTERVAL '7 days'
WHERE pescador_id = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf'
  AND estado = 'pendiente'
  AND expira_en < NOW();

-- Verificar resultado
SELECT id, descripcion, estado, expira_en 
FROM cotizaciones 
WHERE pescador_id = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf'
ORDER BY created_at DESC;
