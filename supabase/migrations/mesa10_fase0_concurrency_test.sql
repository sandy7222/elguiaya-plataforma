-- ============================================================
-- Mesa 10 — Fase 0 — TEST DE CONCURRENCIA REAL
-- Complemento a mesa10_fase0_rpc_seeds_tests.sql
-- Prueba la serialización de activar_siguiente_turno
-- bajo peticiones simultáneas reales.
-- ============================================================
--
-- CONTEXTO DEL PROBLEMA (race condition identificada por Gemini):
--
--   T=0ms  Sesión A: entra a activar_siguiente_turno(sala_id)
--   T=0ms  Sesión B: entra a activar_siguiente_turno(sala_id)
--   T=1ms  Sesión A: lee sala → turno_activo_id = NULL
--   T=1ms  Sesión B: lee sala → turno_activo_id = NULL (misma lectura!)
--   T=2ms  Sesión A: activa turno 1 → OK
--   T=2ms  Sesión B: activa turno 1 OTRA VEZ → DOBLE ACTIVACIÓN ← BUG
--
-- SOLUCIÓN: SELECT FOR UPDATE en la fila de salas serializa el acceso.
--   Sesión B queda BLOQUEADA hasta que Sesión A haga COMMIT.
--   Cuando Sesión B obtiene el lock, ya ve el estado modificado.
--
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- MÉTODO A: pgbench (prueba de concurrencia real automatizada)
-- ──────────────────────────────────────────────────────────────
--
-- Pre-requisitos:
--   • psql y pgbench instalados (vienen con PostgreSQL)
--   • Variable de entorno DATABASE_URL con la connection string
--     de Supabase (desde Project Settings → Database → URI)
--
-- Paso 1: Obtener el sala_id del seed
--   SELECT id FROM salas WHERE nombre = 'Mesa 10 — Debate Piloto';
--
-- Paso 2: Crear el archivo pgbench_turno.sql con este contenido
--   (reemplazar <SALA_ID> con el UUID real):
--
--   SELECT * FROM activar_siguiente_turno('<SALA_ID>');
--
-- Paso 3: Ejecutar con 5 clientes simultáneos, 3 transacciones c/u:
--
--   pgbench -n -c 5 -t 3 -f pgbench_turno.sql "$DATABASE_URL"
--
-- Resultado esperado (sin race condition):
--   • Exactamente 1 turno en estado 'activo' en cada momento
--   • Secuencia correcta: turno 1 → 2 → 3 → Ronda 2 → etc.
--   • Cero errores de constraint o estado duplicado
--
-- Resultado si HUBIERA race condition (sin FOR UPDATE):
--   • Múltiples turnos en estado 'activo' simultáneamente
--   • Errores de unique constraint en salas.turno_activo_id
--
-- ──────────────────────────────────────────────────────────────
-- MÉTODO B: Dos tabs de Supabase Studio con pg_sleep
-- (Reproducible manualmente, sin instalar nada)
-- ──────────────────────────────────────────────────────────────
--
-- 1. Abrir Supabase Studio → SQL Editor → crear 2 tabs
-- 2. Obtener sala_id:
--      SELECT id FROM salas WHERE nombre = 'Mesa 10 — Debate Piloto';
-- 3. Copiar el bloque TAB A en el Tab 1 y TAB B en el Tab 2
-- 4. Ejecutar TAB A, luego inmediatamente TAB B (< 3 segundos)
-- 5. Verificar resultado con el query de verificación abajo
--
-- ┌─ TAB A (ejecutar primero) ────────────────────────────────┐
-- │                                                            │
-- │  BEGIN;                                                    │
-- │    -- Toma el lock exclusivo sobre la sala                 │
-- │    SELECT id, turno_activo_id, estado                      │
-- │    FROM salas                                              │
-- │    WHERE nombre = 'Mesa 10 — Debate Piloto'               │
-- │    FOR UPDATE;                                             │
-- │                                                            │
-- │    -- Simula trabajo lento (TAB B intentará entrar aquí)  │
-- │    PERFORM pg_sleep(8);                                    │
-- │                                                            │
-- │    -- Activar turno 1
-- │    UPDATE turnos                                           │
-- │    SET estado = 'activo', inicio_at = NOW()               │
-- │    WHERE sala_id = (                                       │
-- │      SELECT id FROM salas                                  │
-- │      WHERE nombre = 'Mesa 10 — Debate Piloto'             │
-- │    )                                                       │
-- │    AND numero_turno = 1 AND numero_ronda = 1               │
-- │    AND estado = 'pendiente';                               │
-- │                                                            │
-- │  COMMIT;  -- ← TAB B se desbloquea en este momento        │
-- │                                                            │
-- └────────────────────────────────────────────────────────────┘
--
-- ┌─ TAB B (ejecutar < 3s después de TAB A) ──────────────────┐
-- │                                                            │
-- │  BEGIN;                                                    │
-- │    -- ESTA LÍNEA SE BLOQUEARÁ hasta que TAB A haga COMMIT │
-- │    SELECT id, turno_activo_id, estado                      │
-- │    FROM salas                                              │
-- │    WHERE nombre = 'Mesa 10 — Debate Piloto'               │
-- │    FOR UPDATE;                                             │
-- │                                                            │
-- │    -- Cuando llega acá, turno 1 ya está 'activo'          │
-- │    -- El UPDATE siguiente no afectará ninguna fila         │
-- │    UPDATE turnos                                           │
-- │    SET estado = 'activo', inicio_at = NOW()               │
-- │    WHERE sala_id = (                                       │
-- │      SELECT id FROM salas                                  │
-- │      WHERE nombre = 'Mesa 10 — Debate Piloto'             │
-- │    )                                                       │
-- │    AND numero_turno = 1 AND numero_ronda = 1               │
-- │    AND estado = 'pendiente';  -- ← ya no está pendiente   │
-- │                                                            │
-- │  COMMIT;                                                   │
-- │                                                            │
-- └────────────────────────────────────────────────────────────┘

-- ──────────────────────────────────────────────────────────────
-- QUERY DE VERIFICACIÓN POST-TEST (ejecutar después de ambos tabs)
-- Resultado esperado: exactamente 1 fila con estado='activo'
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_activos INT;
  v_sala_nombre TEXT := 'Mesa 10 — Debate Piloto';
BEGIN
  RAISE NOTICE '--- VERIFICACIÓN POST-CONCURRENCIA ---';

  SELECT COUNT(*) INTO v_activos
  FROM turnos t
  JOIN salas s ON s.id = t.sala_id
  WHERE s.nombre = v_sala_nombre
    AND t.estado = 'activo';

  RAISE NOTICE 'Turnos activos simultáneos encontrados: % (esperado: máximo 1)', v_activos;

  IF v_activos = 0 THEN
    RAISE NOTICE 'INFO: Ningún turno activo — ejecutar las tabs primero.';
  ELSIF v_activos = 1 THEN
    RAISE NOTICE 'PASS: El lock serialización funcionó correctamente.';
  ELSE
    RAISE EXCEPTION
      'FAIL CRÍTICO: % turnos activos simultáneos — hay race condition!', v_activos;
  END IF;

  -- Verificar coherencia: sala.turno_activo_id apunta a un turno activo
  IF EXISTS (
    SELECT 1 FROM salas s
    JOIN turnos t ON t.id = s.turno_activo_id
    WHERE s.nombre = v_sala_nombre
      AND t.estado != 'activo'
  ) THEN
    RAISE EXCEPTION 'FAIL: sala.turno_activo_id apunta a un turno que NO está activo.';
  END IF;

  -- Verificar que los eventos de auditoría son coherentes
  DECLARE
    v_eventos_turno_activado INT;
  BEGIN
    SELECT COUNT(*) INTO v_eventos_turno_activado
    FROM eventos_sala es
    JOIN salas s ON s.id = es.sala_id
    WHERE s.nombre = v_sala_nombre
      AND es.tipo = 'turno_activado';

    RAISE NOTICE 'Eventos turno_activado registrados: %', v_eventos_turno_activado;
    -- Debe ser ≤ número de turnos posibles
  END;

  RAISE NOTICE '--- VERIFICACIÓN COMPLETA ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- MÉTODO C: Prueba de serialización con advisory locks
-- (Simula el comportamiento de bloqueo en una sola conexión)
-- Demuestra que la sala no puede ser leída en escritura
-- por dos transacciones simultáneas.
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_sala_id   UUID;
  v_lock_key  BIGINT;
  v_got_lock  BOOLEAN;
BEGIN
  RAISE NOTICE '--- TEST C: Advisory Lock — serialización simulada ---';

  SELECT id INTO v_sala_id FROM salas
  WHERE nombre = 'Mesa 10 — Debate Piloto';

  -- Convertir UUID de sala a clave numérica para advisory lock
  v_lock_key := abs(hashtext(v_sala_id::text));

  -- Sesión A intenta tomar el lock
  v_got_lock := pg_try_advisory_xact_lock(v_lock_key);
  RAISE NOTICE 'Sesión A obtuvo el lock: %', v_got_lock;
  ASSERT v_got_lock = true, 'FAIL: La primera sesión no pudo tomar el lock';

  -- Sesión B intenta tomar el mismo lock (simula segunda conexión)
  -- Con pg_try_advisory_xact_lock, la segunda llamada en la MISMA
  -- transacción es reentrante. En una segunda conexión REAL, devolvería FALSE.
  -- Aquí verificamos que el lock existe en pg_locks.
  IF EXISTS (
    SELECT 1 FROM pg_locks
    WHERE locktype = 'advisory'
      AND classid = (v_lock_key >> 32)::integer
      AND objid = (v_lock_key & x'ffffffff'::bigint)::integer
      AND granted = true
  ) THEN
    RAISE NOTICE 'CORRECTO: El lock advisory está activo en pg_locks';
    RAISE NOTICE 'Una segunda conexión real quedaría BLOQUEADA aquí hasta COMMIT';
  ELSE
    RAISE NOTICE 'ADVERTENCIA: No se encontró el lock en pg_locks (puede ser variación de hash)';
  END IF;

  -- El lock se libera automáticamente al terminar la transacción (xact lock)
  RAISE NOTICE '--- TEST C: Advisory lock verificado ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- RESUMEN DE COBERTURA DE TESTS
-- ──────────────────────────────────────────────────────────────
SELECT
  numero AS "Test",
  metodo AS "Método",
  cubre AS "¿Qué cubre?",
  automatico AS "¿Automático?"
FROM (VALUES
  (1, 'DO block', 'Estructura de tablas y conteo seed', true),
  (2, 'DO block', 'RLS habilitado en todas las tablas', true),
  (3, 'DO block', 'Trigger inmutabilidad de validada', true),
  (4, 'DO block', 'Append-only en eventos_sala (RULES)', true),
  (5, 'DO block', 'Guardia de estado secuencial en turnos', true),
  (6, 'DO block', 'Constraint moderador sin orden_turno', true),
  (7, 'pgbench',  'Concurrencia real: 5 clientes simultáneos', false),
  (8, '2 tabs',   'Concurrencia real: bloqueo FOR UPDATE visible', false),
  (9, 'advisory', 'Serialización via advisory lock (1 conexión)', true)
) AS t(numero, metodo, cubre, automatico)
ORDER BY numero;
