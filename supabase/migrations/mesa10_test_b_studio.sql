-- ============================================================
-- Mesa 10 — TEST OPCIÓN B: Supabase Studio (dos tabs)
-- Demuestra serialización real del SELECT FOR UPDATE
-- ============================================================
--
-- CÓMO USAR ESTE ARCHIVO:
--   1. Ejecutar SOLO el bloque PASO 0 → obtener sala_id
--   2. Ejecutar SOLO el bloque PASO 1 → reset
--   3. Abrir un segundo tab en el SQL Editor de Supabase
--   4. Copiar el SQL del bloque TAB_A al tab original
--   5. Copiar el SQL del bloque TAB_B al tab nuevo
--   6. Reemplazar <SALA_ID> en ambos con el UUID del PASO 0
--   7. Ejecutar TAB_A → inmediatamente ejecutar TAB_B (< 5s)
--   8. Ejecutar PASO 4 para verificar el resultado
--
-- NOTA IMPORTANTE: NO ejecutar este archivo completo de una vez.
--   Cada bloque está separado. Copiar y pegar cada uno por separado.
-- ============================================================


-- ============================================================
-- PASO 0: Obtener sala_id
-- Ejecutar este bloque solo. Copiar el UUID que devuelve.
-- ============================================================

SELECT
  id            AS sala_id,
  nombre,
  estado,
  ronda_actual,
  turno_activo_id
FROM salas
WHERE nombre = 'Mesa 10 — Debate Piloto';


-- ============================================================
-- PASO 1: Reset — volver todos los turnos a 'pendiente'
-- Reemplazar <SALA_ID> con el UUID del PASO 0.
-- Ejecutar este bloque ANTES de abrir el segundo tab.
-- ============================================================

DO $$
DECLARE
  v_sala_id UUID := '<SALA_ID>';  -- ← REEMPLAZAR
  v_pendientes INT;
BEGIN
  UPDATE salas
  SET
    turno_activo_id = NULL,
    estado          = 'esperando',
    ronda_actual    = 0,
    updated_at      = NOW()
  WHERE id = v_sala_id;

  UPDATE turnos
  SET
    estado    = 'pendiente',
    inicio_at = NULL,
    fin_at    = NULL
  WHERE sala_id = v_sala_id;

  SELECT COUNT(*) INTO v_pendientes
  FROM turnos WHERE sala_id = v_sala_id AND estado = 'pendiente';

  RAISE NOTICE 'Reset OK — turnos pendientes: %', v_pendientes;
END;
$$;


-- ============================================================
-- PASO 2: Abrir el segundo tab en Supabase Studio
-- Clic en el ícono "+" en la barra de tabs del SQL Editor.
-- ============================================================


-- ============================================================
-- TAB_A — Copiar TODO este bloque al tab ORIGINAL (Tab 1)
-- Reemplazar <SALA_ID> con el UUID del PASO 0.
-- NO ejecutar todavía. Primero copiar TAB_B al otro tab.
-- ============================================================
--
-- BEGIN;
--
--   SELECT set_config(
--     'request.jwt.claims',
--     '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
--     true
--   );
--
--   -- ESTE SELECT FOR UPDATE toma el lock exclusivo sobre la sala.
--   -- Tab 2 quedará BLOQUEADA en esta misma línea
--   -- hasta que esta transacción haga COMMIT.
--   SELECT id, estado, turno_activo_id
--   FROM salas
--   WHERE id = '<SALA_ID>'
--   FOR UPDATE;
--
--   -- SELECT pg_sleep simula trabajo lento.
--   -- Da tiempo para que Tab 2 llegue al FOR UPDATE y quede bloqueada.
--   -- Verás el spinner girando en Tab 2 durante estos 10 segundos.
--   SELECT pg_sleep(10);
--
--   -- Activar el turno 1, ronda 1
--   UPDATE turnos
--   SET estado = 'activo', inicio_at = NOW()
--   WHERE sala_id = '<SALA_ID>'
--     AND numero_turno = 1
--     AND numero_ronda = 1
--     AND estado = 'pendiente';
--
--   UPDATE salas
--   SET
--     turno_activo_id = (
--       SELECT id FROM turnos
--       WHERE sala_id = '<SALA_ID>'
--         AND numero_turno = 1
--         AND numero_ronda = 1
--     ),
--     estado       = 'activa',
--     ronda_actual = 1,
--     updated_at   = NOW()
--   WHERE id = '<SALA_ID>';
--
-- COMMIT;
-- -- En este momento Tab 2 se desbloquea automáticamente.


-- ============================================================
-- TAB_B — Copiar TODO este bloque al tab NUEVO (Tab 2)
-- Reemplazar <SALA_ID> con el UUID del PASO 0.
-- Ejecutar Tab 1 primero, luego Tab 2 dentro de los 5 segundos.
-- ============================================================
--
-- BEGIN;
--
--   SELECT set_config(
--     'request.jwt.claims',
--     '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
--     true
--   );
--
--   -- AQUÍ SE BLOQUEA Tab 2.
--   -- El spinner del Studio girará hasta que Tab 1 haga COMMIT.
--   -- Cuando Tab 1 hace COMMIT (después del pg_sleep de 10s),
--   -- esta línea se desbloquea y continúa.
--   SELECT id, estado, turno_activo_id
--   FROM salas
--   WHERE id = '<SALA_ID>'
--   FOR UPDATE;
--
--   -- Cuando llega acá, Tab 1 ya hizo COMMIT.
--   -- El turno 1 ya NO está 'pendiente' → este UPDATE afecta 0 filas.
--   -- Eso es exactamente lo que queremos: sin doble activación.
--   UPDATE turnos
--   SET estado = 'activo', inicio_at = NOW()
--   WHERE sala_id = '<SALA_ID>'
--     AND numero_turno = 1
--     AND numero_ronda = 1
--     AND estado = 'pendiente';
--
--   -- Verificar cuántas filas afectó (debe ser 0)
--   SELECT
--     'Filas afectadas por Tab 2' AS descripcion,
--     COUNT(*) AS turnos_activos_ahora
--   FROM turnos
--   WHERE sala_id = '<SALA_ID>' AND estado = 'activo';
--
-- COMMIT;


-- ============================================================
-- PASO 4: Verificación final
-- Ejecutar DESPUÉS de que ambos tabs hagan COMMIT.
-- Reemplazar <SALA_ID> con el UUID del PASO 0.
-- Resultado esperado: exactamente 1 turno activo.
-- ============================================================

DO $$
DECLARE
  v_sala_id   UUID := '<SALA_ID>';  -- ← REEMPLAZAR
  v_activos   INT;
BEGIN
  SELECT COUNT(*) INTO v_activos
  FROM turnos
  WHERE sala_id = v_sala_id AND estado = 'activo';

  RAISE NOTICE '======================================';
  RAISE NOTICE 'Turnos activos: % (esperado: 1)', v_activos;

  IF v_activos = 1 THEN
    RAISE NOTICE 'PASS — SELECT FOR UPDATE previno la race condition';
  ELSIF v_activos = 0 THEN
    RAISE NOTICE 'INFO — Ningún turno activo. Ejecutar los tabs primero.';
  ELSE
    RAISE EXCEPTION 'FAIL — % turnos activos simultáneos (race condition!)', v_activos;
  END IF;

  -- Verificar coherencia: sala apunta al turno activo correcto
  ASSERT NOT EXISTS (
    SELECT 1 FROM salas s
    JOIN turnos t ON t.id = s.turno_activo_id
    WHERE s.id = v_sala_id
      AND t.estado != 'activo'
  ), 'FAIL: sala.turno_activo_id apunta a un turno que no está activo';

  RAISE NOTICE '======================================';
END;
$$;

-- Vista rápida del estado de todos los turnos
SELECT
  t.numero_ronda                             AS ronda,
  t.numero_turno                             AS turno,
  p.alias,
  t.estado,
  TO_CHAR(t.inicio_at, 'HH24:MI:SS.MS')     AS inicio,
  TO_CHAR(t.fin_at,    'HH24:MI:SS.MS')     AS fin
FROM turnos t
JOIN participantes p ON p.id = t.participante_id
JOIN salas s ON s.id = t.sala_id
WHERE s.nombre = 'Mesa 10 — Debate Piloto'
ORDER BY t.numero_ronda, t.numero_turno;
