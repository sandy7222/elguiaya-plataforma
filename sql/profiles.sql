-- Crear tabla profiles para el perfil de usuario maestro
CREATE TABLE IF NOT EXISTS profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    dni VARCHAR(20),
    telefono VARCHAR(30),
    direccion_calle VARCHAR(200),
    direccion_numero VARCHAR(20),
    localidad VARCHAR(100),
    foto_dni_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_dni ON profiles(dni);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- Crear trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_timestamp
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Insertar perfil de ejemplo (user_id de prueba)
INSERT INTO profiles (user_id, dni, telefono, direccion_calle, direccion_numero, localidad, foto_dni_url) VALUES
(
    '00000000-0000-0000-0000-000000000000',
    '12345678',
    '11-1234-5678',
    'Avenida Siempreviva',
    '742',
    'Springfield',
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=400&h=200&fit=crop'
) ON CONFLICT (user_id) DO NOTHING;

-- Política de seguridad (RLS) - Temporalmente sin restricciones
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Política para que todos puedan ver perfiles (temporal)
CREATE POLICY "Publicar perfiles"
ON profiles FOR SELECT
USING (true);

-- Política para que todos puedan modificar perfiles (temporal)
CREATE POLICY "Administrar perfiles"
ON profiles FOR ALL
USING (true)
WITH CHECK (true);

-- Función para obtener o crear perfil de usuario
CREATE OR REPLACE FUNCTION get_or_create_profile(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    dni VARCHAR(20),
    telefono VARCHAR(30),
    direccion_calle VARCHAR(200),
    direccion_numero VARCHAR(20),
    localidad VARCHAR(100),
    foto_dni_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Intentar obtener perfil existente
    RETURN QUERY
    SELECT p.*
    FROM profiles p
    WHERE p.user_id = p_user_id;
    
    -- Si no existe, crear uno nuevo
    IF NOT FOUND THEN
        INSERT INTO profiles (user_id)
        VALUES (p_user_id)
        RETURNING *;
    END IF;
END;
$$ LANGUAGE plpgsql;
