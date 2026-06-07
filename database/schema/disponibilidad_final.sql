-- Schema final para tabla de disponibilidad con Realtime habilitado

CREATE TABLE disponibilidad (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  capitan_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('reserva', 'bloqueo_manual')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Restricción para evitar duplicados por capitan y fecha
  UNIQUE(capitan_id, fecha)
);

-- Índices para optimización y consultas rápidas
CREATE INDEX idx_disponibilidad_capitan_id ON disponibilidad(capitan_id);
CREATE INDEX idx_disponibilidad_fecha ON disponibilidad(fecha);
CREATE INDEX idx_disponibilidad_tipo ON disponibilidad(tipo);
CREATE INDEX idx_disponibilidad_capitan_fecha ON disponibilidad(capitan_id, fecha);
CREATE INDEX idx_disponibilidad_fecha_tipo ON disponibilidad(fecha, tipo);

-- Habilitar Realtime para esta tabla
ALTER TABLE disponibilidad ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE disponibilidad;

-- Políticas RLS (Row Level Security) para seguridad y consistencia

-- Política: Capitanes pueden ver su propia disponibilidad
CREATE POLICY "Capitanes pueden ver su disponibilidad" ON disponibilidad
  FOR SELECT USING (
    capitan_id = auth.uid()
  );

-- Política: Capitanes pueden insertar su propia disponibilidad
CREATE POLICY "Capitanes pueden insertar su disponibilidad" ON disponibilidad
  FOR INSERT WITH CHECK (
    capitan_id = auth.uid()
  );

-- Política: Capitanes pueden actualizar su propia disponibilidad
CREATE POLICY "Capitanes pueden actualizar su disponibilidad" ON disponibilidad
  FOR UPDATE USING (
    capitan_id = auth.uid()
  );

-- Política: Capitanes pueden eliminar su propia disponibilidad
CREATE POLICY "Capitanes pueden eliminar su disponibilidad" ON disponibilidad
  FOR DELETE USING (
    capitan_id = auth.uid()
  );

-- Política: Usuarios pueden ver disponibilidad para reservas (solo lectura)
CREATE POLICY "Usuarios pueden ver disponibilidad para reservas" ON disponibilidad
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM reservas r
      WHERE r.capitan_id = disponibilidad.capitan_id
        AND (r.pescador_id = auth.uid() OR r.capitan_id = auth.uid())
    )
  );

-- Vista para obtener disponibilidad con información del capitán
CREATE VIEW vista_disponibilidad_capitanes AS
SELECT 
  d.id,
  d.capitan_id,
  d.fecha,
  d.tipo,
  d.created_at,
  p.nombre as capitan_nombre,
  p.email as capitan_email,
  p.cbu -- cbu en minúsculas como se solicitó
FROM disponibilidad d
JOIN perfiles p ON d.capitan_id = p.id;

-- Función para verificar disponibilidad de un capitán en una fecha específica
CREATE OR REPLACE FUNCTION verificar_disponibilidad_fecha(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  v_disponible BOOLEAN := TRUE;
BEGIN
  -- Verificar si existe un bloqueo para la fecha
  SELECT NOT EXISTS(
    SELECT 1 FROM disponibilidad 
    WHERE capitan_id = p_capitan_id 
      AND fecha = p_fecha 
      AND tipo = 'bloqueo_manual'
  ) INTO v_disponible;
  
  RETURN v_disponible;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener fechas bloqueadas de un capitán
CREATE OR REPLACE FUNCTION obtener_fechas_bloqueadas(
  p_capitan_id UUID,
  p_fecha_inicio DATE DEFAULT NULL,
  p_fecha_fin DATE DEFAULT NULL
)
RETURNS TABLE (
  fecha DATE,
  tipo TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.fecha,
    d.tipo,
    d.created_at
  FROM disponibilidad d
  WHERE d.capitan_id = p_capitan_id
    AND d.tipo = 'bloqueo_manual'
    AND (p_fecha_inicio IS NULL OR d.fecha >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR d.fecha <= p_fecha_fin)
  ORDER BY d.fecha;
END;
$$ LANGUAGE plpgsql;

-- Función para validación de último segundo (antes de procesar pago)
CREATE OR REPLACE FUNCTION validar_disponibilidad_ultimo_segundo(
  p_capitan_id UUID,
  p_fecha_reserva DATE
)
RETURNS TABLE (
  disponible BOOLEAN,
  mensaje TEXT,
  tiene_bloqueo BOOLEAN,
  motivo_bloqueo TEXT
) AS $$
DECLARE
  v_tiene_bloqueo BOOLEAN := FALSE;
  v_disponible BOOLEAN := TRUE;
  v_mensaje TEXT := 'Fecha disponible para reserva';
BEGIN
  -- Verificar si existe un bloqueo manual
  SELECT EXISTS(
    SELECT 1 FROM disponibilidad 
    WHERE capitan_id = p_capitan_id 
      AND fecha = p_fecha_reserva 
      AND tipo = 'bloqueo_manual'
  ) INTO v_tiene_bloqueo;
  
  -- Verificar si ya existe una reserva para esa fecha
  SELECT NOT EXISTS(
    SELECT 1 FROM disponibilidad 
    WHERE capitan_id = p_capitan_id 
      AND fecha = p_fecha_reserva 
      AND tipo = 'reserva'
  ) INTO v_disponible;
  
  -- Construir mensaje de respuesta
  IF v_tiene_bloqueo THEN
    v_disponible := FALSE;
    v_mensaje := 'Fecha bloqueada por el capitán';
  ELSIF NOT v_disponible THEN
    v_mensaje := 'Fecha ya reservada';
  ELSE
    v_mensaje := 'Fecha disponible para reserva';
  END IF;
  
  RETURN QUERY SELECT 
    v_disponible, 
    v_mensaje, 
    v_tiene_bloqueo, 
    CASE WHEN v_tiene_bloqueo THEN 'Bloqueado manualmente' ELSE NULL END;
END;
$$ LANGUAGE plpgsql;

-- Función para bloquear una fecha específica
CREATE OR REPLACE FUNCTION bloquear_fecha(
  p_capitan_id UUID,
  p_fecha DATE,
  p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_resultado BOOLEAN := FALSE;
BEGIN
  -- Insertar o actualizar el bloqueo
  INSERT INTO disponibilidad (capitan_id, fecha, tipo)
  VALUES (p_capitan_id, p_fecha, 'bloqueo_manual')
  ON CONFLICT (capitan_id, fecha) 
  DO UPDATE SET 
    tipo = 'bloqueo_manual',
    created_at = NOW();
  
  v_resultado := TRUE;
  RETURN v_resultado;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para desbloquear una fecha específica
CREATE OR REPLACE FUNCTION desbloquear_fecha(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  v_resultado BOOLEAN := FALSE;
BEGIN
  -- Eliminar el registro de bloqueo
  DELETE FROM disponibilidad 
  WHERE capitan_id = p_capitan_id 
    AND fecha = p_fecha 
    AND tipo = 'bloqueo_manual';
  
  v_resultado := FOUND;
  RETURN v_resultado;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para marcar una fecha como reservada
CREATE OR REPLACE FUNCTION marcar_fecha_reservada(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  v_resultado BOOLEAN := FALSE;
BEGIN
  -- Insertar o actualizar la reserva
  INSERT INTO disponibilidad (capitan_id, fecha, tipo)
  VALUES (p_capitan_id, p_fecha, 'reserva')
  ON CONFLICT (capitan_id, fecha) 
  DO UPDATE SET 
    tipo = 'reserva',
    created_at = NOW();
  
  v_resultado := TRUE;
  RETURN v_resultado;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para liberar una fecha reservada
CREATE OR REPLACE FUNCTION liberar_fecha_reservada(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  v_resultado BOOLEAN := FALSE;
BEGIN
  -- Eliminar el registro de reserva
  DELETE FROM disponibilidad 
  WHERE capitan_id = p_capitan_id 
    AND fecha = p_fecha 
    AND tipo = 'reserva';
  
  v_resultado := FOUND;
  RETURN v_resultado;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
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
  dias_reservados INTEGER,
  dias_disponibles INTEGER,
  porcentaje_disponibilidad NUMERIC
) AS $$
DECLARE
  v_total_dias INTEGER;
  v_dias_bloqueados INTEGER;
  v_dias_reservados INTEGER;
BEGIN
  -- Calcular total de días del mes
  v_total_dias := EXTRACT(DAY FROM (p_anio || '-' || p_mes || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day');
  
  -- Contar días bloqueados en el mes
  SELECT COUNT(*) INTO v_dias_bloqueados
  FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND tipo = 'bloqueo_manual'
    AND EXTRACT(MONTH FROM fecha) = p_mes
    AND EXTRACT(YEAR FROM fecha) = p_anio;
  
  -- Contar días reservados en el mes
  SELECT COUNT(*) INTO v_dias_reservados
  FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND tipo = 'reserva'
    AND EXTRACT(MONTH FROM fecha) = p_mes
    AND EXTRACT(YEAR FROM fecha) = p_anio;
  
  RETURN QUERY
  SELECT 
    v_total_dias,
    v_dias_bloqueados,
    v_dias_reservados,
    v_total_dias - v_dias_bloqueados - v_dias_reservados,
    CASE 
      WHEN v_total_dias > 0 THEN 
        ROUND(((v_total_dias - v_dias_bloqueados - v_dias_reservados)::NUMERIC / v_total_dias) * 100, 2)
      ELSE 0
    END;
END;
$$ LANGUAGE plpgsql;

-- Trigger para asegurar consistencia con cbu en minúsculas
CREATE OR REPLACE FUNCTION validar_capitan_cbu()
RETURNS TRIGGER AS $$
BEGIN
  -- Verificar que el capitán tenga cbu configurado (en minúsculas)
  IF NOT EXISTS (
    SELECT 1 FROM perfiles 
    WHERE id = NEW.capitan_id 
      AND cbu IS NOT NULL 
      AND cbu != ''
  ) THEN
    RAISE EXCEPTION 'El capitán debe tener un CBU configurado para gestionar disponibilidad';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar cbu antes de insertar/update
CREATE TRIGGER trigger_validar_capitan_cbu
  BEFORE INSERT OR UPDATE ON disponibilidad
  FOR EACH ROW
  EXECUTE FUNCTION validar_capitan_cbu();
