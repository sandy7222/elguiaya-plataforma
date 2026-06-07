-- Actualización para Carga de Documentación de Capitanes

-- 1. Asegurar columnas en tabla profiles (Master)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS seguro_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS embarcacion_url TEXT;

-- 2. Asegurar columnas en tabla guias (Legado/Específica)
ALTER TABLE guias ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE guias ADD COLUMN IF NOT EXISTS seguro_url TEXT;
ALTER TABLE guias ADD COLUMN IF NOT EXISTS embarcacion_url TEXT;

-- 3. Asegurar que existe la tabla de documentos vinculados si no existe
CREATE TABLE IF NOT EXISTS documentos_usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL, -- Referencia a auth.users.id
    tipo_doc VARCHAR(50) NOT NULL, -- 'seguro', 'embarcacion', 'avatar', 'dni', etc.
    url_storage TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'aprobado', 'rechazado'
    notas TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Crear índices para documentos
CREATE INDEX IF NOT EXISTS idx_documentos_usuarios_id ON documentos_usuarios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_documentos_usuarios_tipo ON documentos_usuarios(tipo_doc);

-- 5. Políticas de Seguridad (RLS) para documentos
ALTER TABLE documentos_usuarios ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'documentos_usuarios' AND policyname = 'Usuarios pueden ver sus propios documentos') THEN
        CREATE POLICY "Usuarios pueden ver sus propios documentos" ON documentos_usuarios
        FOR SELECT USING (auth.uid() = usuario_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'documentos_usuarios' AND policyname = 'Usuarios pueden insertar sus propios documentos') THEN
        CREATE POLICY "Usuarios pueden insertar sus propios documentos" ON documentos_usuarios
        FOR INSERT WITH CHECK (auth.uid() = usuario_id OR usuario_id IS NOT NULL); -- Permitir nulos temporalmente durante registro
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'documentos_usuarios' AND policyname = 'Admins pueden ver todos los documentos') THEN
        CREATE POLICY "Admins pueden ver todos los documentos" ON documentos_usuarios
        FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
    END IF;
END $$;
