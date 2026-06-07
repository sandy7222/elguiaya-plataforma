-- =====================================================
-- Verificación de Usuario Administrador
-- =====================================================

-- Verificar si el usuario admin@capitanya.com existe
SELECT 
    id,
    email,
    created_at,
    last_sign_in_at,
    email_confirmed_at,
    phone,
    phone_confirmed_at,
    raw_user_meta_data,
    is_sso_user,
    app_metadata
FROM auth.users 
WHERE email = 'admin@capitanya.com';

-- Verificar si hay usuarios con rol de administrador
SELECT 
    id,
    email,
    raw_user_meta_data,
    raw_user_meta_data ->> 'role' as user_role,
    raw_user_meta_data ->> 'rol' as user_rol,
    created_at,
    last_sign_in_at
FROM auth.users 
WHERE 
    raw_user_meta_data ->> 'role' = 'admin' OR
    raw_user_meta_data ->> 'rol' = 'admin' OR
    email LIKE '%admin%'
ORDER BY created_at DESC;

-- Verificar configuración de autenticación
SELECT 
    jwt_secret,
    issuer,
    expires_in,
    refresh_token_rotation_enabled,
    security_update_password_required
FROM auth.config 
WHERE key = 'jwt';

-- Verificar si hay usuarios en la tabla usuarios (si existe)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'usuarios'
    ) THEN
        -- Buscar usuarios con rol admin
        FOR user_record IN (
            SELECT 
                id,
                email,
                rol,
                activo,
                created_at,
                updated_at
            FROM usuarios 
            WHERE rol = 'admin' OR email LIKE '%admin%'
            ORDER BY created_at DESC
            LIMIT 5
        ) LOOP
            RAISE NOTICE '👤 Usuario en tabla usuarios: ID=% | Email=% | Rol=% | Activo=%', 
                user_record.id, 
                user_record.email, 
                user_record.rol, 
                user_record.activo;
        END LOOP;
        
        -- Contar usuarios totales
        DECLARE
            total_users INTEGER;
            admin_users INTEGER;
        BEGIN
            SELECT COUNT(*) INTO total_users FROM usuarios;
            SELECT COUNT(*) INTO admin_users FROM usuarios WHERE rol = 'admin';
            
            RAISE NOTICE '📊 Estadísticas usuarios:';
            RAISE NOTICE '  Total usuarios: %', total_users;
            RAISE NOTICE '  Administradores: %', admin_users;
        END;
    ELSE
        RAISE NOTICE 'ℹ️ Tabla usuarios no existe - usando auth.users';
    END IF;
END $$;

-- Verificar si el email admin@capitanya.com está confirmado
DO $$
DECLARE
    user_exists BOOLEAN;
    email_confirmed BOOLEAN;
    last_sign_in TIMESTAMP;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE email = 'admin@capitanya.com'
    ) INTO user_exists;
    
    SELECT email_confirmed_at IS NOT NULL INTO email_confirmed
    FROM auth.users 
    WHERE email = 'admin@capitanya.com';
    
    SELECT last_sign_in_at INTO last_sign_in
    FROM auth.users 
    WHERE email = 'admin@capitanya.com';
    
    IF user_exists THEN
        RAISE NOTICE '👤 Usuario admin@capitanya.com:';
        RAISE NOTICE '  ✅ Existe: SÍ';
        RAISE NOTICE '  📧 Email confirmado: %', 
            CASE WHEN email_confirmed THEN 'SÍ ✅' ELSE 'NO ❌' END;
        RAISE NOTICE '  🕐 Último login: %', 
            COALESCE(last_sign_in::TEXT, 'Nunca');
    ELSE
        RAISE NOTICE '❌ Usuario admin@capitanya.com NO EXISTE';
        RAISE NOTICE '';
        RAISE NOTICE '🎯 SOLUCIONES:';
        RAISE NOTICE '  1. Crear usuario manualmente en Supabase Auth';
        RAISE NOTICE '  2. Verificar typo en email (admin@capitanya.com)';
        RAISE NOTICE '  3. Revisar configuración de auth';
    END IF;
END $$;

-- Recomendaciones para crear usuario admin
SELECT 
    'DIAGNÓSTICO DE AUTENTICACIÓN' as status,
    'Verificar si admin@capitanya.com existe en auth.users' as paso_1,
    'Confirmar email del usuario administrador' as paso_2,
    'Verificar metadata con rol=admin' as paso_3,
    'Probar login con diferentes credenciales' as paso_4,
    'Revisar logs de errores específicos' as paso_5;
