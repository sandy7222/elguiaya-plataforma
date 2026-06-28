-- ============================================================
-- Mesa 10 — pgbench transaction script
-- Archivo: mesa10_pgbench_turno.sql
-- USO: pgbench -f este_archivo.sql ... (ver mesa10_pgbench_run.ps1)
-- ============================================================
-- pgbench ejecuta este bloque desde N clientes simultáneos.
-- Cada cliente lo repite T veces.
-- El SELECT FOR UPDATE garantiza que solo 1 cliente a la vez
-- puede modificar la sala — los demás esperan en el lock.
-- ============================================================

-- Simular contexto de usuario autenticado (moderador)
-- Supabase lee request.jwt.claims para auth.uid()
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  false
);

-- La llamada a la RPC: cada cliente intenta avanzar el turno.
-- Con SELECT FOR UPDATE interno, solo uno gana a la vez.
SELECT
  turno_id,
  alias,
  numero_ronda,
  numero_turno,
  sala_estado
FROM activar_siguiente_turno(
  (SELECT id FROM salas WHERE nombre = 'Mesa 10 — Debate Piloto' LIMIT 1)
);
