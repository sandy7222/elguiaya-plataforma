-- ============================================================
-- FIX: Corrección completa del Almanaque de Disponibilidad
-- Problema: La tabla 'disponibilidad' referenciaba 'perfiles'
--           en lugar de 'profiles', y el trigger de CBU bloqueaba
--           a capitanes que aún no tenían CBU cargado.
-- ============================================================

-- 1. Eliminar la tabla existente y sus dependencias para recrearla correctamente
DROP TABLE IF EXISTS disponibilidad CASCADE;

-- 2. Recrear la tabla con la referencia correcta a 'profiles'
CREATE TABLE disponibilidad (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  capitan_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('reserva', 'bloqueo_manual')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Restricción para evitar duplicados por capitán y fecha
  UNIQUE(capitan_id, fecha)
);

-- 3. Índices para optimización
CREATE INDEX idx_disponibilidad_capitan_id ON disponibilidad(capitan_id);
CREATE INDEX idx_disponibilidad_fecha ON disponibilidad(fecha);
CREATE INDEX idx_disponibilidad_tipo ON disponibilidad(tipo);
CREATE INDEX idx_disponibilidad_capitan_fecha ON disponibilidad(capitan_id, fecha);
CREATE INDEX idx_disponibilidad_fecha_tipo ON disponibilidad(fecha, tipo);

-- 4. Habilitar RLS y Realtime
ALTER TABLE disponibilidad ENABLE ROW LEVEL SECURITY;

-- Agregar a la publicación realtime (ignorar error si ya existe)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE disponibilidad;
EXCEPTION WHEN duplicate_object THEN
  -- Ya estaba en la publicación, ignorar
  NULL;
END;
$$;

-- 5. Políticas RLS corregidas
-- LECTURA: Cualquier usuario autenticado puede ver la disponibilidad
-- (necesario para que el sistema de notificaciones filtre capitanes bloqueados
--  y para que el calendario del pescador muestre fechas disponibles)
CREATE POLICY "Lectura publica de disponibilidad"
  ON disponibilidad
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERTAR: Solo el propio capitán puede bloquear/reservar sus fechas
CREATE POLICY "Capitanes pueden insertar su disponibilidad"
  ON disponibilidad
  FOR INSERT
  TO authenticated
  WITH CHECK (capitan_id = auth.uid());

-- ACTUALIZAR: Solo el propio capitán puede modificar sus registros
CREATE POLICY "Capitanes pueden actualizar su disponibilidad"
  ON disponibilidad
  FOR UPDATE
  TO authenticated
  USING (capitan_id = auth.uid());

-- ELIMINAR: Solo el propio capitán puede eliminar sus bloqueos
CREATE POLICY "Capitanes pueden eliminar su disponibilidad"
  ON disponibilidad
  FOR DELETE
  TO authenticated
  USING (capitan_id = auth.uid());

-- 6. Vista para disponibilidad con datos del capitán
-- (usa guias para obtener CBU ya que allí se almacena)
CREATE OR REPLACE VIEW vista_disponibilidad_capitanes AS
SELECT 
  d.id,
  d.capitan_id,
  d.fecha,
  d.tipo,
  d.created_at,
  p.nombre as capitan_nombre,
  p.email as capitan_email,
  g.cbu
FROM disponibilidad d
JOIN profiles p ON d.capitan_id = p.user_id
LEFT JOIN guias g ON d.capitan_id = g.id;

-- 7. Función: Verificar si una fecha está disponible para un capitán
-- Retorna TRUE si está disponible, FALSE si está bloqueada o reservada
CREATE OR REPLACE FUNCTION verificar_disponibilidad_fecha(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Si existe cualquier registro (bloqueo o reserva) retorna NO disponible
  RETURN NOT EXISTS(
    SELECT 1 FROM disponibilidad
    WHERE capitan_id = p_capitan_id
      AND fecha = p_fecha
  );
END;
$$;

-- 8. Función: Bloquear una fecha de forma manual (descanso voluntario)
CREATE OR REPLACE FUNCTION bloquear_fecha(
  p_capitan_id UUID,
  p_fecha DATE,
  p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO disponibilidad (capitan_id, fecha, tipo)
  VALUES (p_capitan_id, p_fecha, 'bloqueo_manual')
  ON CONFLICT (capitan_id, fecha)
  DO UPDATE SET
    tipo = 'bloqueo_manual',
    created_at = NOW();
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 9. Función: Desbloquear una fecha (sólo bloqueos manuales, no reservas)
CREATE OR REPLACE FUNCTION desbloquear_fecha(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND fecha = p_fecha
    AND tipo = 'bloqueo_manual';
  
  RETURN FOUND;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 10. Función: Marcar una fecha como reservada (cuando se confirma un viaje)
CREATE OR REPLACE FUNCTION marcar_fecha_reservada(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO disponibilidad (capitan_id, fecha, tipo)
  VALUES (p_capitan_id, p_fecha, 'reserva')
  ON CONFLICT (capitan_id, fecha)
  DO UPDATE SET
    tipo = 'reserva',
    created_at = NOW();
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 11. Función: Liberar una fecha reservada (cuando se cancela un viaje)
CREATE OR REPLACE FUNCTION liberar_fecha_reservada(
  p_capitan_id UUID,
  p_fecha DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND fecha = p_fecha
    AND tipo = 'reserva';
  
  RETURN FOUND;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 12. Función: Obtener fechas bloqueadas manualmente de un capitán
CREATE OR REPLACE FUNCTION obtener_fechas_bloqueadas(
  p_capitan_id UUID,
  p_fecha_inicio DATE DEFAULT NULL,
  p_fecha_fin DATE DEFAULT NULL
)
RETURNS TABLE (
  fecha DATE,
  tipo TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.fecha,
    d.tipo,
    d.created_at
  FROM disponibilidad d
  WHERE d.capitan_id = p_capitan_id
    AND (p_fecha_inicio IS NULL OR d.fecha >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR d.fecha <= p_fecha_fin)
  ORDER BY d.fecha;
END;
$$;

-- 13. Función: Validación de último segundo (antes de procesar el pago)
CREATE OR REPLACE FUNCTION validar_disponibilidad_ultimo_segundo(
  p_capitan_id UUID,
  p_fecha_reserva DATE
)
RETURNS TABLE (
  disponible BOOLEAN,
  mensaje TEXT,
  tiene_bloqueo BOOLEAN,
  motivo_bloqueo TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tipo TEXT;
  v_disponible BOOLEAN := TRUE;
  v_tiene_bloqueo BOOLEAN := FALSE;
  v_mensaje TEXT := 'Fecha disponible para reserva';
BEGIN
  -- Buscar cualquier registro para esa fecha
  SELECT d.tipo INTO v_tipo
  FROM disponibilidad d
  WHERE d.capitan_id = p_capitan_id
    AND d.fecha = p_fecha_reserva
  LIMIT 1;
  
  IF v_tipo IS NOT NULL THEN
    v_disponible := FALSE;
    IF v_tipo = 'bloqueo_manual' THEN
      v_tiene_bloqueo := TRUE;
      v_mensaje := 'Fecha bloqueada por el capitán (día de descanso)';
    ELSIF v_tipo = 'reserva' THEN
      v_mensaje := 'Fecha ya reservada por otro pescador';
    END IF;
  END IF;
  
  RETURN QUERY SELECT
    v_disponible,
    v_mensaje,
    v_tiene_bloqueo,
    CASE WHEN v_tiene_bloqueo THEN 'Bloqueado manualmente' ELSE NULL END;
END;
$$;

-- 14. Función: Estadísticas de disponibilidad para el panel del capitán
CREATE OR REPLACE FUNCTION obtener_estadisticas_disponibilidad(
  p_capitan_id UUID,
  p_mes INTEGER DEFAULT NULL,
  p_anio INTEGER DEFAULT NULL
)
RETURNS TABLE (
  total_dias INTEGER,
  dias_bloqueados INTEGER,
  dias_reservados INTEGER,
  dias_disponibles INTEGER,
  porcentaje_disponibilidad NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mes INTEGER := COALESCE(p_mes, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
  v_anio INTEGER := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
  v_total_dias INTEGER;
  v_dias_bloqueados INTEGER;
  v_dias_reservados INTEGER;
BEGIN
  -- Total días del mes
  v_total_dias := EXTRACT(DAY FROM (
    (v_anio::TEXT || '-' || LPAD(v_mes::TEXT, 2, '0') || '-01')::DATE
    + INTERVAL '1 month' - INTERVAL '1 day'
  ))::INTEGER;
  
  -- Días con bloqueo manual
  SELECT COUNT(*)::INTEGER INTO v_dias_bloqueados
  FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND tipo = 'bloqueo_manual'
    AND EXTRACT(MONTH FROM fecha) = v_mes
    AND EXTRACT(YEAR FROM fecha) = v_anio;
  
  -- Días con reserva
  SELECT COUNT(*)::INTEGER INTO v_dias_reservados
  FROM disponibilidad
  WHERE capitan_id = p_capitan_id
    AND tipo = 'reserva'
    AND EXTRACT(MONTH FROM fecha) = v_mes
    AND EXTRACT(YEAR FROM fecha) = v_anio;
  
  RETURN QUERY
  SELECT
    v_total_dias,
    v_dias_bloqueados,
    v_dias_reservados,
    v_total_dias - v_dias_bloqueados - v_dias_reservados,
    CASE
      WHEN v_total_dias > 0 THEN
        ROUND(
          ((v_total_dias - v_dias_bloqueados - v_dias_reservados)::NUMERIC / v_total_dias) * 100,
          2
        )
      ELSE 0
    END;
END;
$$;

-- 15. Permisos de ejecución para todas las funciones
GRANT EXECUTE ON FUNCTION verificar_disponibilidad_fecha(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION bloquear_fecha(UUID, DATE, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION desbloquear_fecha(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION marcar_fecha_reservada(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION liberar_fecha_reservada(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION obtener_fechas_bloqueadas(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION validar_disponibilidad_ultimo_segundo(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION obtener_estadisticas_disponibilidad(UUID, INTEGER, INTEGER) TO authenticated;
