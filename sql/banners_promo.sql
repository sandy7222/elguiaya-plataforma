-- Crear tabla banners_promo para el sistema de banners dinámicos
CREATE TABLE IF NOT EXISTS banners_promo (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    subtitulo TEXT NOT NULL,
    imagen_url TEXT NOT NULL,
    activo BOOLEAN DEFAULT true,
    orden INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_banners_promo_activo ON banners_promo(activo);
CREATE INDEX IF NOT EXISTS idx_banners_promo_orden ON banners_promo(orden);
CREATE INDEX IF NOT EXISTS idx_banners_promo_created_at ON banners_promo(created_at);

-- Crear trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_banners_promo_timestamp
    BEFORE UPDATE ON banners_promo
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Insertar banners de ejemplo
INSERT INTO banners_promo (titulo, subtitulo, imagen_url, activo, orden) VALUES
(
    '🎣 Ofertas Especiales de Pesca',
    'Descuentos de hasta 30% en equipos de pesca profesional',
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=800&h=400&fit=crop',
    true,
    1
),
(
    '⛺ Equipamiento de Camping',
    'Prepárate para tu próxima aventura con lo mejor en camping',
    'https://images.unsplash.com/photo-1504280390367-361c7a9ba8ad?w=800&h=400&fit=crop',
    true,
    2
),
(
    '🚢 Viajes de Pesca Exclusivos',
    'Únete a nuestras expediciones a los mejores spots de pesca',
    'https://images.unsplash.com/photo-1540202404-1b6271a4d6d9?w=800&h=400&fit=crop',
    true,
    3
);

-- Política de seguridad (RLS) - Solo administradores pueden modificar
ALTER TABLE banners_promo ENABLE ROW LEVEL SECURITY;

-- Política para que todos puedan ver banners activos
CREATE POLICY "Publicar banners activos"
ON banners_promo FOR SELECT
USING (activo = true);

-- Política para que solo administradores puedan modificar banners
CREATE POLICY "Administrar banners"
ON banners_promo FOR ALL
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');
