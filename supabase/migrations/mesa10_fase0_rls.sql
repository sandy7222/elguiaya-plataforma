-- ============================================================
-- MIGRACIÓN: Mesa 10 — Fase 0 — RLS (Row Level Security)
-- Sistema de debate moderado multi-IA
-- EJECUTAR DESPUÉS de mesa10_fase0_schema.sql
-- ============================================================

-- ============================================================
-- PASO 1: Habilitar RLS en todas las tablas
-- ============================================================
ALTER TABLE salas                ENABLE ROW LEVEL SECURITY;
ALTER TABLE participantes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE turnos               ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervenciones       ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos_sala         ENABLE ROW LEVEL SECURITY;
ALTER TABLE resumenes_versionados ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PASO 2: Limpiar políticas anteriores (idempotente)
-- ============================================================
DO $$
DECLARE
  tbl TEXT;
  pol TEXT;
BEGIN
  FOR tbl IN VALUES ('salas'),('participantes'),('turnos'),('intervenciones'),('eventos_sala'),('resumenes_versionados') LOOP
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = tbl LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol, tbl);
    END LOOP;
  END LOOP;
END;
$$;

-- ============================================================
-- FUNCIÓN HELPER: ¿Es el usuario moderador de esta sala?
-- Usada como referencia interna en las políticas.
-- ============================================================
CREATE OR REPLACE FUNCTION es_moderador_de_sala(p_sala_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM salas
    WHERE id = p_sala_id
      AND moderador_id = auth.uid()
  );
$$;

-- ============================================================
-- FUNCIÓN HELPER: ¿Es el usuario participante activo de esta sala?
-- ============================================================
CREATE OR REPLACE FUNCTION es_participante_de_sala(p_sala_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM participantes
    WHERE sala_id = p_sala_id
      AND user_id = auth.uid()
      AND activo = true
  );
$$;

-- ============================================================
-- FUNCIÓN HELPER: ¿Tiene el usuario el turno activo en esta sala?
-- ============================================================
CREATE OR REPLACE FUNCTION tiene_turno_activo(p_sala_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1
    FROM salas s
    JOIN turnos t ON t.id = s.turno_activo_id
    JOIN participantes p ON p.id = t.participante_id
    WHERE s.id = p_sala_id
      AND p.user_id = auth.uid()
      AND t.estado = 'activo'
  );
$$;

-- ============================================================
-- POLÍTICAS: salas
-- ============================================================

-- SELECT: cualquier auth si la sala es pública O si es participante/moderador
CREATE POLICY "salas_select"
ON salas FOR SELECT TO authenticated
USING (
  es_publica = true
  OR moderador_id = auth.uid()
  OR es_participante_de_sala(id)
);

-- INSERT: cualquier usuario autenticado puede crear una sala (él será moderador)
CREATE POLICY "salas_insert"
ON salas FOR INSERT TO authenticated
WITH CHECK (moderador_id = auth.uid());

-- UPDATE: solo el moderador puede modificar la sala
CREATE POLICY "salas_update"
ON salas FOR UPDATE TO authenticated
USING    (moderador_id = auth.uid())
WITH CHECK (moderador_id = auth.uid());

-- DELETE: solo el moderador puede eliminar (solo si está en estado 'esperando')
CREATE POLICY "salas_delete"
ON salas FOR DELETE TO authenticated
USING (
  moderador_id = auth.uid()
  AND estado = 'esperando'
);

-- ============================================================
-- POLÍTICAS: participantes
-- ============================================================

-- SELECT: solo participantes de la misma sala pueden verse entre sí
CREATE POLICY "participantes_select"
ON participantes FOR SELECT TO authenticated
USING (es_participante_de_sala(sala_id) OR es_moderador_de_sala(sala_id));

-- INSERT: el moderador agrega participantes, o el propio usuario se une (si sala es pública)
CREATE POLICY "participantes_insert"
ON participantes FOR INSERT TO authenticated
WITH CHECK (
  es_moderador_de_sala(sala_id)
  OR (
    user_id = auth.uid()
    AND EXISTS (SELECT 1 FROM salas WHERE id = sala_id AND es_publica = true AND estado = 'esperando')
  )
);

-- UPDATE: el moderador puede cambiar roles; el propio usuario puede cambiar su alias
CREATE POLICY "participantes_update"
ON participantes FOR UPDATE TO authenticated
USING (
  es_moderador_de_sala(sala_id)
  OR user_id = auth.uid()
)
WITH CHECK (
  es_moderador_de_sala(sala_id)
  OR user_id = auth.uid()
);

-- DELETE: solo el moderador puede expulsar participantes
CREATE POLICY "participantes_delete"
ON participantes FOR DELETE TO authenticated
USING (es_moderador_de_sala(sala_id));

-- ============================================================
-- POLÍTICAS: turnos
-- ============================================================

-- SELECT: participantes de la sala ven los turnos de su sala
CREATE POLICY "turnos_select"
ON turnos FOR SELECT TO authenticated
USING (
  es_participante_de_sala(sala_id)
  OR es_moderador_de_sala(sala_id)
);

-- INSERT: solo el moderador crea turnos
CREATE POLICY "turnos_insert"
ON turnos FOR INSERT TO authenticated
WITH CHECK (es_moderador_de_sala(sala_id));

-- UPDATE: solo el moderador puede cambiar el estado del turno
-- (La función RPC activar_siguiente_turno opera con SECURITY DEFINER)
CREATE POLICY "turnos_update"
ON turnos FOR UPDATE TO authenticated
USING    (es_moderador_de_sala(sala_id))
WITH CHECK (es_moderador_de_sala(sala_id));

-- DELETE: prohibido (los turnos son registro histórico)
-- No se crea política DELETE → ningún usuario puede borrar turnos

-- ============================================================
-- POLÍTICAS: intervenciones
-- ============================================================

-- SELECT:
-- • El propio autor ve siempre sus borradores
-- • El moderador ve todo (incluyendo silenciadas)
-- • El resto de participantes ven solo 'publicada' y 'validada'
CREATE POLICY "intervenciones_select"
ON intervenciones FOR SELECT TO authenticated
USING (
  -- El autor ve sus propios borradores/silenciadas
  participante_id IN (
    SELECT id FROM participantes WHERE user_id = auth.uid()
  )
  -- El moderador lo ve todo
  OR es_moderador_de_sala(sala_id)
  -- Los demás participantes ven publicadas y validadas (no silenciadas ni borradores ajenos)
  OR (
    es_participante_de_sala(sala_id)
    AND estado IN ('publicada', 'validada')
  )
);

-- INSERT: solo el participante con turno activo puede crear una intervención
CREATE POLICY "intervenciones_insert"
ON intervenciones FOR INSERT TO authenticated
WITH CHECK (
  -- El usuario debe ser dueño del participante_id indicado
  participante_id IN (
    SELECT id FROM participantes WHERE user_id = auth.uid()
  )
  -- Y debe tener el turno activo en esa sala
  AND tiene_turno_activo(sala_id)
);

-- UPDATE:
-- • El autor puede editar su borrador
-- • El moderador puede validar o silenciar
-- • Una intervención 'validada' es inmutable (reforzado por trigger también)
CREATE POLICY "intervenciones_update"
ON intervenciones FOR UPDATE TO authenticated
USING (
  -- El autor edita su propio borrador (no puede editar publicadas ni validadas)
  (
    participante_id IN (SELECT id FROM participantes WHERE user_id = auth.uid())
    AND estado = 'borrador'
    AND tiene_turno_activo(sala_id)
  )
  -- El moderador puede cambiar estado (publicada→validada o publicada→silenciada)
  OR (
    es_moderador_de_sala(sala_id)
    AND estado != 'validada'   -- no puede re-editar una ya validada
  )
)
WITH CHECK (
  (
    participante_id IN (SELECT id FROM participantes WHERE user_id = auth.uid())
    AND estado = 'borrador'
  )
  OR es_moderador_de_sala(sala_id)
);

-- DELETE: prohibido (las intervenciones son registro histórico)

-- ============================================================
-- POLÍTICAS: eventos_sala
-- ============================================================

-- SELECT: solo participantes de la sala ven el log
CREATE POLICY "eventos_sala_select"
ON eventos_sala FOR SELECT TO authenticated
USING (
  es_participante_de_sala(sala_id)
  OR es_moderador_de_sala(sala_id)
);

-- INSERT: el moderador o el sistema (funciones SECURITY DEFINER) insertan eventos
-- En Supabase, las RPCs con SECURITY DEFINER eluden RLS.
-- Para el cliente directo, solo el moderador puede insertar.
CREATE POLICY "eventos_sala_insert"
ON eventos_sala FOR INSERT TO authenticated
WITH CHECK (
  es_moderador_de_sala(sala_id)
  OR actor_id = auth.uid()
);

-- UPDATE/DELETE: bloqueados por las RULES en el schema; no se crean políticas

-- ============================================================
-- POLÍTICAS: resumenes_versionados
-- ============================================================

-- SELECT: participantes y moderador de la sala
CREATE POLICY "resumenes_select"
ON resumenes_versionados FOR SELECT TO authenticated
USING (
  es_participante_de_sala(sala_id)
  OR es_moderador_de_sala(sala_id)
);

-- INSERT: solo el moderador genera resúmenes
CREATE POLICY "resumenes_insert"
ON resumenes_versionados FOR INSERT TO authenticated
WITH CHECK (es_moderador_de_sala(sala_id));

-- UPDATE: bloqueado por RULE en el schema; no se crea política

-- ============================================================
-- PASO 3: Verificación de políticas creadas
-- ============================================================
SELECT
  tablename,
  policyname,
  cmd,
  qual IS NOT NULL AS tiene_using,
  with_check IS NOT NULL AS tiene_with_check
FROM pg_policies
WHERE tablename IN ('salas','participantes','turnos','intervenciones','eventos_sala','resumenes_versionados')
ORDER BY tablename, cmd;
