-- Schema para tabla de configuración de la aplicación (branding y estética)

CREATE TABLE configuracion_app (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave TEXT NOT NULL UNIQUE,
  valor TEXT,
  tipo_valor TEXT NOT NULL DEFAULT 'texto' CHECK (tipo_valor IN ('texto', 'numero', 'imagen_url', 'boolean', 'json')),
  descripcion TEXT,
  categoria TEXT NOT NULL DEFAULT 'general' CHECK (categoria IN ('general', 'branding', 'estetica', 'funcional')),
  actualizado_por UUID REFERENCES auth.users(id),
  creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX idx_configuracion_app_clave ON configuracion_app(clave);
CREATE INDEX idx_configuracion_app_categoria ON configuracion_app(categoria);
CREATE INDEX idx_configuracion_app_tipo_valor ON configuracion_app(tipo_valor);

-- Políticas RLS (Row Level Security)
ALTER TABLE configuracion_app ENABLE ROW LEVEL SECURITY;

-- Política: Solo administradores pueden ver configuración
CREATE POLICY "Administradores pueden ver configuración" ON configuracion_app
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
        AND u.raw_user_meta_data->>'rol' = 'admin'
    )
  );

-- Política: Solo administradores pueden insertar configuración
CREATE POLICY "Administradores pueden insertar configuración" ON configuracion_app
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
        AND u.raw_user_meta_data->>'rol' = 'admin'
    )
  );

-- Política: Solo administradores pueden actualizar configuración
CREATE POLICY "Administradores pueden actualizar configuración" ON configuracion_app
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
        AND u.raw_user_meta_data->>'rol' = 'admin'
    )
  );

-- Política: Solo administradores pueden eliminar configuración
CREATE POLICY "Administradores pueden eliminar configuración" ON configuracion_app
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
        AND u.raw_user_meta_data->>'rol' = 'admin'
    )
  );

-- Política: Usuarios públicos pueden leer configuración de branding (solo lectura)
CREATE POLICY "Usuarios públicos pueden leer branding" ON configuracion_app
  FOR SELECT USING (
    categoria IN ('branding', 'estetica') AND 
    clave IN ('login_background_url', 'login_opacity', 'login_brightness')
  );

-- Función para actualizar timestamp automáticamente
CREATE OR REPLACE FUNCTION actualizar_timestamp_configuracion()
RETURNS TRIGGER AS $$
BEGIN
  NEW.actualizado_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar timestamp automáticamente
CREATE TRIGGER trigger_actualizar_timestamp_configuracion
  BEFORE UPDATE ON configuracion_app
  FOR EACH ROW
  EXECUTE FUNCTION actualizar_timestamp_configuracion();

-- Configuración inicial por defecto
INSERT INTO configuracion_app (clave, valor, tipo_valor, descripcion, categoria) VALUES
  ('login_background_url', NULL, 'imagen_url', 'URL de imagen de fondo para pantalla de login', 'branding'),
  ('login_opacity', '0.7', 'numero', 'Opacidad del overlay en pantalla de login (0.0-1.0)', 'estetica'),
  ('login_brightness', '0.5', 'numero', 'Brillo de imagen de fondo en login (0.0-1.0)', 'estetica'),
  ('app_primary_color', '#0066FF', 'texto', 'Color primario de la aplicación', 'branding'),
  ('app_secondary_color', '#00FF00', 'texto', 'Color secundario de la aplicación', 'branding'),
  ('app_logo_url', NULL, 'imagen_url', 'URL del logo de la aplicación', 'branding'),
  ('maintenance_mode', 'false', 'boolean', 'Modo mantenimiento activado', 'funcional'),
  ('max_file_size_mb', '10', 'numero', 'Tamaño máximo de archivos en MB', 'funcional');

-- Función para obtener configuración por clave
CREATE OR REPLACE FUNCTION obtener_configuracion(p_clave TEXT)
RETURNS TEXT AS $$
DECLARE
  v_valor TEXT;
BEGIN
  SELECT valor INTO v_valor
  FROM configuracion_app
  WHERE clave = p_clave;
  
  RETURN v_valor;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener configuración por categoría
CREATE OR REPLACE FUNCTION obtener_configuracion_categoria(p_categoria TEXT)
RETURNS TABLE (
  clave TEXT,
  valor TEXT,
  tipo_valor TEXT,
  descripcion TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ca.clave,
    ca.valor,
    ca.tipo_valor,
    ca.descripcion
  FROM configuracion_app ca
  WHERE ca.categoria = p_categoria
  ORDER BY ca.clave;
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar configuración
CREATE OR REPLACE FUNCTION actualizar_configuracion(
  p_clave TEXT,
  p_valor TEXT,
  p_tipo_valor TEXT DEFAULT NULL,
  p_descripcion TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_usuario_id UUID := auth.uid();
  v_es_admin BOOLEAN := FALSE;
BEGIN
  -- Verificar si es administrador
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = v_usuario_id
      AND u.raw_user_meta_data->>'rol' = 'admin'
  ) INTO v_es_admin;
  
  IF NOT v_es_admin THEN
    RAISE EXCEPTION 'Solo los administradores pueden actualizar la configuración';
  END IF;
  
  -- Actualizar o insertar configuración
  UPDATE configuracion_app 
  SET 
    valor = p_valor,
    tipo_valor = COALESCE(p_tipo_valor, tipo_valor),
    descripcion = COALESCE(p_descripcion, descripcion),
    actualizado_por = v_usuario_id,
    actualizado_at = NOW()
  WHERE clave = p_clave;
  
  -- Si no existía, insertarlo
  IF NOT FOUND THEN
    INSERT INTO configuracion_app (
      clave, 
      valor, 
      tipo_valor, 
      descripcion, 
      actualizado_por
    ) VALUES (
      p_clave, 
      p_valor, 
      COALESCE(p_tipo_valor, 'texto'), 
      p_descripcion, 
      v_usuario_id
    );
  END IF;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener configuración de branding para login
CREATE OR REPLACE FUNCTION obtener_configuracion_login()
RETURNS TABLE (
  background_url TEXT,
  opacity NUMERIC,
  brightness NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT valor FROM configuracion_app WHERE clave = 'login_background_url')::TEXT,
    COALESCE((SELECT valor::NUMERIC FROM configuracion_app WHERE clave = 'login_opacity'), 0.7),
    COALESCE((SELECT valor::NUMERIC FROM configuracion_app WHERE clave = 'login_brightness'), 0.5);
END;
$$ LANGUAGE plpgsql;

-- Vista para configuración de branding
CREATE VIEW vista_configuracion_branding AS
SELECT 
  clave,
  valor,
  tipo_valor,
  descripcion,
  actualizado_at,
  u.email as actualizado_por_email,
  u.raw_user_meta_data->>'nombre' as actualizado_por_nombre
FROM configuracion_app ca
LEFT JOIN auth.users u ON ca.actualizado_por = u.id
WHERE ca.categoria IN ('branding', 'estetica')
ORDER BY ca.categoria, ca.clave;

-- Función para validar valores de configuración
CREATE OR REPLACE FUNCTION validar_configuracion(
  p_clave TEXT,
  p_valor TEXT,
  p_tipo_valor TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  CASE p_tipo_valor
    WHEN 'numero' THEN
      BEGIN
        PERFORM p_valor::NUMERIC;
        RETURN TRUE;
      EXCEPTION WHEN invalid_text_representation THEN
        RETURN FALSE;
      END;
    WHEN 'boolean' THEN
      RETURN p_valor IN ('true', 'false', 'TRUE', 'FALSE');
    WHEN 'imagen_url' THEN
      RETURN p_valor IS NULL OR p_valor ~* '^https?://.*\.(jpg|jpeg|png|gif|webp)$';
    ELSE
      RETURN TRUE; -- texto y json aceptan cualquier valor
  END;
END;
$$ LANGUAGE plpgsql;
