-- Tabla para registrar las descargas de la aplicación con fecha y hora, origen y tipo de dispositivo
CREATE TABLE IF NOT EXISTS public.descargas_app (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  origen TEXT NOT NULL, -- 'qr', 'boton', 'direct_url'
  dispositivo TEXT NOT NULL -- 'Android', 'iOS', 'Otro'
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.descargas_app ENABLE ROW LEVEL SECURITY;

-- Crear política para permitir que cualquiera pueda insertar registros de descargas (acceso público anon)
CREATE POLICY "Permitir inserciones públicas anon" ON public.descargas_app
  FOR INSERT WITH CHECK (true);

-- Crear política para permitir que los administradores puedan consultar las descargas
CREATE POLICY "Administradores pueden ver descargas" ON public.descargas_app
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
        AND u.raw_user_meta_data->>'rol' = 'admin'
    )
  );

-- Crear índice para optimizar consultas de descargas por fecha y origen
CREATE INDEX idx_descargas_app_creado_at ON public.descargas_app(creado_at DESC);
CREATE INDEX idx_descargas_app_origen ON public.descargas_app(origen);
