-- Schema para tabla de disponibilidad de capitanes

CREATE TABLE disponibilidad (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  capitan_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  esta_bloqueado BOOLEAN NOT NULL DEFAULT true,
  motivo_bloqueo TEXT,
  creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Restricción para evitar duplicados
  UNIQUE(capitan_id, fecha)
);

-- Índices para optimización
CREATE INDEX idx_disponibilidad_capitan_id ON disponibilidad(capitan_id);
CREATE INDEX idx_disponibilidad_fecha ON disponibilidad(fecha);
CREATE INDEX idx_disponibilidad_capitan_fecha ON disponibilidad(capitan_id, fecha);
CREATE INDEX idx_disponibilidad_bloqueado ON disponibilidad(esta_bloqueado);

-- Políticas RLS (Row Level Security)
ALTER TABLE disponibilidad ENABLE ROW LEVEL SECURITY;

-- Política: Capitanes pueden ver su propia disponibilidad
CREATE POLICY "Capitanes pueden ver su disponibilidad" ON disponibilidad
  FOR SELECT USING (capitan_id = auth.uid());

-- Política: Capitanes pueden gestionar su disponibilidad
CREATE POLICY "Capitanes pueden gestionar su disponibilidad" ON disponibilidad
  FOR ALL USING (capitan_id = auth.uid());

-- Política: Usuarios pueden ver disponibilidad para reservas
CREATE POLICY "Usuarios pueden ver disponibilidad" ON disponibilidad
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM reservas r
      WHERE r.capitan_id = disponibilidad.capitan_id
        AND (r.pescador_id = auth.uid() OR r.capitan_id = auth.uid())
    )
  );

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp_disponibilidad()
RETURNS TRIGGER AS $$
BEGIN
  NEW.actualizado_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar timestamp automáticamente
CREATE TRIGGER trigger_actualizar_timestamp_disponibilidad
  BEFORE UPDATE ON disponibilidad
  FOR EACH ROW
  EXECUTE FUNCTION actualizar_timestamp_disponibilidad();

-- Vista para obtener disponibilidad con información del capitán
CREATE VIEW vista_disponibilidad_capitanes AS
SELECT 
  d.id,
  d.capitan_id,
  d.fecha,
  d.esta_bloqueado,
  d.motivo_bloqueo,
  d.creado_at,
  d.actualizado_at,
  u.email as capitan_email,
  u.raw_user_meta_data->>'nombre' as capitan_nombre,
  u.raw_user_meta_data->>'rol' as capitan_rol
FROM disponibilidad d
JOIN auth.users u ON d.capitan_id = u.id;

-- Función para verificar disponibilidad en un rango de fechas
CREATE OR REPLACE FUNCTION verificar_disponibilidad_rango(
  p_capitan_id UUID,
  p_fecha_inicio DATE,
  p_fecha_fin DATE
)
RETURNS TABLE (
  fecha DATE,
  disponible BOOLEAN,
  motivo TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(d.fecha, g.fecha) as fecha,
    COALESCE(NOT d.esta_bloqueado, true) as disponible,
    d.motivo_bloqueo
  FROM generate_series(p_fecha_inicio, p_fecha_fin, '1 day'::interval) g(fecha)
  LEFT JOIN disponibilidad d ON d.capitan_id = p_capitan_id AND d.fecha = g.fecha
  ORDER BY g.fecha;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener días bloqueados de un capitán
CREATE OR REPLACE FUNCTION obtener_dias_bloqueados(
  p_capitan_id UUID,
  p_fecha_inicio DATE DEFAULT NULL,
  p_fecha_fin DATE DEFAULT NULL
)
RETURNS TABLE (
  fecha DATE,
  motivo_bloqueo TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.fecha,
    d.motivo_bloqueo
  FROM disponibilidad d
  WHERE d.capitan_id = p_capitan_id
    AND d.esta_bloqueado = true
    AND (p_fecha_inicio IS NULL OR d.fecha >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR d.fecha <= p_fecha_fin)
  ORDER BY d.fecha;
END;
$$ LANGUAGE plpgsql;

-- Función para bloquear múltiples fechas a la vez
CREATE OR REPLACE FUNCTION bloquear_fechas_multiples(
  p_capitan_id UUID,
  p_fechas DATE[],
  p_motivo TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  fechas_procesadas INTEGER := 0;
  fecha_actual DATE;
BEGIN
  FOREACH fecha_actual IN ARRAY p_fechas
  LOOP
    INSERT INTO disponibilidad (capitan_id, fecha, esta_bloqueado, motivo_bloqueo)
    VALUES (p_capitan_id, fecha_actual, true, p_motivo)
    ON CONFLICT (capitan_id, fecha) 
    DO UPDATE SET 
      esta_bloqueado = true,
      motivo_bloqueo = EXCLUDED.motivo_bloqueo,
      actualizado_at = NOW();
    
    fechas_procesadas := fechas_procesadas + 1;
  END LOOP;
  
  RETURN fechas_procesadas;
END;
$$ LANGUAGE plpgsql;

-- Función para desbloquear múltiples fechas a la vez
CREATE OR REPLACE FUNCTION desbloquear_fechas_multiples(
  p_capitan_id UUID,
  p_fechas DATE[]
)
RETURNS INTEGER AS $$
DECLARE
  fechas_procesadas INTEGER := 0;
  fecha_actual DATE;
BEGIN
  FOREACH fecha_actual IN ARRAY p_fechas
  LOOP
    UPDATE disponibilidad 
    SET esta_bloqueado = false,
        motivo_bloqueo = NULL,
        actualizado_at = NOW()
    WHERE capitan_id = p_capitan_id AND fecha = fecha_actual;
    
    IF FOUND THEN
      fechas_procesadas := fechas_procesadas + 1;
    END IF;
  END LOOP;
  
  RETURN fechas_procesadas;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de disponibilidad
CREATE OR REPLACE FUNCTION obtener_estadisticas_disponibilidad(
  p_capitan_id UUID,
  p_mes INTEGER DEFAULT EXTRACT(MONTH FROM CURRENT_DATE),
  p_anio INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)
)
RETURNS TABLE (
  total_dias INTEGER,
  dias_bloqueados INTEGER,
  dias_disponibles INTEGER,
  porcentaje_disponibilidad NUMERIC
) AS $$
DECLARE
  v_total_dias INTEGER;
  v_dias_bloqueados INTEGER;
BEGIN
  -- Calcular total de días del mes
  v_total_dias := EXTRACT(DAY FROM (p_anio || '-' || p_mes || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day');
  
  -- Contar días bloqueados en el mes
  SELECT COUNT(*) INTO v_dias_bloqueados
  FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND esta_bloqueado = true
    AND EXTRACT(MONTH FROM fecha) = p_mes
    AND EXTRACT(YEAR FROM fecha) = p_anio;
  
  RETURN QUERY
  SELECT 
    v_total_dias,
    v_dias_bloqueados,
    v_total_dias - v_dias_bloqueados,
    CASE 
      WHEN v_total_dias > 0 THEN 
        ROUND(((v_total_dias - v_dias_bloqueados)::NUMERIC / v_total_dias) * 100, 2)
      ELSE 0
    END;
END;
$$ LANGUAGE plpgsql;
