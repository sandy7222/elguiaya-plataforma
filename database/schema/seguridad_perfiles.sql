-- Schema para sistema de seguridad: baneo y verificación de usuarios

-- Agregar campos de seguridad a tabla perfiles
ALTER TABLE perfiles 
ADD COLUMN estado_cuenta TEXT DEFAULT 'activo' CHECK (estado_cuenta IN ('activo', 'baneado')),
ADD COLUMN verificado BOOLEAN DEFAULT false,
ADD COLUMN fecha_verificacion TIMESTAMP WITH TIME ZONE,
ADD COLUMN motivo_baneo TEXT,
ADD COLUMN fecha_baneo TIMESTAMP WITH TIME ZONE,
ADD COLUMN baneado_por UUID REFERENCES auth.users(id);

-- Índices para optimización
CREATE INDEX idx_perfiles_estado_cuenta ON perfiles(estado_cuenta);
CREATE INDEX idx_perfiles_verificado ON perfiles(verificado);
CREATE INDEX idx_perfiles_baneado_por ON perfiles(baneado_por);

-- Tabla de logs de auditoría administrativa
CREATE TABLE logs_admin (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES auth.users(id),
  usuario_afectado_id UUID REFERENCES perfiles(id),
  tipo_accion TEXT NOT NULL CHECK (tipo_accion IN ('baneo', 'desbaneo', 'verificacion', 'desverificacion')),
  detalles TEXT,
  ip_address TEXT,
  user_agent TEXT,
  creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para logs
CREATE INDEX idx_logs_admin_admin_id ON logs_admin(admin_id);
CREATE INDEX idx_logs_admin_usuario_afectado ON logs_admin(usuario_afectado_id);
CREATE INDEX idx_logs_admin_tipo_accion ON logs_admin(tipo_accion);
CREATE INDEX idx_logs_admin_creado_at ON logs_admin(creado_at);

-- Políticas RLS para logs_admin
ALTER TABLE logs_admin ENABLE ROW LEVEL SECURITY;

-- Solo administradores pueden ver logs
CREATE POLICY "Administradores pueden ver logs" ON logs_admin
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'rol' = 'admin'
  )
);

-- Solo administradores pueden insertar logs
CREATE POLICY "Administradores pueden insertar logs" ON logs_admin
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'rol' = 'admin'
  )
);

-- Función para banear usuario
CREATE OR REPLACE FUNCTION banear_usuario(
  p_usuario_id UUID,
  p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_es_admin BOOLEAN := FALSE;
  v_usuario_email TEXT;
BEGIN
  -- Verificar si es administrador
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = v_admin_id
      AND u.raw_user_meta_data->>'rol' = 'admin'
  ) INTO v_es_admin;
  
  IF NOT v_es_admin THEN
    RAISE EXCEPTION 'Solo los administradores pueden banear usuarios';
  END IF;
  
  -- Obtener email del usuario afectado para el log
  SELECT email INTO v_usuario_email
  FROM perfiles
  WHERE id = p_usuario_id;
  
  -- Actualizar estado del usuario
  UPDATE perfiles 
  SET 
    estado_cuenta = 'baneado',
    motivo_baneo = p_motivo,
    fecha_baneo = NOW(),
    baneado_por = v_admin_id
  WHERE id = p_usuario_id;
  
  -- Registrar en logs
  INSERT INTO logs_admin (
    admin_id,
    usuario_afectado_id,
    tipo_accion,
    detalles
  ) VALUES (
    v_admin_id,
    p_usuario_id,
    'baneo',
    'Usuario baneado. Motivo: ' || COALESCE(p_motivo, 'No especificado')
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para desbanear usuario
CREATE OR REPLACE FUNCTION desbanear_usuario(
  p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_es_admin BOOLEAN := FALSE;
BEGIN
  -- Verificar si es administrador
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = v_admin_id
      AND u.raw_user_meta_data->>'rol' = 'admin'
  ) INTO v_es_admin;
  
  IF NOT v_es_admin THEN
    RAISE EXCEPTION 'Solo los administradores pueden desbanear usuarios';
  END IF;
  
  -- Actualizar estado del usuario
  UPDATE perfiles 
  SET 
    estado_cuenta = 'activo',
    motivo_baneo = NULL,
    fecha_baneo = NULL,
    baneado_por = NULL
  WHERE id = p_usuario_id;
  
  -- Registrar en logs
  INSERT INTO logs_admin (
    admin_id,
    usuario_afectado_id,
    tipo_accion,
    detalles
  ) VALUES (
    v_admin_id,
    p_usuario_id,
    'desbaneo',
    'Usuario desbaneado'
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para verificar capitán
CREATE OR REPLACE FUNCTION verificar_capitan(
  p_capitan_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_es_admin BOOLEAN := FALSE;
BEGIN
  -- Verificar si es administrador
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = v_admin_id
      AND u.raw_user_meta_data->>'rol' = 'admin'
  ) INTO v_es_admin;
  
  IF NOT v_es_admin THEN
    RAISE EXCEPTION 'Solo los administradores pueden verificar capitanes';
  END IF;
  
  -- Verificar que el usuario sea capitán
  IF NOT EXISTS (
    SELECT 1 FROM perfiles p
    WHERE p.id = p_capitan_id
      AND p.rol = 'capitan'
  ) THEN
    RAISE EXCEPTION 'El usuario no es un capitán';
  END IF;
  
  -- Actualizar estado de verificación
  UPDATE perfiles 
  SET 
    verificado = true,
    fecha_verificacion = NOW()
  WHERE id = p_capitan_id;
  
  -- Registrar en logs
  INSERT INTO logs_admin (
    admin_id,
    usuario_afectado_id,
    tipo_accion,
    detalles
  ) VALUES (
    v_admin_id,
    p_capitan_id,
    'verificacion',
    'Capitán verificado'
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para desverificar capitán
CREATE OR REPLACE FUNCTION desverificar_capitan(
  p_capitan_id UUID,
  p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_es_admin BOOLEAN := FALSE;
BEGIN
  -- Verificar si es administrador
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = v_admin_id
      AND u.raw_user_meta_data->>'rol' = 'admin'
  ) INTO v_es_admin;
  
  IF NOT v_es_admin THEN
    RAISE EXCEPTION 'Solo los administradores pueden desverificar capitanes';
  END IF;
  
  -- Actualizar estado de verificación
  UPDATE perfiles 
  SET 
    verificado = false,
    fecha_verificacion = NULL
  WHERE id = p_capitan_id;
  
  -- Registrar en logs
  INSERT INTO logs_admin (
    admin_id,
    usuario_afectado_id,
    tipo_accion,
    detalles
  ) VALUES (
    v_admin_id,
    p_capitan_id,
    'desverificacion',
    'Capitán desverificado. Motivo: ' || COALESCE(p_motivo, 'No especificado')
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para verificar estado de cuenta en login
CREATE OR REPLACE FUNCTION verificar_estado_login(
  p_email TEXT
)
RETURNS TABLE (
  permitido BOOLEAN,
  mensaje TEXT,
  estado_cuenta TEXT
) AS $$
DECLARE
  v_estado TEXT;
  v_motivo_baneo TEXT;
BEGIN
  -- Obtener estado de cuenta
  SELECT 
    p.estado_cuenta,
    p.motivo_baneo
  INTO v_estado, v_motivo_baneo
  FROM perfiles p
  WHERE p.email = p_email;
  
  -- Si no existe el perfil, permitir registro
  IF v_estado IS NULL THEN
    RETURN QUERY SELECT true, NULL::TEXT, 'no_existe'::TEXT;
    RETURN;
  END IF;
  
  -- Si está baneado, denegar acceso
  IF v_estado = 'baneado' THEN
    RETURN QUERY SELECT 
      false, 
      'Tu cuenta ha sido suspendida. Contactate con soporte.',
      'baneado'::TEXT;
    RETURN;
  END IF;
  
  -- Si está activo, permitir acceso
  RETURN QUERY SELECT true, NULL::TEXT, 'activo'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Vista para gestión de usuarios desde admin
CREATE VIEW vista_gestion_usuarios AS
SELECT 
  p.id,
  p.nombre,
  p.email,
  p.rol,
  p.estado_cuenta,
  p.verificado,
  p.fecha_verificacion,
  p.motivo_baneo,
  p.fecha_baneo,
  p.creado_at,
  admin_email.email as baneado_por_email,
  CASE 
    WHEN p.estado_cuenta = 'baneado' THEN true
    ELSE false
  END as esta_baneado,
  CASE 
    WHEN p.verificado = true AND p.rol = 'capitan' THEN true
    ELSE false
  END as es_capitan_verificado
FROM perfiles p
LEFT JOIN auth.users admin_email ON p.baneado_por = admin_email.id
ORDER BY p.creado_at DESC;

-- Vista para logs de auditoría
CREATE VIEW vista_logs_admin_detalle AS
SELECT 
  la.id,
  la.tipo_accion,
  la.detalles,
  la.creado_at,
  la.ip_address,
  la.user_agent,
  admin.email as admin_email,
  admin.raw_user_meta_data->>'nombre' as admin_nombre,
  afectado.nombre as usuario_afectado_nombre,
  afectado.email as usuario_afectado_email,
  afectado.rol as usuario_afectado_rol
FROM logs_admin la
JOIN auth.users admin ON la.admin_id = admin.id
LEFT JOIN perfiles afectado ON la.usuario_afectado_id = afectado.id
ORDER BY la.creado_at DESC;

-- Función para obtener estadísticas de seguridad
CREATE OR REPLACE FUNCTION obtener_estadisticas_seguridad()
RETURNS TABLE (
  total_usuarios INTEGER,
  usuarios_activos INTEGER,
  usuarios_baneados INTEGER,
  capitanes_verificados INTEGER,
  capitanes_no_verificados INTEGER,
  baneos_ultimos_30_dias INTEGER,
  verificaciones_ultimos_30_dias INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM perfiles),
    (SELECT COUNT(*) FROM perfiles WHERE estado_cuenta = 'activo'),
    (SELECT COUNT(*) FROM perfiles WHERE estado_cuenta = 'baneado'),
    (SELECT COUNT(*) FROM perfiles WHERE rol = 'capitan' AND verificado = true),
    (SELECT COUNT(*) FROM perfiles WHERE rol = 'capitan' AND verificado = false),
    (SELECT COUNT(*) FROM logs_admin WHERE tipo_accion = 'baneo' AND creado_at > NOW() - INTERVAL '30 days'),
    (SELECT COUNT(*) FROM logs_admin WHERE tipo_accion = 'verificacion' AND creado_at > NOW() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql;
