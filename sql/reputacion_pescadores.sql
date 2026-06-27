-- ============================================================================
-- REPUTACIÓN DE PESCADORES (paridad con reputacion_capitanes)
-- Ejecutar en Supabase SQL Editor del proyecto CapitanYA-MASTER
-- ============================================================================

-- 1. Tabla de reputación del pescador
CREATE TABLE IF NOT EXISTS public.reputacion_pescadores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pescador_id UUID NOT NULL,
    calificacion_promedio DECIMAL(3,2) DEFAULT 0.00,
    total_viajes INTEGER DEFAULT 0,
    viajes_completados INTEGER DEFAULT 0,
    viajes_cancelados INTEGER DEFAULT 0,
    total_calificaciones INTEGER DEFAULT 0,
    calificaciones_5_estrellas INTEGER DEFAULT 0,
    calificaciones_4_estrellas INTEGER DEFAULT 0,
    calificaciones_3_estrellas INTEGER DEFAULT 0,
    calificaciones_2_estrellas INTEGER DEFAULT 0,
    calificaciones_1_estrella INTEGER DEFAULT 0,
    ultima_calificacion TIMESTAMPTZ,
    nivel_reputacion VARCHAR(20) DEFAULT 'novato',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_pescador_reputacion UNIQUE (pescador_id)
);

CREATE INDEX IF NOT EXISTS idx_reputacion_pescadores_pescador_id
    ON public.reputacion_pescadores (pescador_id);

ALTER TABLE public.reputacion_pescadores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reputacion_pescadores_lectura_autenticados" ON public.reputacion_pescadores;
CREATE POLICY "reputacion_pescadores_lectura_autenticados"
ON public.reputacion_pescadores FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "reputacion_pescadores_ver_propio" ON public.reputacion_pescadores;
CREATE POLICY "reputacion_pescadores_ver_propio"
ON public.reputacion_pescadores FOR SELECT
TO authenticated
USING (pescador_id::text = auth.uid()::text);

-- 2. RPC: recalcular promedio al calificar (llamada desde la app)
CREATE OR REPLACE FUNCTION public.actualizar_reputacion_pescador(
    p_pescador_id UUID,
    p_calificacion INTEGER
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    nueva_calificacion_promedio DECIMAL,
    nuevo_nivel VARCHAR
) AS $$
DECLARE
    reputacion_actual RECORD;
    nueva_calificacion DECIMAL(3,2);
    nuevo_nivel_reputacion VARCHAR(20);
    v_viajes_completados INTEGER;
BEGIN
    IF p_calificacion < 1 OR p_calificacion > 5 THEN
        RETURN QUERY SELECT FALSE, 'Calificación fuera de rango (1-5)'::TEXT, 0.00::DECIMAL, 'novato'::VARCHAR;
        RETURN;
    END IF;

    SELECT * INTO reputacion_actual
    FROM public.reputacion_pescadores
    WHERE pescador_id = p_pescador_id;

    SELECT COUNT(*)::INTEGER INTO v_viajes_completados
    FROM public.pedidos
    WHERE pescador_id::text = p_pescador_id::text
      AND estado IN ('cerrado', 'finalizado', 'listo_para_confirmar');

    IF reputacion_actual IS NULL THEN
        INSERT INTO public.reputacion_pescadores (
            pescador_id,
            calificacion_promedio,
            total_calificaciones,
            total_viajes,
            viajes_completados,
            calificaciones_5_estrellas,
            calificaciones_4_estrellas,
            calificaciones_3_estrellas,
            calificaciones_2_estrellas,
            calificaciones_1_estrella,
            ultima_calificacion,
            nivel_reputacion,
            created_at,
            updated_at
        ) VALUES (
            p_pescador_id,
            p_calificacion::DECIMAL,
            1,
            GREATEST(v_viajes_completados, 1),
            GREATEST(v_viajes_completados, 1),
            CASE WHEN p_calificacion = 5 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 4 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 3 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 2 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 1 THEN 1 ELSE 0 END,
            NOW(),
            'novato',
            NOW(),
            NOW()
        );

        nueva_calificacion := p_calificacion::DECIMAL;
        nuevo_nivel_reputacion := 'novato';
    ELSE
        UPDATE public.reputacion_pescadores SET
            total_calificaciones = total_calificaciones + 1,
            total_viajes = GREATEST(total_viajes, v_viajes_completados),
            viajes_completados = GREATEST(viajes_completados, v_viajes_completados),
            calificaciones_5_estrellas = calificaciones_5_estrellas + CASE WHEN p_calificacion = 5 THEN 1 ELSE 0 END,
            calificaciones_4_estrellas = calificaciones_4_estrellas + CASE WHEN p_calificacion = 4 THEN 1 ELSE 0 END,
            calificaciones_3_estrellas = calificaciones_3_estrellas + CASE WHEN p_calificacion = 3 THEN 1 ELSE 0 END,
            calificaciones_2_estrellas = calificaciones_2_estrellas + CASE WHEN p_calificacion = 2 THEN 1 ELSE 0 END,
            calificaciones_1_estrella = calificaciones_1_estrella + CASE WHEN p_calificacion = 1 THEN 1 ELSE 0 END,
            ultima_calificacion = NOW(),
            updated_at = NOW()
        WHERE pescador_id = p_pescador_id;

        SELECT (
            (calificaciones_5_estrellas * 5 +
             calificaciones_4_estrellas * 4 +
             calificaciones_3_estrellas * 3 +
             calificaciones_2_estrellas * 2 +
             calificaciones_1_estrella * 1)::DECIMAL
            / NULLIF(total_calificaciones, 0)
        )::DECIMAL(3,2)
        INTO nueva_calificacion
        FROM public.reputacion_pescadores
        WHERE pescador_id = p_pescador_id;

        UPDATE public.reputacion_pescadores
        SET calificacion_promedio = COALESCE(nueva_calificacion, 0)
        WHERE pescador_id = p_pescador_id;

        SELECT viajes_completados INTO v_viajes_completados
        FROM public.reputacion_pescadores
        WHERE pescador_id = p_pescador_id;

        IF nueva_calificacion >= 4.8 AND v_viajes_completados >= 50 THEN
            nuevo_nivel_reputacion := 'elite';
        ELSIF nueva_calificacion >= 4.5 AND v_viajes_completados >= 20 THEN
            nuevo_nivel_reputacion := 'experto';
        ELSIF nueva_calificacion >= 4.0 AND v_viajes_completados >= 10 THEN
            nuevo_nivel_reputacion := 'intermedio';
        ELSE
            nuevo_nivel_reputacion := 'novato';
        END IF;

        UPDATE public.reputacion_pescadores
        SET nivel_reputacion = nuevo_nivel_reputacion
        WHERE pescador_id = p_pescador_id;
    END IF;

    RETURN QUERY
    SELECT TRUE,
           'Reputación del pescador actualizada'::TEXT,
           nueva_calificacion,
           nuevo_nivel_reputacion;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Backfill desde calificaciones existentes (capitán → pescador)
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT
            cv.calificado_id::UUID AS pescador_id,
            cv.calificacion::INTEGER AS calificacion
        FROM public.calificaciones_viaje cv
        WHERE cv.calificador_rol = 'capitan'
          AND cv.calificado_id IS NOT NULL
        ORDER BY cv.created_at ASC
    LOOP
        PERFORM public.actualizar_reputacion_pescador(rec.pescador_id, rec.calificacion);
    END LOOP;
END $$;
