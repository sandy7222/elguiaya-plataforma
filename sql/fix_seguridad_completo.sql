-- ====================================================================
-- SCRIPT DE BASE DE DATOS PARA EL MÓDULO DE SEGURIDAD Y AUDITORÍA
-- Ejecutar este archivo completo en el SQL Editor de tu consola Supabase
-- ====================================================================

-- 1. Agregar columnas adicionales a la tabla profiles para control de estado
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS estado_cuenta TEXT DEFAULT 'activo';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS motivo_baneo TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fecha_baneo TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS baneado_por_email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fecha_verificacion TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS esta_baneado BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS es_capitan_verificado BOOLEAN DEFAULT FALSE;

-- 2. Crear tabla logs_admin si no existe
CREATE TABLE IF NOT EXISTS public.logs_admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_accion VARCHAR(50) NOT NULL,
    detalles TEXT,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT,
    admin_id UUID,
    admin_email VARCHAR(255),
    admin_nombre VARCHAR(255),
    usuario_afectado_nombre VARCHAR(255),
    usuario_afectado_email VARCHAR(255),
    usuario_afectado_rol VARCHAR(50)
);

-- Índices de optimización para logs_admin
CREATE INDEX IF NOT EXISTS idx_logs_admin_tipo_accion ON public.logs_admin(tipo_accion);
CREATE INDEX IF NOT EXISTS idx_logs_admin_creado_at ON public.logs_admin(creado_at);

-- RLS para logs_admin
ALTER TABLE public.logs_admin ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins ver todos los logs_admin" ON public.logs_admin;
CREATE POLICY "Admins ver todos los logs_admin"
ON public.logs_admin FOR SELECT
USING (true); -- Permitimos ver temporalmente a usuarios autenticados con rol administrativo

DROP POLICY IF EXISTS "Permitir inserts a logs_admin" ON public.logs_admin;
CREATE POLICY "Permitir inserts a logs_admin"
ON public.logs_admin FOR INSERT
WITH CHECK (true);

-- 3. Funciones RPC de Moderación

-- Eliminar funciones existentes primero para evitar conflictos de firmas y tipos de retorno
DROP FUNCTION IF EXISTS public.banear_usuario(UUID, TEXT);
DROP FUNCTION IF EXISTS public.desbanear_usuario(UUID);
DROP FUNCTION IF EXISTS public.verificar_capitan(UUID);
DROP FUNCTION IF EXISTS public.desverificar_capitan(UUID, TEXT);
DROP FUNCTION IF EXISTS public.verificar_estado_login(TEXT);
DROP FUNCTION IF EXISTS public.obtener_estadisticas_seguridad();

-- A. Banear Usuario
CREATE OR REPLACE FUNCTION public.banear_usuario(
    p_usuario_id UUID,
    p_motivo TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_email TEXT;
    v_admin_id UUID;
    v_usuario_email TEXT;
    v_usuario_nombre TEXT;
    v_usuario_rol TEXT;
BEGIN
    v_admin_id := auth.uid();
    SELECT email INTO v_admin_email FROM auth.users WHERE id = v_admin_id;
    
    SELECT email, nombre, rol INTO v_usuario_email, v_usuario_nombre, v_usuario_rol
    FROM public.profiles
    WHERE user_id = p_usuario_id;
    
    UPDATE public.profiles
    SET 
        estado_cuenta = 'baneado',
        estado = 'baneado',
        motivo_baneo = p_motivo,
        fecha_baneo = NOW(),
        esta_baneado = TRUE,
        baneado_por_email = COALESCE(v_admin_email, 'admin@capitanya.com'),
        updated_at = NOW()
    WHERE user_id = p_usuario_id;
    
    INSERT INTO public.logs_admin (
        tipo_accion,
        detalles,
        admin_id,
        admin_email,
        admin_nombre,
        usuario_afectado_nombre,
        usuario_afectado_email,
        usuario_afectado_rol
    ) VALUES (
        'baneo',
        'Usuario baneado por motivo: ' || COALESCE(p_motivo, 'Sin motivo especificado'),
        v_admin_id,
        COALESCE(v_admin_email, 'admin@capitanya.com'),
        'Administrador',
        COALESCE(v_usuario_nombre, 'Usuario'),
        COALESCE(v_usuario_email, '-'),
        COALESCE(v_usuario_rol, '-')
    );
    
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- B. Desbanear Usuario
CREATE OR REPLACE FUNCTION public.desbanear_usuario(
    p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_email TEXT;
    v_admin_id UUID;
    v_usuario_email TEXT;
    v_usuario_nombre TEXT;
    v_usuario_rol TEXT;
BEGIN
    v_admin_id := auth.uid();
    SELECT email INTO v_admin_email FROM auth.users WHERE id = v_admin_id;
    
    SELECT email, nombre, rol INTO v_usuario_email, v_usuario_nombre, v_usuario_rol
    FROM public.profiles
    WHERE user_id = p_usuario_id;
    
    UPDATE public.profiles
    SET 
        estado_cuenta = 'activo',
        estado = 'activo',
        motivo_baneo = NULL,
        fecha_baneo = NULL,
        esta_baneado = FALSE,
        baneado_por_email = NULL,
        updated_at = NOW()
    WHERE user_id = p_usuario_id;
    
    INSERT INTO public.logs_admin (
        tipo_accion,
        detalles,
        admin_id,
        admin_email,
        admin_nombre,
        usuario_afectado_nombre,
        usuario_afectado_email,
        usuario_afectado_rol
    ) VALUES (
        'desbaneo',
        'Baneo removido de la cuenta del usuario',
        v_admin_id,
        COALESCE(v_admin_email, 'admin@capitanya.com'),
        'Administrador',
        COALESCE(v_usuario_nombre, 'Usuario'),
        COALESCE(v_usuario_email, '-'),
        COALESCE(v_usuario_rol, '-')
    );
    
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- C. Verificar Capitán
CREATE OR REPLACE FUNCTION public.verificar_capitan(
    p_capitan_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_email TEXT;
    v_admin_id UUID;
    v_usuario_email TEXT;
    v_usuario_nombre TEXT;
BEGIN
    v_admin_id := auth.uid();
    SELECT email INTO v_admin_email FROM auth.users WHERE id = v_admin_id;
    
    SELECT email, nombre INTO v_usuario_email, v_usuario_nombre
    FROM public.profiles
    WHERE user_id = p_capitan_id;
    
    UPDATE public.profiles
    SET 
        verificado = TRUE,
        es_capitan_verificado = TRUE,
        fecha_verificacion = NOW(),
        updated_at = NOW()
    WHERE user_id = p_capitan_id;
    
    INSERT INTO public.logs_admin (
        tipo_accion,
        detalles,
        admin_id,
        admin_email,
        admin_nombre,
        usuario_afectado_nombre,
        usuario_afectado_email,
        usuario_afectado_rol
    ) VALUES (
        'verificacion',
        'Capitán verificado exitosamente',
        v_admin_id,
        COALESCE(v_admin_email, 'admin@capitanya.com'),
        'Administrador',
        COALESCE(v_usuario_nombre, 'Usuario'),
        COALESCE(v_usuario_email, '-'),
        'capitan'
    );
    
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. Desverificar Capitán
CREATE OR REPLACE FUNCTION public.desverificar_capitan(
    p_capitan_id UUID,
    p_motivo TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_email TEXT;
    v_admin_id UUID;
    v_usuario_email TEXT;
    v_usuario_nombre TEXT;
BEGIN
    v_admin_id := auth.uid();
    SELECT email INTO v_admin_email FROM auth.users WHERE id = v_admin_id;
    
    SELECT email, nombre INTO v_usuario_email, v_usuario_nombre
    FROM public.profiles
    WHERE user_id = p_capitan_id;
    
    UPDATE public.profiles
    SET 
        verificado = FALSE,
        es_capitan_verificado = FALSE,
        fecha_verificacion = NULL,
        updated_at = NOW()
    WHERE user_id = p_capitan_id;
    
    INSERT INTO public.logs_admin (
        tipo_accion,
        detalles,
        admin_id,
        admin_email,
        admin_nombre,
        usuario_afectado_nombre,
        usuario_afectado_email,
        usuario_afectado_rol
    ) VALUES (
        'desverificacion',
        'Verificación del capitán removida. Motivo: ' || COALESCE(p_motivo, 'Sin motivo especificado'),
        v_admin_id,
        COALESCE(v_admin_email, 'admin@capitanya.com'),
        'Administrador',
        COALESCE(v_usuario_nombre, 'Usuario'),
        COALESCE(v_usuario_email, '-'),
        'capitan'
    );
    
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. Verificar Estado Login
CREATE OR REPLACE FUNCTION public.verificar_estado_login(
    p_email TEXT
)
RETURNS TABLE (
    permitido BOOLEAN,
    mensaje TEXT,
    estado_cuenta TEXT,
    rol TEXT,
    activo BOOLEAN
) AS $$
DECLARE
    v_estado_cuenta TEXT;
    v_rol TEXT;
    v_motivo_baneo TEXT;
BEGIN
    SELECT p.estado_cuenta, p.rol, p.motivo_baneo
    INTO v_estado_cuenta, v_rol, v_motivo_baneo
    FROM public.profiles p
    WHERE p.email = p_email
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT TRUE, NULL::TEXT, 'no_existe'::TEXT, NULL::TEXT, TRUE;
        RETURN;
    END IF;
    
    IF v_estado_cuenta = 'baneado' THEN
        RETURN QUERY SELECT FALSE, 'Tu cuenta ha sido suspendida. Motivo: ' || COALESCE(v_motivo_baneo, 'Violación de los términos de servicio'), 'baneado'::TEXT, v_rol, FALSE;
    ELSE
        RETURN QUERY SELECT TRUE, NULL::TEXT, v_estado_cuenta, v_rol, TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. Obtener Estadísticas de Seguridad
CREATE OR REPLACE FUNCTION public.obtener_estadisticas_seguridad()
RETURNS TABLE (
    total_usuarios INTEGER,
    usuarios_activos INTEGER,
    usuarios_baneados INTEGER,
    capitanes_verificados INTEGER,
    capitanes_no_verificados INTEGER,
    baneos_ultimos_30_dias INTEGER,
    verificaciones_ultimos_30_dias INTEGER
) AS $$
DECLARE
    v_total_usuarios INTEGER;
    v_usuarios_activos INTEGER;
    v_usuarios_baneados INTEGER;
    v_capitanes_verificados INTEGER;
    v_capitanes_no_verificados INTEGER;
    v_baneos_30 INTEGER;
    v_verif_30 INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO v_total_usuarios FROM public.profiles;
    
    SELECT COUNT(*)::INTEGER INTO v_usuarios_activos FROM public.profiles WHERE estado_cuenta = 'activo';
    
    SELECT COUNT(*)::INTEGER INTO v_usuarios_baneados FROM public.profiles WHERE estado_cuenta = 'baneado';
    
    SELECT COUNT(*)::INTEGER INTO v_capitanes_verificados FROM public.profiles WHERE es_capitan = TRUE AND verificado = TRUE;
    
    SELECT COUNT(*)::INTEGER INTO v_capitanes_no_verificados FROM public.profiles WHERE es_capitan = TRUE AND verificado = FALSE;
    
    SELECT COUNT(*)::INTEGER INTO v_baneos_30 FROM public.logs_admin WHERE tipo_accion = 'baneo' AND creado_at >= NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*)::INTEGER INTO v_verif_30 FROM public.logs_admin WHERE tipo_accion = 'verificacion' AND creado_at >= NOW() - INTERVAL '30 days';
    
    RETURN QUERY SELECT 
        v_total_usuarios, 
        v_usuarios_activos, 
        v_usuarios_baneados, 
        v_capitanes_verificados, 
        v_capitanes_no_verificados, 
        v_baneos_30, 
        v_verif_30;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Permisos
GRANT ALL ON public.logs_admin TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.banear_usuario TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.desbanear_usuario TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verificar_capitan TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.desverificar_capitan TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verificar_estado_login TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.obtener_estadisticas_seguridad TO anon, authenticated, service_role;

-- Forzar recarga del Schema Cache
NOTIFY pgrst, 'reload schema';
