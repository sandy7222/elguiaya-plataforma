-- =====================================================
-- Funciones RPC para el módulo de Branding
-- =====================================================

-- 1. Función para obtener configuración de login
CREATE OR REPLACE FUNCTION public.obtener_configuracion_login()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    config_result jsonb;
BEGIN
    -- Construir objeto JSON con la configuración de login
    SELECT jsonb_build_object(
        'background_url', COALESCE(MAX(CASE WHEN clave = 'login_background_url' THEN valor END), NULL),
        'opacity', COALESCE(MAX(CASE WHEN clave = 'login_opacity' THEN valor END), '0.7')::float,
        'brightness', COALESCE(MAX(CASE WHEN clave = 'login_brightness' THEN valor END), '0.5')::float,
        'logo_url', COALESCE(MAX(CASE WHEN clave = 'logo_url' THEN valor END), NULL),
        'favicon_url', COALESCE(MAX(CASE WHEN clave = 'favicon_url' THEN valor END), NULL),
        'color_primario', COALESCE(MAX(CASE WHEN clave = 'color_primario' THEN valor END), '#0D6EFD'),
        'color_secundario', COALESCE(MAX(CASE WHEN clave = 'color_secundario' THEN valor END), '#6C757D'),
        'color_fondo', COALESCE(MAX(CASE WHEN clave = 'color_fondo' THEN valor END), '#F8F9FA'),
        'font_family', COALESCE(MAX(CASE WHEN clave = 'font_family' THEN valor END), 'Roboto')
    ) INTO config_result
    FROM configuracion_app
    WHERE clave IN (
        'login_background_url', 'login_opacity', 'login_brightness',
        'logo_url', 'favicon_url', 'color_primario', 
        'color_secundario', 'color_fondo', 'font_family'
    );
    
    RETURN config_result;
END;
$$;

-- 2. Función para actualizar configuración de branding
CREATE OR REPLACE FUNCTION public.actualizar_configuracion(
    p_clave TEXT,
    p_valor TEXT,
    p_tipo_valor TEXT DEFAULT 'texto',
    p_descripcion TEXT DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_id TEXT;
BEGIN
    -- Obtener ID del usuario actual
    user_id := auth.uid();
    
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado';
    END IF;
    
    -- Insertar o actualizar configuración
    INSERT INTO configuracion_app (
        clave, 
        valor, 
        tipo_valor, 
        descripcion,
        actualizado_at,
        actualizado_por
    ) VALUES (
        p_clave,
        p_valor,
        p_tipo_valor,
        p_descripcion,
        NOW(),
        user_id
    )
    ON CONFLICT (clave)
    DO UPDATE SET
        valor = EXCLUDED.valor,
        tipo_valor = EXCLUDED.tipo_valor,
        descripcion = COALESCE(EXCLUDED.descripcion, configuracion_app.descripcion),
        actualizado_at = NOW(),
        actualizado_por = EXCLUDED.actualizado_por;
    
    RETURN true;
END;
$$;

-- 3. Función para obtener toda la configuración de branding
CREATE OR REPLACE FUNCTION public.obtener_configuracion_branding()
RETURNS TABLE(
    clave TEXT,
    valor TEXT,
    tipo_valor TEXT,
    descripcion TEXT,
    actualizado_at TIMESTAMP,
    actualizado_por TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ca.clave,
        ca.valor,
        ca.tipo_valor,
        ca.descripcion,
        ca.actualizado_at,
        ca.actualizado_por
    FROM configuracion_app ca
    WHERE ca.clave LIKE '%branding%' OR 
          ca.clave LIKE '%login%' OR
          ca.clave LIKE '%color%' OR
          ca.clave LIKE '%logo%' OR
          ca.clave LIKE '%favicon%'
    ORDER BY ca.clave;
END;
$$;

-- =====================================================
-- Configuración de Permisos
-- =====================================================

-- Permisos para funciones RPC
GRANT EXECUTE ON FUNCTION public.obtener_configuracion_login() TO authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_configuracion TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_configuracion_branding() TO authenticated;

-- Permisos para la tabla de configuración
GRANT SELECT, INSERT, UPDATE ON configuracion_app TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE configuracion_app_id_seq TO authenticated;

-- =====================================================
-- Configuración de RLS (Row Level Security)
-- =====================================================

-- Habilitar RLS si no está habilitado
ALTER TABLE configuracion_app ENABLE ROW LEVEL SECURITY;

-- Política para que usuarios autenticados puedan ver la configuración
CREATE POLICY "Usuarios autenticados pueden ver configuración" ON configuracion_app
    FOR SELECT USING (auth.role() = 'authenticated');

-- Política para que usuarios autenticados puedan actualizar configuración
CREATE POLICY "Usuarios autenticados pueden actualizar configuración" ON configuracion_app
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Política para que usuarios autenticados puedan actualizar configuración
CREATE POLICY "Usuarios autenticados pueden modificar configuración" ON configuracion_app
    FOR UPDATE USING (auth.role() = 'authenticated');

-- =====================================================
-- Datos iniciales (opcional)
-- =====================================================

-- Insertar configuración por defecto si no existe
INSERT INTO configuracion_app (clave, valor, tipo_valor, descripcion) VALUES
    ('login_background_url', NULL, 'imagen_url', 'URL de imagen de fondo para pantalla de login'),
    ('login_opacity', '0.7', 'numero', 'Opacidad del overlay en pantalla de login (0.0-1.0)'),
    ('login_brightness', '0.5', 'numero', 'Brillo de imagen de fondo en login (0.0-1.0)'),
    ('logo_url', NULL, 'imagen_url', 'URL del logo principal de la aplicación'),
    ('favicon_url', NULL, 'imagen_url', 'URL del favicon de la aplicación'),
    ('color_primario', '#0D6EFD', 'color_hex', 'Color primario de la interfaz'),
    ('color_secundario', '#6C757D', 'color_hex', 'Color secundario de la interfaz'),
    ('color_fondo', '#F8F9FA', 'color_hex', 'Color de fondo principal'),
    ('font_family', 'Roboto', 'texto', 'Fuente principal de la aplicación')
ON CONFLICT (clave) DO NOTHING;

-- =====================================================
-- Vista para facilitar consultas de branding
-- =====================================================

CREATE OR REPLACE VIEW public.vista_configuracion_branding AS
SELECT 
    clave,
    valor,
    tipo_valor,
    descripcion,
    actualizado_at,
    actualizado_por
FROM configuracion_app
WHERE clave LIKE '%branding%' OR 
      clave LIKE '%login%' OR
      clave LIKE '%color%' OR
      clave LIKE '%logo%' OR
      clave LIKE '%favicon%';

-- Permisos para la vista
GRANT SELECT ON public.vista_configuracion_branding TO authenticated;
