-- Schema para tabla de mensajes de chat en Supabase

CREATE TABLE mensajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reserva_id UUID NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
  emisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  texto TEXT NOT NULL,
  tipo_emisor VARCHAR(20) NOT NULL CHECK (tipo_emisor IN ('pescador', 'capitan', 'admin')),
  leido BOOLEAN DEFAULT FALSE,
  creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX idx_mensajes_reserva_id ON mensajes(reserva_id);
CREATE INDEX idx_mensajes_emisor_id ON mensajes(emisor_id);
CREATE INDEX idx_mensajes_creado_at ON mensajes(creado_at);
CREATE INDEX idx_mensajes_reserva_emisor ON mensajes(reserva_id, emisor_id);

-- Políticas RLS (Row Level Security)
ALTER TABLE mensajes ENABLE ROW LEVEL SECURITY;

-- Política: Usuarios pueden ver mensajes de sus propias reservas
CREATE POLICY "Usuarios pueden ver mensajes de sus reservas" ON mensajes
  FOR SELECT USING (
    reserva_id IN (
      SELECT id FROM reservas 
      WHERE pescador_id = auth.uid() 
         OR capitan_id = auth.uid()
    )
  );

-- Política: Usuarios pueden enviar mensajes a sus reservas
CREATE POLICY "Usuarios pueden enviar mensajes a sus reservas" ON mensajes
  FOR INSERT WITH CHECK (
    reserva_id IN (
      SELECT id FROM reservas 
      WHERE pescador_id = auth.uid() 
         OR capitan_id = auth.uid()
    ) AND emisor_id = auth.uid()
  );

-- Política: Usuarios pueden actualizar sus propios mensajes (solo para marcar como leído)
CREATE POLICY "Usuarios pueden actualizar mensajes leídos" ON mensajes
  FOR UPDATE USING (
    emisor_id != auth.uid() AND -- Solo puede actualizar mensajes que no envió
    reserva_id IN (
      SELECT id FROM reservas 
      WHERE pescador_id = auth.uid() 
         OR capitan_id = auth.uid()
    )
  );

-- Política: Usuarios pueden eliminar sus propios mensajes
CREATE POLICY "Usuarios pueden eliminar sus propios mensajes" ON mensajes
  FOR DELETE USING (emisor_id = auth.uid());

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp_mensajes()
RETURNS TRIGGER AS $$
BEGIN
  NEW.actualizado_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar timestamp automáticamente
CREATE TRIGGER trigger_actualizar_timestamp_mensajes
  BEFORE UPDATE ON mensajes
  FOR EACH ROW
  EXECUTE FUNCTION actualizar_timestamp_mensajes();

-- Vista para obtener mensajes con información del emisor
CREATE VIEW vista_mensajes_con_emisor AS
SELECT 
  m.id,
  m.reserva_id,
  m.emisor_id,
  m.texto,
  m.tipo_emisor,
  m.leido,
  m.creado_at,
  m.actualizado_at,
  u.email as emisor_email,
  u.raw_user_meta_data->>'nombre' as emisor_nombre,
  u.raw_user_meta_data->>'rol' as emisor_rol
FROM mensajes m
JOIN auth.users u ON m.emisor_id = u.id;

-- Función para marcar mensajes como leídos
CREATE OR REPLACE FUNCTION marcar_mensajes_leidos(
  p_reserva_id UUID,
  p_usuario_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  mensajes_actualizados INTEGER;
BEGIN
  UPDATE mensajes 
  SET leido = TRUE 
  WHERE reserva_id = p_reserva_id 
    AND emisor_id != p_usuario_id 
    AND leido = FALSE;
  
  GET DIAGNOSTICS mensajes_actualizados = ROW_COUNT;
  RETURN mensajes_actualizados;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener conteo de mensajes no leídos
CREATE OR REPLACE FUNCTION contar_mensajes_no_leidos(p_usuario_id UUID)
RETURNS INTEGER AS $$
DECLARE
  conteo INTEGER;
BEGIN
  SELECT COUNT(*) INTO conteo
  FROM mensajes m
  JOIN reservas r ON m.reserva_id = r.id
  WHERE (r.pescador_id = p_usuario_id OR r.capitan_id = p_usuario_id)
    AND m.emisor_id != p_usuario_id
    AND m.leido = FALSE;
  
  RETURN COALESCE(conteo, 0);
END;
$$ LANGUAGE plpgsql;
