-- Motor de comisiones: tablas faltantes enlazadas a comisionistas, pedidos y profiles.
-- La app Flutter escribe logs_comisiones + saldos al cerrar viajes (procesarComisionesViaje).

-- ─── Saldos acumulados por promotor (comisionista) ───────────────────────────
-- Nota: la columna se llama usuario_id por compatibilidad con Flutter, pero guarda comisionistas.id
CREATE TABLE IF NOT EXISTS public.saldos (
  usuario_id       UUID PRIMARY KEY REFERENCES public.comisionistas(id) ON DELETE CASCADE,
  saldo_disponible NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (saldo_disponible >= 0),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saldos_updated_at ON public.saldos (updated_at DESC);

COMMENT ON TABLE public.saldos IS
  'Billetera de comisiones del promotor. usuario_id = comisionistas.id (legacy naming en Flutter).';

-- ─── Auditoría de reparto del 10% por viaje ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.logs_comisiones (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viaje_id       UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  pescador_id    UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  capitan_id     UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  vendedor_id    UUID REFERENCES public.comisionistas(id) ON DELETE SET NULL,
  monto_viaje    NUMERIC(12,2) NOT NULL DEFAULT 0,
  comision_app   NUMERIC(12,2) NOT NULL DEFAULT 0,
  pago_vendedor  NUMERIC(12,2) NOT NULL DEFAULT 0,
  neta_app       NUMERIC(12,2) NOT NULL DEFAULT 0,
  escenario      TEXT NOT NULL DEFAULT 'SIN_REFERENCIA',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT logs_comisiones_viaje_id_unique UNIQUE (viaje_id),
  CONSTRAINT logs_comisiones_escenario_check CHECK (
    escenario IN ('MATCH', 'CAPITAN', 'PESCADOR', 'EXPIRADO_O_REPETIDO', 'SIN_REFERENCIA')
  )
);

CREATE INDEX IF NOT EXISTS idx_logs_comisiones_created_at
  ON public.logs_comisiones (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_logs_comisiones_vendedor_id
  ON public.logs_comisiones (vendedor_id);

CREATE INDEX IF NOT EXISTS idx_logs_comisiones_capitan_id
  ON public.logs_comisiones (capitan_id);

CREATE INDEX IF NOT EXISTS idx_logs_comisiones_pescador_id
  ON public.logs_comisiones (pescador_id);

CREATE INDEX IF NOT EXISTS idx_logs_comisiones_escenario
  ON public.logs_comisiones (escenario);

COMMENT ON TABLE public.logs_comisiones IS
  'Historial admin del reparto del 10% de comisión por viaje concretado.';

-- ─── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.saldos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_comisiones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin lee saldos comisionistas" ON public.saldos;
CREATE POLICY "Admin lee saldos comisionistas"
ON public.saldos
FOR SELECT
USING (public.is_admin_user());

DROP POLICY IF EXISTS "App upsert saldos comisionistas" ON public.saldos;
CREATE POLICY "App upsert saldos comisionistas"
ON public.saldos
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Admin lee logs comisiones" ON public.logs_comisiones;
CREATE POLICY "Admin lee logs comisiones"
ON public.logs_comisiones
FOR SELECT
USING (public.is_admin_user());

DROP POLICY IF EXISTS "App inserta logs comisiones" ON public.logs_comisiones;
CREATE POLICY "App inserta logs comisiones"
ON public.logs_comisiones
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Inicializar fila de saldo en cero para comisionistas existentes (idempotente)
INSERT INTO public.saldos (usuario_id, saldo_disponible, updated_at)
SELECT c.id, 0, NOW()
FROM public.comisionistas c
ON CONFLICT (usuario_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
