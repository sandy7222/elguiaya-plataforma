-- Schema simplificado para tabla de mensajes de chat en Supabase

CREATE TABLE mensajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reserva_id UUID NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
  emisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receptor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contenido TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX idx_mensajes_reserva_id ON mensajes(reserva_id);
CREATE INDEX idx_mensajes_emisor_id ON mensajes(emisor_id);
CREATE INDEX idx_mensajes_receptor_id ON mensajes(receptor_id);
CREATE INDEX idx_mensajes_created_at ON mensajes(created_at);
CREATE INDEX idx_mensajes_reserva_creado ON mensajes(reserva_id, created_at);

-- Políticas RLS (Row Level Security)
ALTER TABLE mensajes ENABLE ROW LEVEL SECURITY;

-- Política: Usuarios pueden ver mensajes de sus reservas (como emisor o receptor)
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

-- Política: Usuarios pueden eliminar sus propios mensajes
CREATE POLICY "Usuarios pueden eliminar sus propios mensajes" ON mensajes
  FOR DELETE USING (emisor_id = auth.uid());

-- Vista para obtener mensajes con información de usuarios
CREATE VIEW vista_mensajes_chat AS
SELECT 
  m.id,
  m.reserva_id,
  m.emisor_id,
  m.receptor_id,
  m.contenido,
  m.created_at,
  e.email as emisor_email,
  e.raw_user_meta_data->>'nombre' as emisor_nombre,
  e.raw_user_meta_data->>'rol' as emisor_rol,
  r.email as receptor_email,
  r.raw_user_meta_data->>'nombre' as receptor_nombre,
  r.raw_user_meta_data->>'rol' as receptor_rol
FROM mensajes m
JOIN auth.users e ON m.emisor_id = e.id
JOIN auth.users r ON m.receptor_id = r.id;
