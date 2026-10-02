-- MercadoPago producción: columnas MP, webhook_logs, RLS seguro, RPC idempotente.

-- ─── config_sistema ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.config_sistema (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mp_public_key TEXT,
  mp_access_token TEXT,
  is_sandbox BOOLEAN DEFAULT TRUE,
  mantenimiento_tienda BOOLEAN DEFAULT FALSE,
  logistica_public_key TEXT,
  logistica_access_token TEXT,
  logistica_is_sandbox BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.config_sistema ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can select config_sistema" ON public.config_sistema;
DROP POLICY IF EXISTS "Only admins can select config_sistema" ON public.config_sistema;
DROP POLICY IF EXISTS "Only admins can insert config_sistema" ON public.config_sistema;
DROP POLICY IF EXISTS "Only admins can update config_sistema" ON public.config_sistema;
DROP POLICY IF EXISTS "Only admins can delete config_sistema" ON public.config_sistema;

CREATE POLICY "Only admins can select config_sistema" ON public.config_sistema
  FOR SELECT USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'rol' = 'admin'
      )
    )
  );

CREATE POLICY "Only admins can insert config_sistema" ON public.config_sistema
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'rol' = 'admin'
      )
    )
  );

CREATE POLICY "Only admins can update config_sistema" ON public.config_sistema
  FOR UPDATE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'rol' = 'admin'
      )
    )
  );

CREATE POLICY "Only admins can delete config_sistema" ON public.config_sistema
  FOR DELETE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'rol' = 'admin'
      )
    )
  );

INSERT INTO public.config_sistema (mp_public_key, mp_access_token, is_sandbox)
SELECT 'APP_USR-dummy-public-key', 'APP_USR-dummy-access-token', true
WHERE NOT EXISTS (SELECT 1 FROM public.config_sistema);

-- Config pública para la app (sin access token)
CREATE OR REPLACE FUNCTION public.get_mp_public_config()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'mp_public_key', COALESCE(mp_public_key, ''),
    'is_sandbox', COALESCE(is_sandbox, true),
    'mantenimiento_tienda', COALESCE(mantenimiento_tienda, false)
  )
  FROM config_sistema
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_mp_public_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_mp_public_config() TO anon;

-- ─── pedidos: columnas MercadoPago ──────────────────────────────────────────
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS mp_payment_id TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS mp_preference_id TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS mp_external_reference TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS mp_raw_response JSONB;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS metodo_pago TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS monto_total NUMERIC(12,2);
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS contacto_habilitado BOOLEAN DEFAULT FALSE;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS contacto_habilitado_at TIMESTAMPTZ;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS pescador_id UUID;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS capitan_id UUID;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS presupuesto_id UUID;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS cotizacion_id UUID;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS tipo_checkout TEXT DEFAULT 'viaje';
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS estado_logistico TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS numero_pedido TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS reserva_id BIGINT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_pedidos_mp_payment_id_unique
  ON public.pedidos (mp_payment_id)
  WHERE mp_payment_id IS NOT NULL AND mp_payment_id <> '';

CREATE INDEX IF NOT EXISTS idx_pedidos_mp_external_reference
  ON public.pedidos (mp_external_reference);

-- ─── webhook_logs ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.webhook_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  webhook_type TEXT,
  action TEXT,
  payment_id TEXT,
  reserva_id TEXT,
  pedido_id TEXT,
  request_body JSONB,
  response_body JSONB,
  status TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.webhook_logs ADD COLUMN IF NOT EXISTS pedido_id TEXT;

CREATE INDEX IF NOT EXISTS idx_webhook_logs_payment ON public.webhook_logs(payment_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_pedido ON public.webhook_logs(pedido_id);

ALTER TABLE public.webhook_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "webhook_logs_admin_only" ON public.webhook_logs;
DROP POLICY IF EXISTS "webhook_logs_insert_service" ON public.webhook_logs;

CREATE POLICY "webhook_logs_admin_only" ON public.webhook_logs
  FOR SELECT USING (
    auth.role() = 'service_role' OR EXISTS (
      SELECT 1 FROM profiles WHERE user_id = auth.uid() AND rol = 'admin'
    )
  );

CREATE POLICY "webhook_logs_insert_service" ON public.webhook_logs
  FOR INSERT WITH CHECK (true);

-- ─── deduplicación eventos MP ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mp_payment_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  mp_payment_id TEXT NOT NULL,
  pedido_id UUID,
  mp_status TEXT,
  processed_at TIMESTAMPTZ DEFAULT NOW(),
  payload JSONB
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mp_payment_events_unique
  ON public.mp_payment_events (mp_payment_id);

ALTER TABLE public.mp_payment_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mp_payment_events_service" ON public.mp_payment_events;
CREATE POLICY "mp_payment_events_service" ON public.mp_payment_events
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ─── RPC: confirmar pago desde webhook (idempotente) ────────────────────────
CREATE OR REPLACE FUNCTION public.confirmar_pago_pedido_mp(
  p_pedido_id UUID,
  p_mp_payment_id TEXT,
  p_status TEXT,
  p_status_detail TEXT DEFAULT NULL,
  p_transaction_amount NUMERIC DEFAULT NULL,
  p_payment_method_id TEXT DEFAULT NULL,
  p_preference_id TEXT DEFAULT NULL,
  p_date_approved TIMESTAMPTZ DEFAULT NULL,
  p_raw JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_estado TEXT;
  v_tipo TEXT;
BEGIN
  IF p_pedido_id IS NULL OR p_mp_payment_id IS NULL OR p_mp_payment_id = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'parametros_invalidos');
  END IF;

  -- Idempotencia por evento MP
  BEGIN
    INSERT INTO mp_payment_events (mp_payment_id, pedido_id, mp_status, payload)
    VALUES (p_mp_payment_id, p_pedido_id, p_status, p_raw);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', true, 'note', 'evento_ya_procesado');
  END;

  SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'pedido_no_encontrado');
  END IF;

  IF v_pedido.mp_payment_id IS NOT NULL
     AND v_pedido.mp_payment_id = p_mp_payment_id
     AND v_pedido.estado IN ('pagado', 'pago_pendiente') THEN
    RETURN jsonb_build_object('ok', true, 'note', 'ya_confirmado', 'estado', v_pedido.estado);
  END IF;

  IF EXISTS (
    SELECT 1 FROM pedidos
    WHERE mp_payment_id = p_mp_payment_id AND id <> p_pedido_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'mp_payment_id_duplicado');
  END IF;

  v_estado := CASE lower(COALESCE(p_status, ''))
    WHEN 'approved' THEN 'pagado'
    WHEN 'pending' THEN 'pago_pendiente'
    WHEN 'in_process' THEN 'pago_pendiente'
    WHEN 'authorized' THEN 'pago_pendiente'
    ELSE 'pago_rechazado'
  END;

  v_tipo := COALESCE(v_pedido.tipo_checkout, 'viaje');

  UPDATE pedidos SET
    estado = v_estado,
    mp_payment_id = p_mp_payment_id,
    metodo_pago = COALESCE(p_payment_method_id, 'mercado_pago'),
    monto_total = COALESCE(p_transaction_amount, monto_total, total),
    total = COALESCE(p_transaction_amount, total, monto_total),
    mp_preference_id = COALESCE(p_preference_id, mp_preference_id),
    mp_external_reference = p_pedido_id::text,
    mp_raw_response = COALESCE(p_raw, mp_raw_response),
    contacto_habilitado = CASE WHEN lower(p_status) = 'approved' THEN TRUE ELSE contacto_habilitado END,
    contacto_habilitado_at = CASE
      WHEN lower(p_status) = 'approved' THEN COALESCE(contacto_habilitado_at, NOW())
      ELSE contacto_habilitado_at
    END,
    estado_logistico = CASE
      WHEN lower(p_status) = 'approved' AND v_tipo IN ('tienda', 'hibrido') THEN 'preparando'
      WHEN lower(p_status) = 'rejected' AND v_tipo IN ('tienda', 'hibrido') THEN 'sin_envio'
      ELSE estado_logistico
    END,
    updated_at = NOW()
  WHERE id = p_pedido_id;

  -- Notificaciones básicas (el cliente completa side-effects al volver)
  IF lower(p_status) = 'approved' THEN
    IF v_pedido.pescador_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'notificaciones_globales'
    ) THEN
      INSERT INTO notificaciones_globales (
        receptor_id, tipo_actor, categoria, prioridad,
        titulo, contenido, leido, payload, created_at
      )
      VALUES (
        v_pedido.pescador_id,
        'sistema',
        'pago',
        'alta',
        'Pago confirmado',
        'Tu pago fue acreditado correctamente.',
        FALSE,
        jsonb_build_object('tipo', 'pago_confirmado', 'pedido_id', p_pedido_id::text),
        NOW()
      );
    END IF;

    IF v_pedido.capitan_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'notificaciones_globales'
    ) THEN
      INSERT INTO notificaciones_globales (
        receptor_id, tipo_actor, categoria, prioridad,
        titulo, contenido, leido, payload, created_at
      )
      VALUES (
        v_pedido.capitan_id,
        'sistema',
        'pago',
        'alta',
        'Pago recibido',
        'El pescador confirmó el pago del viaje.',
        FALSE,
        jsonb_build_object('tipo', 'pago_confirmado', 'pedido_id', p_pedido_id::text),
        NOW()
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'estado', v_estado,
    'pedido_id', p_pedido_id,
    'pescador_id', v_pedido.pescador_id,
    'capitan_id', v_pedido.capitan_id,
    'tipo_checkout', v_tipo
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_pago_pedido_mp(
  UUID, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, TIMESTAMPTZ, JSONB
) TO service_role;

NOTIFY pgrst, 'reload schema';
