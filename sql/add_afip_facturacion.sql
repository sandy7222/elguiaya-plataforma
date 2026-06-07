-- ============================================================
-- MIGRACIÓN: Módulo de Facturación Electrónica AFIP
-- Agrega columnas de configuración AFIP a config_sistema
-- El sistema arranca INACTIVO por defecto (afip_facturacion_activa = false)
-- ============================================================

-- 1. Agregar columnas AFIP a config_sistema (idempotente con IF NOT EXISTS)
ALTER TABLE public.config_sistema
  ADD COLUMN IF NOT EXISTS afip_api_token TEXT,
  ADD COLUMN IF NOT EXISTS afip_facturacion_activa BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS afip_entorno VARCHAR(20) NOT NULL DEFAULT 'sandbox'
    CHECK (afip_entorno IN ('sandbox', 'homologacion', 'produccion'));

-- 2. Comentarios descriptivos para documentar el schema
COMMENT ON COLUMN public.config_sistema.afip_api_token IS
  'API Key / Token del servicio de facturación electrónica AFIP. NULL = no configurado.';
COMMENT ON COLUMN public.config_sistema.afip_facturacion_activa IS
  'Interruptor maestro de facturación electrónica. FALSE = sistema en modo standby (sin emitir facturas).';
COMMENT ON COLUMN public.config_sistema.afip_entorno IS
  'Entorno de operación AFIP: sandbox (pruebas locales), homologacion (certificación AFIP), produccion (real).';

-- 3. Crear tabla de log de facturas emitidas (audit trail permanente)
CREATE TABLE IF NOT EXISTS public.facturas_afip (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id       UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE RESTRICT,
  dni_cliente     VARCHAR(20) NOT NULL,
  monto           DECIMAL(12, 2) NOT NULL,
  tipo_comprobante VARCHAR(10) NOT NULL DEFAULT 'FC_B',   -- FC_A, FC_B, NCA, NCB
  numero_cae      VARCHAR(14),                            -- CAE asignado por AFIP (NULL en sandbox)
  vencimiento_cae DATE,                                   -- Vencimiento del CAE
  entorno         VARCHAR(20) NOT NULL DEFAULT 'sandbox',
  estado          VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente', 'emitida', 'error', 'omitida')),
  motivo_omision  TEXT,                                   -- Mensaje cuando afip_facturacion_activa = false
  payload_request JSONB,                                  -- Payload enviado al servicio AFIP
  payload_response JSONB,                                 -- Respuesta cruda del servicio AFIP
  error_detalle   TEXT,                                   -- Detalle en caso de error
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Índices de rendimiento para facturas_afip
CREATE INDEX IF NOT EXISTS idx_facturas_afip_pedido_id  ON public.facturas_afip(pedido_id);
CREATE INDEX IF NOT EXISTS idx_facturas_afip_estado     ON public.facturas_afip(estado);
CREATE INDEX IF NOT EXISTS idx_facturas_afip_dni        ON public.facturas_afip(dni_cliente);
CREATE INDEX IF NOT EXISTS idx_facturas_afip_created_at ON public.facturas_afip(created_at DESC);

-- 5. Trigger para updated_at automático en facturas_afip
CREATE OR REPLACE FUNCTION public.set_facturas_afip_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_facturas_afip_updated_at ON public.facturas_afip;
CREATE TRIGGER trg_facturas_afip_updated_at
  BEFORE UPDATE ON public.facturas_afip
  FOR EACH ROW EXECUTE FUNCTION public.set_facturas_afip_updated_at();

-- 6. RLS para facturas_afip (solo admins acceden)
ALTER TABLE public.facturas_afip ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins pueden ver todas las facturas" ON public.facturas_afip;
CREATE POLICY "Admins pueden ver todas las facturas" ON public.facturas_afip
  FOR SELECT USING (
    auth.role() = 'authenticated' AND (
      (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
      auth.jwt() ->> 'rol' = 'admin' OR
      auth.jwt() ->> 'role' = 'admin'
    )
  );

DROP POLICY IF EXISTS "Servicio puede insertar facturas" ON public.facturas_afip;
CREATE POLICY "Servicio puede insertar facturas" ON public.facturas_afip
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Servicio puede actualizar facturas" ON public.facturas_afip;
CREATE POLICY "Servicio puede actualizar facturas" ON public.facturas_afip
  FOR UPDATE USING (auth.role() = 'authenticated');
