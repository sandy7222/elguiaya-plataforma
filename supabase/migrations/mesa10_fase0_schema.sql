-- ============================================================
-- MIGRACIÓN: Mesa 10 — Fase 0 — Schema Base
-- Sistema de debate moderado multi-IA
-- Proyecto: CapitanYA / Mesa 10
-- EJECUTAR en Supabase SQL Editor (orden importa)
-- ============================================================

-- ============================================================
-- PASO 0: Extensiones requeridas
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- PASO 1: ENUMs de dominio
-- ============================================================

-- Estado general de una sala de debate
DO $$ BEGIN
  CREATE TYPE estado_sala AS ENUM (
    'esperando',    -- sala creada, esperando participantes
    'activa',       -- debate en curso
    'pausada',      -- moderador pausó el debate
    'finalizada'    -- debate concluido
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Estado de un turno individual
DO $$ BEGIN
  CREATE TYPE estado_turno AS ENUM (
    'pendiente',    -- todavía no es su momento
    'activo',       -- es el turno de este participante AHORA
    'completado',   -- participante publicó su intervención
    'saltado'       -- moderador saltó este turno
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Estado del ciclo de vida de una intervención
DO $$ BEGIN
  CREATE TYPE estado_intervencion AS ENUM (
    'borrador',     -- participante aún redactando (no visible al resto)
    'publicada',    -- enviada, visible a todos, mutable hasta validación
    'validada',     -- sellada por moderador — INMUTABLE
    'silenciada'    -- ocultada por moderador (visible solo a moderador)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Rol dentro de una sala
DO $$ BEGIN
  CREATE TYPE rol_participante AS ENUM (
    'moderador',    -- controla flujo, valida, silencia
    'debatiente',   -- interviene en turnos
    'observador'    -- solo lectura, no interviene
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Tipo de evento para el log de auditoría
DO $$ BEGIN
  CREATE TYPE tipo_evento_sala AS ENUM (
    'sala_creada',
    'participante_unido',
    'participante_expulsado',
    'turno_activado',
    'turno_completado',
    'turno_saltado',
    'intervencion_publicada',
    'intervencion_validada',
    'intervencion_silenciada',
    'sala_pausada',
    'sala_finalizada',
    'resumen_generado'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PASO 2: TABLA salas
-- Unidad principal de debate. Una sala = un debate.
-- ============================================================
CREATE TABLE IF NOT EXISTS salas (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre              TEXT        NOT NULL CHECK (char_length(nombre) BETWEEN 3 AND 120),
  descripcion         TEXT        CHECK (char_length(descripcion) <= 500),
  moderador_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  estado              estado_sala NOT NULL DEFAULT 'esperando',
  turno_activo_id     UUID,                         -- FK diferida → tabla turnos
  max_participantes   SMALLINT    NOT NULL DEFAULT 10 CHECK (max_participantes BETWEEN 2 AND 100),
  duracion_turno_seg  SMALLINT    NOT NULL DEFAULT 120 CHECK (duracion_turno_seg BETWEEN 10 AND 3600),
  ronda_actual        SMALLINT    NOT NULL DEFAULT 0,
  max_rondas          SMALLINT    NOT NULL DEFAULT 3 CHECK (max_rondas BETWEEN 1 AND 20),
  es_publica          BOOLEAN     NOT NULL DEFAULT false,
  metadatos           JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  salas IS 'Sala de debate de Mesa 10. Una sala = un debate activo o archivado.';
COMMENT ON COLUMN salas.turno_activo_id IS 'FK al turno que está ACTIVO ahora. NULL si no hay turno en curso.';
COMMENT ON COLUMN salas.metadatos IS 'JSONB libre para configuración extra (ej: tema, tags, config de IA).';

-- ============================================================
-- PASO 3: TABLA participantes
-- Relación muchos-a-muchos entre auth.users y salas.
-- ============================================================
CREATE TABLE IF NOT EXISTS participantes (
  id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  sala_id         UUID              NOT NULL REFERENCES salas(id) ON DELETE CASCADE,
  user_id         UUID              NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alias           TEXT              NOT NULL CHECK (char_length(alias) BETWEEN 1 AND 60),
  rol             rol_participante  NOT NULL DEFAULT 'debatiente',
  orden_turno     SMALLINT,         -- posición en la secuencia de turnos (NULL = observador)
  activo          BOOLEAN           NOT NULL DEFAULT true,
  silenciado      BOOLEAN           NOT NULL DEFAULT false,
  joined_at       TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_participante_sala  UNIQUE (sala_id, user_id),
  CONSTRAINT uq_alias_sala         UNIQUE (sala_id, alias),
  CONSTRAINT chk_moderador_sin_turno CHECK (
    NOT (rol = 'moderador' AND orden_turno IS NOT NULL)
  )
);

COMMENT ON TABLE  participantes IS 'Membresía de un usuario en una sala. Incluye su rol y posición en el debate.';
COMMENT ON COLUMN participantes.orden_turno IS 'Orden 1-based para la secuencia de turnos. NULL para observadores/moderador.';

-- ============================================================
-- PASO 4: TABLA turnos
-- Representa un slot temporal asignado a un participante debatiente.
-- ============================================================
CREATE TABLE IF NOT EXISTS turnos (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  sala_id           UUID          NOT NULL REFERENCES salas(id) ON DELETE CASCADE,
  participante_id   UUID          NOT NULL REFERENCES participantes(id) ON DELETE CASCADE,
  numero_turno      SMALLINT      NOT NULL CHECK (numero_turno >= 1),
  numero_ronda      SMALLINT      NOT NULL CHECK (numero_ronda >= 1),
  estado            estado_turno  NOT NULL DEFAULT 'pendiente',
  inicio_at         TIMESTAMPTZ,
  fin_at            TIMESTAMPTZ,
  duracion_real_seg INTEGER GENERATED ALWAYS AS (
    CASE WHEN inicio_at IS NOT NULL AND fin_at IS NOT NULL
         THEN EXTRACT(EPOCH FROM (fin_at - inicio_at))::INTEGER
         ELSE NULL
    END
  ) STORED,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_turno_sala UNIQUE (sala_id, numero_ronda, numero_turno)
);

COMMENT ON TABLE  turnos IS 'Slot temporal de debate asignado a un participante en una ronda.';
COMMENT ON COLUMN turnos.duracion_real_seg IS 'Duración efectiva calculada automáticamente (columna generada).';

-- FK diferida: salas.turno_activo_id → turnos.id
-- Se hace post-creación para evitar dependencia circular entre salas y turnos
ALTER TABLE salas
  DROP CONSTRAINT IF EXISTS fk_sala_turno_activo;

ALTER TABLE salas
  ADD CONSTRAINT fk_sala_turno_activo
  FOREIGN KEY (turno_activo_id) REFERENCES turnos(id)
  ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED;

-- ============================================================
-- PASO 5: TABLA intervenciones
-- El contenido real de cada participación en un turno.
-- ============================================================
CREATE TABLE IF NOT EXISTS intervenciones (
  id                  UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  turno_id            UUID                  NOT NULL REFERENCES turnos(id) ON DELETE CASCADE,
  sala_id             UUID                  NOT NULL REFERENCES salas(id) ON DELETE CASCADE,
  participante_id     UUID                  NOT NULL REFERENCES participantes(id) ON DELETE CASCADE,
  contenido           TEXT                  NOT NULL CHECK (char_length(contenido) BETWEEN 1 AND 10000),
  estado              estado_intervencion   NOT NULL DEFAULT 'borrador',
  version             SMALLINT              NOT NULL DEFAULT 1 CHECK (version >= 1),
  tokens_estimados    INTEGER               CHECK (tokens_estimados >= 0),
  validada_por        UUID                  REFERENCES auth.users(id) ON DELETE SET NULL,
  validada_at         TIMESTAMPTZ,
  silenciada_por      UUID                  REFERENCES auth.users(id) ON DELETE SET NULL,
  silenciada_at       TIMESTAMPTZ,
  metadatos           JSONB                 NOT NULL DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  intervenciones IS 'Contenido de la participación de un debatiente en su turno.';
COMMENT ON COLUMN intervenciones.estado IS 'borrador→publicada→validada (inmutable). silenciada es estado terminal paralelo.';
COMMENT ON COLUMN intervenciones.version IS 'Contador de ediciones antes de publicar. Congelado al validar.';

-- ============================================================
-- PASO 6: TABLA eventos_sala
-- Log de auditoría inmutable de todo lo que ocurre en la sala.
-- ============================================================
CREATE TABLE IF NOT EXISTS eventos_sala (
  id              UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  sala_id         UUID                NOT NULL REFERENCES salas(id) ON DELETE CASCADE,
  tipo            tipo_evento_sala    NOT NULL,
  actor_id        UUID                REFERENCES auth.users(id) ON DELETE SET NULL,
  payload         JSONB               NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW()
  -- SIN updated_at: esta tabla es inmutable por diseño
);

COMMENT ON TABLE eventos_sala IS 'Log de auditoría append-only de todos los eventos de una sala.';

-- Prevenir UPDATE y DELETE en eventos_sala (append-only enforcement vía rules)
CREATE OR REPLACE RULE eventos_sala_no_update AS
  ON UPDATE TO eventos_sala DO INSTEAD NOTHING;

CREATE OR REPLACE RULE eventos_sala_no_delete AS
  ON DELETE TO eventos_sala DO INSTEAD NOTHING;

-- ============================================================
-- PASO 7: TABLA resumenes_versionados
-- Snapshots de resumen del debate.
-- ============================================================
CREATE TABLE IF NOT EXISTS resumenes_versionados (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sala_id         UUID        NOT NULL REFERENCES salas(id) ON DELETE CASCADE,
  version         SMALLINT    NOT NULL CHECK (version >= 1),
  generado_por    UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  contenido       TEXT        NOT NULL CHECK (char_length(contenido) BETWEEN 1 AND 50000),
  modelo_ia       TEXT        CHECK (char_length(modelo_ia) <= 100),
  tokens_usados   INTEGER     CHECK (tokens_usados >= 0),
  ronda_hasta     SMALLINT,
  metadatos       JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_resumen_sala_version UNIQUE (sala_id, version)
);

COMMENT ON TABLE resumenes_versionados IS 'Snapshots versionados del resumen del debate. Inmutables post-creación.';

CREATE OR REPLACE RULE resumenes_no_update AS
  ON UPDATE TO resumenes_versionados DO INSTEAD NOTHING;

-- ============================================================
-- PASO 8: FUNCIÓN trigger updated_at automático
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER tg_salas_updated_at
    BEFORE UPDATE ON salas
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tg_participantes_updated_at
    BEFORE UPDATE ON participantes
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tg_intervenciones_updated_at
    BEFORE UPDATE ON intervenciones
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PASO 9: TRIGGER — intervención validada es INMUTABLE
-- ============================================================
CREATE OR REPLACE FUNCTION enforce_intervencion_inmutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.estado = 'validada' THEN
    RAISE EXCEPTION
      'MESA10_IMMUTABLE: La intervención % ya fue validada y no puede modificarse.',
      OLD.id
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER tg_intervencion_inmutable
    BEFORE UPDATE ON intervenciones
    FOR EACH ROW EXECUTE FUNCTION enforce_intervencion_inmutable();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PASO 10: ÍNDICES de performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_salas_estado        ON salas(estado);
CREATE INDEX IF NOT EXISTS idx_salas_moderador      ON salas(moderador_id);
CREATE INDEX IF NOT EXISTS idx_salas_turno_activo   ON salas(turno_activo_id) WHERE turno_activo_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_participantes_sala    ON participantes(sala_id);
CREATE INDEX IF NOT EXISTS idx_participantes_user    ON participantes(user_id);
CREATE INDEX IF NOT EXISTS idx_participantes_activos ON participantes(sala_id, activo) WHERE activo = true;

CREATE INDEX IF NOT EXISTS idx_turnos_sala           ON turnos(sala_id, numero_ronda, numero_turno);
CREATE INDEX IF NOT EXISTS idx_turnos_participante   ON turnos(participante_id);
CREATE INDEX IF NOT EXISTS idx_turnos_activo         ON turnos(sala_id, estado) WHERE estado = 'activo';

CREATE INDEX IF NOT EXISTS idx_intervenciones_turno        ON intervenciones(turno_id);
CREATE INDEX IF NOT EXISTS idx_intervenciones_sala         ON intervenciones(sala_id);
CREATE INDEX IF NOT EXISTS idx_intervenciones_participante ON intervenciones(participante_id);
CREATE INDEX IF NOT EXISTS idx_intervenciones_estado       ON intervenciones(sala_id, estado);

CREATE INDEX IF NOT EXISTS idx_eventos_sala_crono   ON eventos_sala(sala_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_tipo         ON eventos_sala(sala_id, tipo);
CREATE INDEX IF NOT EXISTS idx_eventos_actor        ON eventos_sala(actor_id) WHERE actor_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_resumenes_sala       ON resumenes_versionados(sala_id, version DESC);

-- ============================================================
-- PASO 11: Verificación del schema
-- ============================================================
SELECT
  t.tablename,
  (SELECT COUNT(*) FROM information_schema.columns c
   WHERE c.table_name = t.tablename AND c.table_schema = 'public') AS columnas
FROM pg_tables t
WHERE t.schemaname = 'public'
  AND t.tablename IN ('salas','participantes','turnos','intervenciones','eventos_sala','resumenes_versionados')
ORDER BY t.tablename;

SELECT typname, enumlabel
FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname IN ('estado_sala','estado_turno','estado_intervencion','rol_participante','tipo_evento_sala')
ORDER BY typname, e.enumsortorder;
