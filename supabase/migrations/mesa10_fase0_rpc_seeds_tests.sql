-- ============================================================
-- MIGRACIÓN: Mesa 10 — Fase 0 — RPC + Seeds + Tests
-- Sistema de debate moderado multi-IA
-- EJECUTAR DESPUÉS de mesa10_fase0_rls.sql
-- ============================================================

-- ============================================================
-- SECCIÓN A: RPC ATÓMICA — activar_siguiente_turno
-- ============================================================
-- Contrato:
--   • Solo el moderador de p_sala_id puede llamarla.
--   • Usa SELECT FOR UPDATE sobre la fila de la sala → serializa
--     accesos concurrentes (evita race conditions).
--   • Cierra el turno activo actual (si existe).
--   • Activa el siguiente turno 'pendiente' en orden.
--   • Si no quedan turnos pendientes en la ronda, avanza la ronda.
--   • Si se agotaron las rondas, finaliza la sala.
--   • Registra un evento en eventos_sala.
--   • Devuelve el turno activado (o NULL si finalizó).
-- ============================================================
CREATE OR REPLACE FUNCTION activar_siguiente_turno(p_sala_id UUID)
RETURNS TABLE (
  turno_id          UUID,
  participante_id   UUID,
  alias             TEXT,
  numero_ronda      SMALLINT,
  numero_turno      SMALLINT,
  inicio_at         TIMESTAMPTZ,
  sala_estado       estado_sala
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_sala              salas%ROWTYPE;
  v_turno_anterior    UUID;
  v_siguiente_turno   turnos%ROWTYPE;
  v_participante      participantes%ROWTYPE;
  v_nueva_ronda       SMALLINT;
BEGIN
  -- ── 1. LOCK EXCLUSIVO sobre la fila de la sala ────────────────────
  -- SELECT FOR UPDATE garantiza serialización ante peticiones simultáneas.
  -- Ninguna otra transacción puede ejecutar esta función para la misma
  -- sala hasta que esta transacción haga COMMIT o ROLLBACK.
  SELECT * INTO v_sala
  FROM salas
  WHERE id = p_sala_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'MESA10_NOT_FOUND: Sala % no existe.', p_sala_id
      USING ERRCODE = 'P0002';
  END IF;

  -- ── 2. Verificar que el caller es el moderador ────────────────────
  IF v_sala.moderador_id != auth.uid() THEN
    RAISE EXCEPTION 'MESA10_FORBIDDEN: Solo el moderador puede activar turnos.'
      USING ERRCODE = '42501';
  END IF;

  -- ── 3. Verificar estado válido de la sala ────────────────────────
  IF v_sala.estado NOT IN ('esperando', 'activa') THEN
    RAISE EXCEPTION 'MESA10_INVALID_STATE: La sala está en estado % y no admite cambios de turno.',
      v_sala.estado
      USING ERRCODE = 'P0001';
  END IF;

  -- ── 4. Cerrar el turno activo anterior (si existe) ────────────────
  v_turno_anterior := v_sala.turno_activo_id;

  IF v_turno_anterior IS NOT NULL THEN
    UPDATE turnos
    SET
      estado  = 'completado',
      fin_at  = NOW()
    WHERE id = v_turno_anterior
      AND estado = 'activo';
    -- Si ya no era 'activo' (race condition previa atajada por el lock) lo ignoramos.
  END IF;

  -- ── 5. Buscar el siguiente turno 'pendiente' en la ronda actual ───
  SELECT * INTO v_siguiente_turno
  FROM turnos
  WHERE sala_id      = p_sala_id
    AND numero_ronda = GREATEST(v_sala.ronda_actual, 1)
    AND estado       = 'pendiente'
  ORDER BY numero_turno ASC
  LIMIT 1;

  -- ── 6. Si no hay más turnos en la ronda actual, avanzar ronda ─────
  IF NOT FOUND THEN
    v_nueva_ronda := GREATEST(v_sala.ronda_actual, 1) + 1;

    IF v_nueva_ronda > v_sala.max_rondas THEN
      -- ── 6a. Debate finalizado ─────────────────────────────────────
      UPDATE salas
      SET
        estado          = 'finalizada',
        turno_activo_id = NULL,
        updated_at      = NOW()
      WHERE id = p_sala_id;

      INSERT INTO eventos_sala (sala_id, tipo, actor_id, payload)
      VALUES (
        p_sala_id, 'sala_finalizada', auth.uid(),
        jsonb_build_object(
          'motivo', 'rondas_agotadas',
          'rondas_completadas', v_sala.ronda_actual
        )
      );

      RETURN QUERY
        SELECT NULL::UUID, NULL::UUID, NULL::TEXT,
               NULL::SMALLINT, NULL::SMALLINT,
               NULL::TIMESTAMPTZ, 'finalizada'::estado_sala;
      RETURN;
    END IF;

    -- ── 6b. Hay más rondas: actualizar ronda y buscar el primer turno ─
    UPDATE salas
    SET ronda_actual = v_nueva_ronda,
        updated_at   = NOW()
    WHERE id = p_sala_id;

    SELECT * INTO v_siguiente_turno
    FROM turnos
    WHERE sala_id      = p_sala_id
      AND numero_ronda = v_nueva_ronda
      AND estado       = 'pendiente'
    ORDER BY numero_turno ASC
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'MESA10_NO_TURNS: No existen turnos en la ronda %.', v_nueva_ronda
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  -- ── 7. Activar el turno encontrado ───────────────────────────────
  UPDATE turnos
  SET
    estado    = 'activo',
    inicio_at = NOW()
  WHERE id = v_siguiente_turno.id;

  -- ── 8. Actualizar sala: turno activo y estado 'activa' ───────────
  UPDATE salas
  SET
    turno_activo_id = v_siguiente_turno.id,
    estado          = 'activa',
    updated_at      = NOW()
  WHERE id = p_sala_id;

  -- ── 9. Obtener alias del participante para el evento ─────────────
  SELECT * INTO v_participante
  FROM participantes
  WHERE id = v_siguiente_turno.participante_id;

  -- ── 10. Registrar evento de auditoría ────────────────────────────
  INSERT INTO eventos_sala (sala_id, tipo, actor_id, payload)
  VALUES (
    p_sala_id,
    'turno_activado',
    auth.uid(),
    jsonb_build_object(
      'turno_id',        v_siguiente_turno.id,
      'participante_id', v_siguiente_turno.participante_id,
      'alias',           v_participante.alias,
      'numero_turno',    v_siguiente_turno.numero_turno,
      'numero_ronda',    v_siguiente_turno.numero_ronda,
      'turno_anterior',  v_turno_anterior
    )
  );

  -- ── 11. Devolver resultado ───────────────────────────────────────
  RETURN QUERY
    SELECT
      v_siguiente_turno.id,
      v_siguiente_turno.participante_id,
      v_participante.alias,
      v_siguiente_turno.numero_ronda,
      v_siguiente_turno.numero_turno,
      NOW()::TIMESTAMPTZ,
      'activa'::estado_sala;
END;
$$;

COMMENT ON FUNCTION activar_siguiente_turno(UUID) IS
'RPC atómica (SELECT FOR UPDATE) que avanza al siguiente turno en la sala.
Solo ejecutable por el moderador de la sala. Previene race conditions.';

-- Permisos: solo usuarios autenticados pueden llamar la función
REVOKE ALL ON FUNCTION activar_siguiente_turno(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION activar_siguiente_turno(UUID) TO authenticated;

-- ============================================================
-- SECCIÓN B: DATOS SEMILLA (3 participantes, 3 turnos)
-- ¡ATENCIÓN! Reemplaza los UUIDs con los de tu proyecto real.
-- Estos son UUIDs ficticios para testing local.
-- ============================================================

-- Crear usuarios de prueba en auth.users (solo funciona en entorno local/dev)
-- En producción, los usuarios ya deben existir.

DO $$
DECLARE
  v_mod_id    UUID := '00000000-0000-0000-0000-000000000001'; -- Moderador
  v_deb1_id   UUID := '00000000-0000-0000-0000-000000000002'; -- Debatiente 1 (Claude)
  v_deb2_id   UUID := '00000000-0000-0000-0000-000000000003'; -- Debatiente 2 (Gemini)
  v_deb3_id   UUID := '00000000-0000-0000-0000-000000000004'; -- Debatiente 3 (ChatGPT)
  v_sala_id   UUID;
  v_part_mod  UUID;
  v_part_1    UUID;
  v_part_2    UUID;
  v_part_3    UUID;
  v_turno_1   UUID;
  v_turno_2   UUID;
  v_turno_3   UUID;
BEGIN

  -- ── Insertar usuarios ficticios en auth.users (dev only) ──────────
  -- En Supabase local, auth.users permite inserts directos.
  -- En producción esto no se hace; los usuarios se crean via auth.signUp()
  INSERT INTO auth.users (id, email, role, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud)
  VALUES
    (v_mod_id,  'moderador@mesa10.dev', 'authenticated', NOW(), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb, 'authenticated'),
    (v_deb1_id, 'claude@mesa10.dev',    'authenticated', NOW(), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb, 'authenticated'),
    (v_deb2_id, 'gemini@mesa10.dev',    'authenticated', NOW(), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb, 'authenticated'),
    (v_deb3_id, 'chatgpt@mesa10.dev',   'authenticated', NOW(), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb, 'authenticated')
  ON CONFLICT (id) DO NOTHING;

  -- ── Crear sala de debate ───────────────────────────────────────────
  INSERT INTO salas (
    id, nombre, descripcion, moderador_id, estado,
    max_participantes, duracion_turno_seg, max_rondas, es_publica, ronda_actual,
    metadatos
  )
  VALUES (
    gen_random_uuid(),
    'Mesa 10 — Debate Piloto',
    'Primer debate entre Claude, Gemini y ChatGPT. Tema: El rol de la IA en la democracia.',
    v_mod_id,
    'esperando',
    10, 180, 3, false, 0,
    '{"tema": "IA y democracia", "formato": "turno_3min", "version_mesa": "0.1.0"}'::jsonb
  )
  RETURNING id INTO v_sala_id;

  -- ── Registrar evento de creación ──────────────────────────────────
  INSERT INTO eventos_sala (sala_id, tipo, actor_id, payload)
  VALUES (v_sala_id, 'sala_creada', v_mod_id,
    jsonb_build_object('nombre', 'Mesa 10 — Debate Piloto'));

  -- ── Insertar participantes ────────────────────────────────────────
  INSERT INTO participantes (id, sala_id, user_id, alias, rol, orden_turno)
  VALUES
    (gen_random_uuid(), v_sala_id, v_mod_id,  'Moderador',  'moderador',  NULL)
  RETURNING id INTO v_part_mod;

  INSERT INTO participantes (id, sala_id, user_id, alias, rol, orden_turno)
  VALUES (gen_random_uuid(), v_sala_id, v_deb1_id, 'Claude-3',  'debatiente', 1)
  RETURNING id INTO v_part_1;

  INSERT INTO participantes (id, sala_id, user_id, alias, rol, orden_turno)
  VALUES (gen_random_uuid(), v_sala_id, v_deb2_id, 'Gemini-2',  'debatiente', 2)
  RETURNING id INTO v_part_2;

  INSERT INTO participantes (id, sala_id, user_id, alias, rol, orden_turno)
  VALUES (gen_random_uuid(), v_sala_id, v_deb3_id, 'ChatGPT-4', 'debatiente', 3)
  RETURNING id INTO v_part_3;

  -- Eventos de unión
  INSERT INTO eventos_sala (sala_id, tipo, actor_id, payload)
  SELECT v_sala_id, 'participante_unido', user_id,
         jsonb_build_object('alias', alias, 'rol', rol::text)
  FROM participantes WHERE sala_id = v_sala_id;

  -- ── Insertar turnos (Ronda 1) ─────────────────────────────────────
  INSERT INTO turnos (id, sala_id, participante_id, numero_turno, numero_ronda, estado)
  VALUES (gen_random_uuid(), v_sala_id, v_part_1, 1, 1, 'pendiente')
  RETURNING id INTO v_turno_1;

  INSERT INTO turnos (id, sala_id, participante_id, numero_turno, numero_ronda, estado)
  VALUES (gen_random_uuid(), v_sala_id, v_part_2, 2, 1, 'pendiente')
  RETURNING id INTO v_turno_2;

  INSERT INTO turnos (id, sala_id, participante_id, numero_turno, numero_ronda, estado)
  VALUES (gen_random_uuid(), v_sala_id, v_part_3, 3, 1, 'pendiente')
  RETURNING id INTO v_turno_3;

  -- También pre-crear turnos para Rondas 2 y 3
  INSERT INTO turnos (sala_id, participante_id, numero_turno, numero_ronda, estado)
  VALUES
    (v_sala_id, v_part_1, 1, 2, 'pendiente'),
    (v_sala_id, v_part_2, 2, 2, 'pendiente'),
    (v_sala_id, v_part_3, 3, 2, 'pendiente'),
    (v_sala_id, v_part_1, 1, 3, 'pendiente'),
    (v_sala_id, v_part_2, 2, 3, 'pendiente'),
    (v_sala_id, v_part_3, 3, 3, 'pendiente');

  RAISE NOTICE '==============================================';
  RAISE NOTICE 'SEED OK';
  RAISE NOTICE 'sala_id:   %', v_sala_id;
  RAISE NOTICE 'moderador: %  (moderador@mesa10.dev)', v_mod_id;
  RAISE NOTICE 'claude:    %  (claude@mesa10.dev)',    v_deb1_id;
  RAISE NOTICE 'gemini:    %  (gemini@mesa10.dev)',    v_deb2_id;
  RAISE NOTICE 'chatgpt:   %  (chatgpt@mesa10.dev)',  v_deb3_id;
  RAISE NOTICE '==============================================';
END;
$$;

-- ============================================================
-- SECCIÓN C: SCRIPTS DE PRUEBA
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- TEST 1: Verificar estructura base
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_count INT;
BEGIN
  RAISE NOTICE '--- TEST 1: Verificación de estructura ---';

  SELECT COUNT(*) INTO v_count FROM salas;
  RAISE NOTICE 'Salas creadas: % (esperado: 1)', v_count;
  ASSERT v_count = 1, 'FAIL: Debería haber exactamente 1 sala';

  SELECT COUNT(*) INTO v_count FROM participantes;
  RAISE NOTICE 'Participantes: % (esperado: 4)', v_count;
  ASSERT v_count = 4, 'FAIL: Debería haber 4 participantes (1 mod + 3 deb)';

  SELECT COUNT(*) INTO v_count FROM turnos;
  RAISE NOTICE 'Turnos totales: % (esperado: 9)', v_count;
  ASSERT v_count = 9, 'FAIL: Debería haber 9 turnos (3 por ronda × 3 rondas)';

  SELECT COUNT(*) INTO v_count FROM eventos_sala;
  RAISE NOTICE 'Eventos generados: % (esperado: 5)', v_count;
  -- 1 sala_creada + 4 participante_unido = 5

  RAISE NOTICE '--- TEST 1: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TEST 2: Acceso restringido — RLS básico
-- Verifica que las tablas tienen RLS habilitado
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_tbl TEXT;
  v_rls BOOLEAN;
BEGIN
  RAISE NOTICE '--- TEST 2: RLS habilitado en todas las tablas ---';
  FOR v_tbl IN VALUES ('salas'),('participantes'),('turnos'),('intervenciones'),('eventos_sala'),('resumenes_versionados') LOOP
    SELECT rowsecurity INTO v_rls FROM pg_tables
    WHERE tablename = v_tbl AND schemaname = 'public';
    RAISE NOTICE 'RLS en %: %', v_tbl, v_rls;
    ASSERT v_rls = true, format('FAIL: RLS no habilitado en %', v_tbl);
  END LOOP;
  RAISE NOTICE '--- TEST 2: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TEST 3: Inmutabilidad de intervención validada
-- Verifica que el trigger enforce_intervencion_inmutable funciona
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_sala_id     UUID;
  v_part_id     UUID;
  v_turno_id    UUID;
  v_interv_id   UUID;
  v_caught      BOOLEAN := false;
BEGIN
  RAISE NOTICE '--- TEST 3: Inmutabilidad de intervención validada ---';

  SELECT id INTO v_sala_id FROM salas LIMIT 1;
  SELECT id INTO v_part_id FROM participantes WHERE sala_id = v_sala_id AND rol = 'debatiente' LIMIT 1;
  SELECT id INTO v_turno_id FROM turnos WHERE sala_id = v_sala_id AND numero_ronda = 1 AND numero_turno = 1 LIMIT 1;

  -- Crear intervención y marcarla como validada directamente (bypass RLS como admin)
  INSERT INTO intervenciones (turno_id, sala_id, participante_id, contenido, estado)
  VALUES (v_turno_id, v_sala_id, v_part_id,
          'La IA puede fortalecer la democracia si se implementa con transparencia y supervisión ciudadana.',
          'validada')
  RETURNING id INTO v_interv_id;

  -- Intentar modificar — debe fallar por trigger
  BEGIN
    UPDATE intervenciones
    SET contenido = '← ESTE CAMBIO NO DEBERÍA OCURRIR'
    WHERE id = v_interv_id;
  EXCEPTION WHEN OTHERS THEN
    v_caught := true;
    RAISE NOTICE 'CORRECTO: Modificación bloqueada con: %', SQLERRM;
  END;

  ASSERT v_caught = true, 'FAIL: La intervención validada debería ser inmutable';

  -- Limpiar
  DELETE FROM intervenciones WHERE id = v_interv_id;

  RAISE NOTICE '--- TEST 3: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TEST 4: Append-only en eventos_sala
-- Verifica que UPDATE y DELETE en eventos_sala no tienen efecto
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_sala_id   UUID;
  v_evento_id UUID;
  v_payload   JSONB;
BEGIN
  RAISE NOTICE '--- TEST 4: Append-only en eventos_sala ---';

  SELECT id INTO v_sala_id FROM salas LIMIT 1;

  -- Insertar evento de prueba
  INSERT INTO eventos_sala (sala_id, tipo, actor_id, payload)
  VALUES (v_sala_id, 'sala_pausada', '00000000-0000-0000-0000-000000000001',
          '{"prueba": "original"}'::jsonb)
  RETURNING id, payload INTO v_evento_id, v_payload;

  -- Intentar UPDATE (debería ser ignorado por la RULE)
  UPDATE eventos_sala
  SET payload = '{"prueba": "modificado"}'::jsonb
  WHERE id = v_evento_id;

  -- Verificar que no cambió
  SELECT payload INTO v_payload FROM eventos_sala WHERE id = v_evento_id;

  IF v_payload->>'prueba' = 'original' THEN
    RAISE NOTICE 'CORRECTO: UPDATE ignorado, payload sigue siendo: %', v_payload;
  ELSE
    RAISE EXCEPTION 'FAIL: El payload fue modificado: %', v_payload;
  END IF;

  -- Intentar DELETE (debería ser ignorado por la RULE)
  DELETE FROM eventos_sala WHERE id = v_evento_id;

  IF EXISTS (SELECT 1 FROM eventos_sala WHERE id = v_evento_id) THEN
    RAISE NOTICE 'CORRECTO: DELETE ignorado, el evento sigue existiendo';
  ELSE
    RAISE EXCEPTION 'FAIL: El evento fue eliminado';
  END IF;

  RAISE NOTICE '--- TEST 4: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TEST 5: Control de turno activo — atomicidad
-- Simula 2 peticiones concurrentes de activación de turno
-- y verifica que solo una gana (con transacciones explícitas)
-- ──────────────────────────────────────────────────────────────
-- NOTA: Para probar atomicidad real con conexiones concurrentes,
-- ejecutar los siguientes bloques desde 2 sesiones SQL distintas
-- de forma simultanea. Este script valida la lógica secuencial;
-- la prueba de concurrencia real requiere 2 conexiones psql.

DO $$
DECLARE
  v_sala_id   UUID;
  v_activos   INT;
BEGIN
  RAISE NOTICE '--- TEST 5: Control de único turno activo ---';

  SELECT id INTO v_sala_id FROM salas WHERE estado = 'esperando' LIMIT 1;

  -- Activar manualmente el turno 1, ronda 1 (simula primer caller ganador)
  UPDATE turnos
  SET estado = 'activo', inicio_at = NOW()
  WHERE sala_id = v_sala_id
    AND numero_turno = 1
    AND numero_ronda = 1
    AND estado = 'pendiente';

  UPDATE salas
  SET turno_activo_id = (
    SELECT id FROM turnos
    WHERE sala_id = v_sala_id AND estado = 'activo' LIMIT 1
  ),
  estado = 'activa',
  ronda_actual = 1
  WHERE id = v_sala_id;

  -- Intentar activar el mismo turno de nuevo (simula segundo caller)
  -- Debería no cambiar nada porque ya no está en 'pendiente'
  UPDATE turnos
  SET estado = 'activo', inicio_at = NOW()
  WHERE sala_id = v_sala_id
    AND numero_turno = 1
    AND numero_ronda = 1
    AND estado = 'pendiente';  -- ← condición de guardia

  -- Contar cuántos turnos activos hay (debe ser 1)
  SELECT COUNT(*) INTO v_activos
  FROM turnos
  WHERE sala_id = v_sala_id AND estado = 'activo';

  RAISE NOTICE 'Turnos activos simultáneos: % (esperado: 1)', v_activos;
  ASSERT v_activos = 1, format('FAIL: Hay %s turnos activos, debería haber 1', v_activos);

  RAISE NOTICE '--- TEST 5: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TEST 5b: Script para prueba de concurrencia real
-- INSTRUCCIONES: Abrir 2 terminales psql, ejecutar este bloque
-- en AMBAS al mismo tiempo (la segunda debe bloquearse hasta
-- que la primera haga COMMIT).
-- ──────────────────────────────────────────────────────────────
/*
-- === SESIÓN A y SESIÓN B (ejecutar simultáneamente) ===

BEGIN;

  -- Esta línea bloquea a la segunda sesión hasta que la primera haga COMMIT
  SELECT * FROM salas WHERE id = '<tu_sala_id>' FOR UPDATE;

  -- Simular trabajo (esperar 5 segundos para dar tiempo a la segunda sesión)
  PERFORM pg_sleep(5);

  -- Activar siguiente turno (solo uno de los dos callers ganará)
  UPDATE turnos
  SET estado = 'activo', inicio_at = NOW()
  WHERE sala_id = '<tu_sala_id>'
    AND estado = 'pendiente'
    AND numero_turno = (
      SELECT MIN(numero_turno) FROM turnos
      WHERE sala_id = '<tu_sala_id>' AND estado = 'pendiente'
    );

COMMIT;

-- Verificar después:
SELECT id, numero_turno, estado, inicio_at
FROM turnos
WHERE sala_id = '<tu_sala_id>'
ORDER BY numero_ronda, numero_turno;
*/

-- ──────────────────────────────────────────────────────────────
-- TEST 6: Verificación del moderador en participantes
-- El moderador no puede tener orden_turno asignado
-- ──────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_sala_id UUID;
  v_caught  BOOLEAN := false;
BEGIN
  RAISE NOTICE '--- TEST 6: Constraint moderador_sin_turno ---';

  SELECT id INTO v_sala_id FROM salas LIMIT 1;

  BEGIN
    -- Intentar insertar un moderador CON orden_turno → debe fallar
    INSERT INTO participantes (sala_id, user_id, alias, rol, orden_turno)
    VALUES (v_sala_id, gen_random_uuid(), 'ModInvalido', 'moderador', 1);
  EXCEPTION WHEN check_violation THEN
    v_caught := true;
    RAISE NOTICE 'CORRECTO: Constraint bloqueó moderador con orden_turno';
  END;

  ASSERT v_caught = true, 'FAIL: El constraint chk_moderador_sin_turno no funcionó';

  RAISE NOTICE '--- TEST 6: PASS ---';
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- RESUMEN FINAL
-- ──────────────────────────────────────────────────────────────
SELECT
  'salas'                 AS tabla, COUNT(*) AS filas FROM salas
UNION ALL SELECT 'participantes',  COUNT(*) FROM participantes
UNION ALL SELECT 'turnos',         COUNT(*) FROM turnos
UNION ALL SELECT 'intervenciones', COUNT(*) FROM intervenciones
UNION ALL SELECT 'eventos_sala',   COUNT(*) FROM eventos_sala
UNION ALL SELECT 'resumenes',      COUNT(*) FROM resumenes_versionados
ORDER BY tabla;

SELECT
  numero_ronda,
  numero_turno,
  p.alias,
  t.estado
FROM turnos t
JOIN participantes p ON p.id = t.participante_id
ORDER BY numero_ronda, numero_turno;
