-- ============================================================================
-- ARQUITECTURA DE CALIFICACIÓN MULTIDIMENSIONAL Y VERIFICABLE (CAPITÁN YA)
-- ============================================================================
-- Este script define la estructura y lógica de base de datos para el sistema de
-- reputación multidimensional, auditoría anti-fraude y penalizaciones reactivas.

-- 1. CREAR LA TABLA DE CALIFICACIONES SI NO EXISTE
CREATE TABLE IF NOT EXISTS calificaciones_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    calificador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE, -- pescador que califica
    capitán_calificado_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    calificacion INTEGER CHECK (calificacion >= 1 AND calificacion <= 5),
    comentario TEXT,
    aspectos_puntuados JSONB DEFAULT '{}'::JSONB, -- {'puntualidad': 5, 'seguridad': 4, 'comunicacion': 5}
    respuesta_capitan TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- MODIFICACIONES A LA TABLA EXISTENTE DE CALIFICACIONES
ALTER TABLE calificaciones_viajes 
ADD COLUMN IF NOT EXISTS peso_calificacion DECIMAL(3,2) DEFAULT 1.00,
ADD COLUMN IF NOT EXISTS verificado BOOLEAN DEFAULT FALSE;

-- Asegurar restricción única: un pescador solo puede calificar un viaje una única vez
ALTER TABLE calificaciones_viajes 
DROP CONSTRAINT IF EXISTS unique_calificacion_viaje;

ALTER TABLE calificaciones_viajes 
ADD CONSTRAINT unique_calificacion_viaje UNIQUE (pedido_id, calificador_id);

-- 2. TABLA DE REPORTES E INCIDENTES DE VIAJES
CREATE TABLE IF NOT EXISTS reportes_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE SET NULL,
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    motivo VARCHAR(100) NOT NULL,
    descripcion TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'investigando', 'desestimado', 'confirmado'
    resolucion_admin TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en reportes
ALTER TABLE reportes_viajes ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para reportes
DROP POLICY IF EXISTS "Pescadores pueden insertar sus reportes" ON reportes_viajes;
CREATE POLICY "Pescadores pueden insertar sus reportes"
ON reportes_viajes FOR INSERT
WITH CHECK (auth.uid() = pescador_id);

DROP POLICY IF EXISTS "Usuarios pueden ver sus propios reportes" ON reportes_viajes;
CREATE POLICY "Usuarios pueden ver sus propios reportes"
ON reportes_viajes FOR SELECT
USING (auth.uid() = pescador_id OR auth.uid() = capitan_id);

-- 3. TABLA DE PENALIZACIONES DE CAPITANES
CREATE TABLE IF NOT EXISTS penalizaciones_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    reporte_id UUID REFERENCES reportes_viajes(id) ON DELETE CASCADE,
    puntos_penalizacion DECIMAL(3,2) DEFAULT 0.50, -- Reducción directa de rating
    motivo TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- CREAR LA TABLA DE REPUTACIÓN SI NO EXISTE
CREATE TABLE IF NOT EXISTS reputacion_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
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
    ultima_calificacion TIMESTAMP WITH TIME ZONE,
    nivel_reputacion VARCHAR(20) DEFAULT 'novato', -- 'novato', 'intermedio', 'experto', 'elite'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Asegurar restricción única en reputación para evitar registros duplicados por capitán
ALTER TABLE reputacion_capitanes DROP CONSTRAINT IF EXISTS unique_capitan_reputacion;
ALTER TABLE reputacion_capitanes ADD CONSTRAINT unique_capitan_reputacion UNIQUE (capitan_id);

-- ============================================================================
-- 4. ALGORITMO ANTI-FRAUDE (BEFORE INSERT OR UPDATE)
-- ============================================================================
CREATE OR REPLACE FUNCTION auditar_calificacion_fraude_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_viaje_capitan_id UUID;
    v_viaje_pescador_id UUID;
    v_viaje_estado VARCHAR(20);
    v_medio_pago VARCHAR(20);
BEGIN
    -- A. Anti-Autocalificación
    IF NEW.calificador_id = NEW.capitán_calificado_id THEN
        RAISE EXCEPTION 'Un capitán no puede calificarse a sí mismo.';
    END IF;

    -- B. Validar existencia del viaje/pedido
    SELECT capitan_id, pescador_id, estado
    INTO v_viaje_capitan_id, v_viaje_pescador_id, v_viaje_estado
    FROM pedidos
    WHERE id = NEW.pedido_id;

    IF v_viaje_capitan_id IS NULL THEN
        RAISE EXCEPTION 'El viaje especificado no existe.';
    END IF;

    -- Asegurar que el calificador sea el pescador del viaje
    IF NEW.calificador_id != v_viaje_pescador_id OR NEW.capitán_calificado_id != v_viaje_capitan_id THEN
        RAISE EXCEPTION 'Los participantes de la calificación no coinciden con los del viaje.';
    END IF;

    -- Asegurar que el viaje esté cerrado o listo para confirmar
    IF v_viaje_estado NOT IN ('cerrado', 'listo_para_confirmar') THEN
        RAISE EXCEPTION 'No se puede calificar un viaje que no ha finalizado.';
    END IF;

    -- C. Calcular peso dinámico de la calificación
    -- Verificar si se cobró por la plataforma
    SELECT medio INTO v_medio_pago
    FROM pagos
    WHERE pedido_id = NEW.pedido_id AND estado = 'aprobado'
    LIMIT 1;

    IF v_medio_pago = 'mercado_pago' THEN
        NEW.peso_calificacion := 2.00; -- Alta fidelidad
        NEW.verificado := TRUE;
    ELSIF v_medio_pago = 'efectivo' THEN
        NEW.peso_calificacion := 1.00; -- Verificado pero offline
        NEW.verificado := TRUE;
    ELSE
        NEW.peso_calificacion := 0.20; -- Enlace externo / sin registro de pago
        NEW.verificado := FALSE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditar_calificacion_fraude ON calificaciones_viajes;
CREATE TRIGGER trg_auditar_calificacion_fraude
BEFORE INSERT OR UPDATE ON calificaciones_viajes
FOR EACH ROW EXECUTE FUNCTION auditar_calificacion_fraude_fn();

-- ============================================================================
-- 5. CÁLCULO DE REPUTACIÓN PONDERADA Y PENALIZADA EN TIEMPO REAL (AFTER TRIGGER)
-- ============================================================================
CREATE OR REPLACE FUNCTION recalcular_reputacion_capitan_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_capitan_id UUID;
    v_total_viajes INTEGER;
    v_completados INTEGER;
    v_total_calificaciones INTEGER;
    v_suma_ponderada DECIMAL(12,4) := 0.0000;
    v_suma_pesos DECIMAL(12,4) := 0.0000;
    v_promedio_ponderado DECIMAL(3,2) := 0.00;
    v_total_penalizaciones DECIMAL(3,2) := 0.00;
    v_rating_final DECIMAL(3,2) := 0.00;
    v_nivel_reputacion VARCHAR(20) := 'novato';
BEGIN
    -- Identificar capitan_id según operación (INSERT, UPDATE, DELETE)
    IF TG_OP = 'DELETE' THEN
        v_capitan_id := OLD.capitán_calificado_id;
    ELSE
        v_capitan_id := NEW.capitán_calificado_id;
    END IF;

    -- A. Obtener estadísticas de viajes desde pedidos
    SELECT 
        COUNT(id),
        COUNT(id) FILTER (WHERE estado = 'cerrado')
    INTO v_total_viajes, v_completados
    FROM pedidos
    WHERE capitan_id = v_capitan_id;

    -- B. Calcular media ponderada de los aspectos multidimensionales
    SELECT 
        COALESCE(SUM(
            (
                COALESCE((aspectos_puntuados->>'puntualidad')::numeric, calificacion::numeric) +
                COALESCE((aspectos_puntuados->>'embarcacion')::numeric, calificacion::numeric) +
                COALESCE((aspectos_puntuados->>'guia_pesca')::numeric, calificacion::numeric) +
                COALESCE((aspectos_puntuados->>'trato')::numeric, calificacion::numeric) +
                COALESCE((aspectos_puntuados->>'equipamiento')::numeric, calificacion::numeric)
            ) / 5.0 * peso_calificacion
        ), 0.0000),
        COALESCE(SUM(peso_calificacion), 0.0000),
        COUNT(id)
    INTO v_suma_ponderada, v_suma_pesos, v_total_calificaciones
    FROM calificaciones_viajes
    WHERE capitán_calificado_id = v_capitan_id;

    IF v_suma_pesos > 0 THEN
        v_promedio_ponderado := (v_suma_ponderada / v_suma_pesos)::DECIMAL(3,2);
    ELSE
        v_promedio_ponderado := 0.00;
    END IF;

    -- C. Calcular deducciones por penalizaciones activas (reportes confirmados)
    SELECT COALESCE(SUM(puntos_penalizacion), 0.00)
    INTO v_total_penalizaciones
    FROM penalizaciones_capitanes
    WHERE capitan_id = v_capitan_id AND activo = TRUE;

    -- D. Rating Final (Mínimo 1.00, Máximo 5.00)
    v_rating_final := GREATEST(1.00, LEAST(5.00, v_promedio_ponderado - v_total_penalizaciones));

    -- E. Determinar nivel de reputación según viajes y promedio final
    IF v_rating_final >= 4.80 AND v_completados >= 30 THEN
        v_nivel_reputacion := 'elite';
    ELSIF v_rating_final >= 4.50 AND v_completados >= 15 THEN
        v_nivel_reputacion := 'experto';
    ELSIF v_rating_final >= 4.00 AND v_completados >= 5 THEN
        v_nivel_reputacion := 'intermedio';
    ELSE
        v_nivel_reputacion := 'novato';
    END IF;

    -- F. Insertar o actualizar tabla de reputación
    INSERT INTO reputacion_capitanes (
        capitan_id, calificacion_promedio, total_viajes, viajes_completados,
        total_calificaciones, nivel_reputacion, ultima_calificacion, updated_at
    ) VALUES (
        v_capitan_id, v_rating_final, v_total_viajes, v_completados,
        v_total_calificaciones, v_nivel_reputacion, NOW(), NOW()
    )
    ON CONFLICT (capitan_id) DO UPDATE SET
        calificacion_promedio = EXCLUDED.calificacion_promedio,
        total_viajes = EXCLUDED.total_viajes,
        viajes_completados = EXCLUDED.viajes_completados,
        total_calificaciones = EXCLUDED.total_calificaciones,
        nivel_reputacion = EXCLUDED.nivel_reputacion,
        ultima_calificacion = EXCLUDED.ultima_calificacion,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asignar triggers de actualización de promedio y nivel
DROP TRIGGER IF EXISTS trg_calificaciones_viajes_cambio ON calificaciones_viajes;
CREATE TRIGGER trg_calificaciones_viajes_cambio
AFTER INSERT OR UPDATE OR DELETE ON calificaciones_viajes
FOR EACH ROW EXECUTE FUNCTION recalcular_reputacion_capitan_fn();

DROP TRIGGER IF EXISTS trg_penalizaciones_cambio ON penalizaciones_capitanes;
CREATE TRIGGER trg_penalizaciones_cambio
AFTER INSERT OR UPDATE OR DELETE ON penalizaciones_capitanes
FOR EACH ROW EXECUTE FUNCTION recalcular_reputacion_capitan_fn();

-- ============================================================================
-- 6. ACCIÓN ANTE REPORTES CONFIRMADOS (TRIGGER)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_procesar_reporte_confirmado()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el reporte cambia a confirmado, aplicar penalización automática de -0.5 puntos
    IF NEW.estado = 'confirmado' AND OLD.estado != 'confirmado' THEN
        INSERT INTO penalizaciones_capitanes (capitan_id, reporte_id, puntos_penalizacion, motivo)
        VALUES (NEW.capitan_id, NEW.id, 0.50, 'Reporte de mal servicio verificado administrativamente: ' || NEW.motivo);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_procesar_reporte_confirmado ON reportes_viajes;
CREATE TRIGGER trg_procesar_reporte_confirmado
    AFTER UPDATE ON reportes_viajes
    FOR EACH ROW
    WHEN (NEW.estado = 'confirmado')
    EXECUTE FUNCTION trigger_procesar_reporte_confirmado();
