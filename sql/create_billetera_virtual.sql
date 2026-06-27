-- ══════════════════════════════════════════════════════════════════════════════
-- BILLETERA VIRTUAL DEL CAPITÁN — Tablas Supabase
-- Período de disputa: 48 horas (acordado)
-- Comisión plataforma: 15%
--
-- Ejecutar en Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- ─── 1. Billetera: saldo actual por capitán ────────────────────────────────────
CREATE TABLE IF NOT EXISTS billetera_capitanes (
  capitan_id        UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  saldo_disponible  NUMERIC(12,2) NOT NULL DEFAULT 0,  -- listo para retirar
  saldo_pendiente   NUMERIC(12,2) NOT NULL DEFAULT 0,  -- en período de disputa (48hs)
  saldo_retenido    NUMERIC(12,2) NOT NULL DEFAULT 0,  -- transferencia en proceso
  total_cobrado     NUMERIC(12,2) NOT NULL DEFAULT 0,  -- acumulado histórico
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ─── 2. Movimientos: registro de cada crédito/débito ──────────────────────────
CREATE TABLE IF NOT EXISTS movimientos_billetera (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  capitan_id       UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pedido_id        UUID         REFERENCES pedidos(id),
  liquidacion_id   UUID,        -- referencia a liquidaciones (se completa al retirar)
  tipo             TEXT         NOT NULL,
  -- tipos válidos:
  --   'ingreso_viaje'     → viaje cerrado, dinero acreditado (pendiente 48hs)
  --   'retiro_solicitado' → capitán solicitó transferencia
  --   'retiro_completado' → transferencia procesada exitosamente
  --   'retiro_fallido'    → transferencia rechazada, dinero devuelto a disponible
  --   'disputa_congelada' → se abrió una disputa, fondos bloqueados
  --   'disputa_resuelta'  → disputa cerrada a favor del capitán
  monto_bruto      NUMERIC(12,2) NOT NULL DEFAULT 0,
  comision         NUMERIC(12,2) NOT NULL DEFAULT 0,
  monto_neto       NUMERIC(12,2) NOT NULL DEFAULT 0,
  estado           TEXT         NOT NULL DEFAULT 'pendiente',
  -- estados: pendiente → disponible | procesando → completado | fallido
  disponible_desde TIMESTAMPTZ, -- para tipo='ingreso_viaje': cuándo pasan a disponible
  liberado_at      TIMESTAMPTZ, -- cuándo se liberó efectivamente
  descripcion      TEXT,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT tipo_valido CHECK (tipo IN (
    'ingreso_viaje', 'retiro_solicitado', 'retiro_completado',
    'retiro_fallido', 'disputa_congelada', 'disputa_resuelta'
  )),
  CONSTRAINT estado_valido CHECK (estado IN (
    'pendiente', 'disponible', 'procesando', 'completado', 'fallido', 'congelado'
  ))
);

-- ─── 3. Liquidaciones: solicitudes de transferencia al banco ──────────────────
CREATE TABLE IF NOT EXISTS liquidaciones (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  capitan_id     UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  monto          NUMERIC(12,2) NOT NULL,
  cbu            TEXT         NOT NULL,       -- CBU o CVU (22 dígitos sin espacios)
  alias          TEXT,
  banco          TEXT,
  estado         TEXT         NOT NULL DEFAULT 'solicitado',
  -- solicitado → procesando → completado | fallido
  comprobante    TEXT,                        -- número de transferencia del banco
  descripcion    TEXT,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  procesado_at   TIMESTAMPTZ,

  CONSTRAINT estado_liq_valido CHECK (estado IN (
    'solicitado', 'procesando', 'completado', 'fallido', 'cancelado'
  ))
);

-- ─── Índices para performance ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_movimientos_capitan
  ON movimientos_billetera (capitan_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_movimientos_pendientes
  ON movimientos_billetera (estado, disponible_desde)
  WHERE estado = 'pendiente';

CREATE INDEX IF NOT EXISTS idx_liquidaciones_capitan
  ON liquidaciones (capitan_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_liquidaciones_pendientes
  ON liquidaciones (estado)
  WHERE estado IN ('solicitado', 'procesando');

-- ─── Row Level Security ────────────────────────────────────────────────────────
ALTER TABLE billetera_capitanes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_billetera ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidaciones        ENABLE ROW LEVEL SECURITY;

-- El capitán solo ve su propia billetera
CREATE POLICY "capitan_ve_su_billetera" ON billetera_capitanes
  FOR SELECT USING (auth.uid() = capitan_id);

CREATE POLICY "capitan_ve_sus_movimientos" ON movimientos_billetera
  FOR SELECT USING (auth.uid() = capitan_id);

CREATE POLICY "capitan_ve_sus_liquidaciones" ON liquidaciones
  FOR SELECT USING (auth.uid() = capitan_id);

-- Solo el backend (service_role) puede insertar/actualizar
-- (Las políticas INSERT/UPDATE se omiten para que solo el backend las gestione)

-- ─── Columnas necesarias en la tabla pedidos (si no existen) ──────────────────
ALTER TABLE pedidos
  ADD COLUMN IF NOT EXISTS cerrado_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS iniciado_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS finalizado_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS capitan_califico BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pescador_califico BOOLEAN DEFAULT FALSE;

-- ─── FUNCIÓN: liberar pendientes vencidos (para cron de Supabase) ─────────────
-- Puede llamarse desde: Supabase Scheduled Functions cada hora
CREATE OR REPLACE FUNCTION liberar_pendientes_vencidos()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mov RECORD;
BEGIN
  FOR v_mov IN
    SELECT id, capitan_id, monto_neto
    FROM movimientos_billetera
    WHERE estado = 'pendiente'
      AND disponible_desde <= NOW()
  LOOP
    -- Marcar movimiento como disponible
    UPDATE movimientos_billetera
    SET estado = 'disponible', liberado_at = NOW()
    WHERE id = v_mov.id;

    -- Transferir de pendiente → disponible en la billetera
    UPDATE billetera_capitanes
    SET saldo_pendiente  = GREATEST(0, saldo_pendiente  - v_mov.monto_neto),
        saldo_disponible = saldo_disponible + v_mov.monto_neto,
        total_cobrado    = total_cobrado    + v_mov.monto_neto,
        updated_at       = NOW()
    WHERE capitan_id = v_mov.capitan_id;

    RAISE NOTICE 'Movimiento % liberado para capitán %: $%',
      v_mov.id, v_mov.capitan_id, v_mov.monto_neto;
  END LOOP;
END;
$$;

-- ─── CRON: ejecutar la función cada hora (requiere pg_cron extension) ─────────
-- En Supabase → Database → Extensions → activar pg_cron
-- Luego ejecutar:
--
-- SELECT cron.schedule(
--   'liberar-billeteras-48hs',
--   '0 * * * *',            -- cada hora en punto
--   'SELECT liberar_pendientes_vencidos()'
-- );

-- ─── Vista de resumen (útil para el panel admin) ───────────────────────────────
CREATE OR REPLACE VIEW vista_billeteras AS
SELECT
  b.capitan_id,
  p.nombre                         AS nombre_capitan,
  b.saldo_disponible,
  b.saldo_pendiente,
  b.saldo_retenido,
  b.total_cobrado,
  (b.saldo_disponible + b.saldo_pendiente) AS saldo_total,
  b.updated_at
FROM billetera_capitanes b
LEFT JOIN profiles p ON p.user_id = b.capitan_id;
