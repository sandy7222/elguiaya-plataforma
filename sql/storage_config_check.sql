-- =====================================================
-- Verificación Completa de Configuración de Storage
-- =====================================================

-- 1. Verificar bucket branding existe y está configurado
DO $$
DECLARE
    bucket_name TEXT := 'branding';
    bucket_exists BOOLEAN;
    bucket_public BOOLEAN;
    bucket_size_limit BIGINT;
    bucket_mime_types TEXT[];
BEGIN
    -- Verificar si el bucket existe
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = bucket_name
    ) INTO bucket_exists;
    
    -- Verificar si es público
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = bucket_name AND public = true
    ) INTO bucket_public;
    
    -- Obtener configuración actual
    SELECT 
        file_size_limit,
        allowed_mime_types
    INTO bucket_size_limit, bucket_mime_types
    FROM storage.buckets 
    WHERE name = bucket_name;
    
    -- Mostrar resultados
    IF bucket_exists THEN
        RAISE NOTICE '✅ Bucket "%" existe', bucket_name;
        
        IF bucket_public THEN
            RAISE NOTICE '✅ Bucket "%" es PÚBLICO', bucket_name;
        ELSE
            RAISE NOTICE '❌ Bucket "%" es PRIVADO - Las imágenes no serán visibles', bucket_name;
        END IF;
        
        RAISE NOTICE '📊 Límite de tamaño: % bytes', bucket_size_limit;
        RAISE NOTICE '📋 Tipos MIME permitidos: %', ARRAY_TO_STRING(bucket_mime_types, ', ');
    ELSE
        RAISE NOTICE '❌ Bucket "%" NO EXISTE - Crear con sql/branding_config_table.sql', bucket_name;
    END IF;
END $$;

-- 2. Verificar políticas RLS configuradas
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    -- Contar políticas para storage.objects
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'storage.objects' 
    AND schemaname = 'storage';
    
    RAISE NOTICE '🔐 Políticas RLS para storage.objects: %', policy_count;
    
    -- Mostrar políticas específicas
    IF policy_count > 0 THEN
        FOR policy_record IN (
            SELECT schemaname, tablename, policyname, permissive, roles, cmd
            FROM pg_policies 
            WHERE tablename = 'storage.objects' 
            AND schemaname = 'storage'
            ORDER BY policyname
        ) LOOP
            RAISE NOTICE '  📄 Política: "%" | Permisivo: % | Roles: % | Acción: %', 
                policy_record.policyname, 
                policy_record.permissive, 
                COALESCE(policy_record.roles, 'todos'), 
                policy_record.cmd;
        END LOOP;
    END IF;
END $$;

-- 3. Verificar estado actual de archivos en branding
DO $$
DECLARE
    total_files INTEGER;
    total_size BIGINT;
    recent_files INTEGER;
    avg_size BIGINT;
BEGIN
    -- Estadísticas generales
    SELECT COUNT(*) INTO total_files
    FROM storage.objects 
    WHERE bucket_id = 'branding';
    
    SELECT COALESCE(SUM(octet_length(size)), 0) INTO total_size
    FROM storage.objects 
    WHERE bucket_id = 'branding';
    
    -- Archivos recientes (últimos 7 días)
    SELECT COUNT(*) INTO recent_files
    FROM storage.objects 
    WHERE bucket_id = 'branding' 
    AND created_at >= NOW() - INTERVAL '7 days';
    
    -- Tamaño promedio
    SELECT CASE 
        WHEN total_files > 0 THEN total_size / total_files
        ELSE 0
    END INTO avg_size;
    
    RAISE NOTICE '📁 ESTADÍSTICAS DE ARCHIVOS EN BRANDING';
    RAISE NOTICE '  📄 Total archivos: %', total_files;
    RAISE NOTICE '  📊 Tamaño total: % MB', ROUND(total_size / (1024.0 * 1024.0), 2);
    RAISE NOTICE '  📈 Archivos recientes (7 días): %', recent_files;
    RAISE NOTICE '  📏 Tamaño promedio: % KB', ROUND(avg_size / 1024.0, 2);
    
    -- Mostrar archivos recientes si existen
    IF recent_files > 0 THEN
        RAISE NOTICE '📋 ARCHIVOS RECIENTES:';
        FOR file_record IN (
            SELECT name, created_at, (octet_length(size) / 1024.0)::numeric as size_kb
            FROM storage.objects 
            WHERE bucket_id = 'branding' 
            AND created_at >= NOW() - INTERVAL '7 days'
            ORDER BY created_at DESC
            LIMIT 5
        ) LOOP
            RAISE NOTICE '  📸 % | % KB | %', 
                file_record.name, 
                file_record.size_kb, 
                file_record.created_at;
        END LOOP;
    END IF;
END $$;

-- 4. Verificar configuración de autenticación
DO $$
DECLARE
    user_count INTEGER;
    anon_count INTEGER;
BEGIN
    -- Verificar usuarios autenticados vs anónimos
    SELECT COUNT(*) INTO user_count
    FROM auth.users 
    WHERE email IS NOT NULL 
    AND last_sign_in_at >= NOW() - INTERVAL '1 day';
    
    SELECT COUNT(*) INTO anon_count
    FROM auth.users 
    WHERE email IS NULL;
    
    RAISE NOTICE '🔐 ESTADO DE AUTENTICACIÓN';
    RAISE NOTICE '  👥 Usuarios activos (24h): %', user_count;
    RAISE NOTICE '  👤 Sesiones anónimas: %', anon_count;
    
    -- Verificar configuración JWT
    SELECT 
        jwt_secret, 
        issuer,
        expires_in
    FROM auth.config 
    WHERE key = 'jwt';
END $$;

-- 5. Recomendaciones automáticas
DO $$
BEGIN
    RAISE NOTICE '🎯 RECOMENDACIONES AUTOMÁTICAS';
    RAISE NOTICE '';
    RAISE NOTICE '1. Si el bucket branding no existe:';
    RAISE NOTICE '   → Ejecutar: sql/branding_config_table.sql';
    RAISE NOTICE '';
    RAISE NOTICE '2. Si hay problemas de permisos:';
    RAISE NOTICE '   → Ejecutar: sql/storage_branding_permissions.sql';
    RAISE NOTICE '';
    RAISE NOTICE '3. Si las imágenes no cargan:';
    RAISE NOTICE '   → Verificar logs de BrandingService';
    RAISE NOTICE '   → Revisar políticas RLS en Supabase';
    RAISE NOTICE '';
    RAISE NOTICE '4. Para diagnóstico completo:';
    RAISE NOTICE '   → Ejecutar: sql/storage_diagnostic.sql';
END $$;
