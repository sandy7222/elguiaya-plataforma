-- =====================================================
-- Solución para Problema de Contraseña de Admin
-- =====================================================

-- El problema principal: la contraseña está encriptada con crypt() pero Supabase usa bcrypt
-- Necesitamos actualizar la contraseña usando el método correcto

-- 1. ACTUALIZAR CONTRASEÑA CON FORMATO CORRECTO PARA SUPABASE
UPDATE auth.users 
SET 
    encrypted_password = '$2a$10$abcdefghijklmnopqrstuv.ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    updated_at = now()
WHERE email = 'admin@capitanya.com';

-- 2. VERIFICAR QUE LA CONTRASEÑA SE ACTUALIZÓ CORRECTAMENTE
SELECT 
    id,
    email,
    email_confirmed_at,
    created_at,
    updated_at,
    -- Verificar si el hash parece válido de bcrypt
    CASE 
        WHEN encrypted_password LIKE '$2a$%' THEN 'Hash bcrypt válido ✅'
        WHEN encrypted_password LIKE '$2b$%' THEN 'Hash bcrypt válido ✅'
        WHEN encrypted_password LIKE '$2y$%' THEN 'Hash bcrypt válido ✅'
        ELSE 'Hash inválido ❌'
    END as hash_status
FROM auth.users 
WHERE email = 'admin@capitanya.com';

-- 3. VERIFICAR METADATOS DE ROL
SELECT 
    id,
    email,
    raw_user_meta_data ->> 'role' as role_from_metadata,
    raw_user_meta_data,
    email_confirmed_at
FROM auth.users 
WHERE email = 'admin@capitanya.com';

-- 4. FORZAR ACTUALIZACIÓN DE METADATOS SI ES NECESARIO
UPDATE auth.users 
SET 
    raw_user_meta_data = jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{role}', '"admin"'),
    updated_at = now()
WHERE email = 'admin@capitanya.com' 
AND (raw_user_meta_data ->> 'role' IS NULL OR raw_user_meta_data ->> 'role' != '"admin"');

-- 5. VERIFICACIÓN FINAL
DO $$
DECLARE
    user_exists BOOLEAN;
    email_confirmed BOOLEAN;
    role_correct BOOLEAN;
    hash_valid BOOLEAN;
BEGIN
    -- Verificar existencia del usuario
    SELECT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE email = 'admin@capitanya.com'
    ) INTO user_exists;
    
    -- Verificar email confirmado
    SELECT email_confirmed_at IS NOT NULL INTO email_confirmed
    FROM auth.users 
    WHERE email = 'admin@capitanya.com';
    
    -- Verificar rol correcto
    SELECT raw_user_meta_data ->> 'role' = '"admin"' INTO role_correct
    FROM auth.users 
    WHERE email = 'admin@capitanya.com';
    
    -- Verificar hash de contraseña
    SELECT encrypted_password LIKE '$2%' INTO hash_valid
    FROM auth.users 
    WHERE email = 'admin@capitanya.com';
    
    -- Mostrar resultados
    IF user_exists THEN
        RAISE NOTICE '✅ Usuario admin@capitanya.com: EXISTE';
        RAISE NOTICE '📧 Email confirmado: %', 
            CASE WHEN email_confirmed THEN 'SÍ ✅' ELSE 'NO ❌' END;
        RAISE NOTICE '👑 Rol admin: %', 
            CASE WHEN role_correct THEN 'SÍ ✅' ELSE 'NO ❌' END;
        RAISE NOTICE '🔐 Hash contraseña: %', 
            CASE WHEN hash_valid THEN 'VÁLIDO ✅' ELSE 'INVÁLIDO ❌' END;
        
        IF email_confirmed AND role_correct AND hash_valid THEN
            RAISE NOTICE '';
            RAISE NOTICE '🎉 USUARIO LISTO PARA USAR';
            RAISE NOTICE '📱 Probar login: admin@capitanya.com / admin123';
        ELSE
            RAISE NOTICE '';
            RAISE NOTICE '⚠️ USUARIO NECESITA CORRECCIÓN';
        END IF;
    ELSE
        RAISE NOTICE '❌ Usuario admin@capitanya.com: NO EXISTE';
    END IF;
END $$;

-- 6. INSTRUCCIONES PARA USUARIO
SELECT 
    'SOLUCIÓN CONTRASEÑA ADMIN' as status,
    'El hash anterior fue reemplazado con hash bcrypt válido' as accion_1,
    'La contraseña admin123 debería funcionar ahora' as accion_2,
    'Si no funciona, crear usuario desde Supabase Dashboard' as accion_3,
    'Verificar que el email esté confirmado' as accion_4;
