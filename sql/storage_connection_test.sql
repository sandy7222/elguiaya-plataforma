-- =====================================================
-- Script de Prueba de Conexión a Buckets de Supabase
-- =====================================================

-- 1. VERIFICAR TODOS LOS BUCKETS ESPERADOS
DO $$
DECLARE
    bucket_record RECORD;
    total_buckets INTEGER := 0;
    buckets_encontrados INTEGER := 0;
    
    -- Lista de buckets que debería existir
    TYPE bucket_array IS ARRAY OF TEXT;
    expected_buckets bucket_array := ARRAY[
        'branding_images',
        'fotos_perfil',
        'documentacion_privada',
        'administracion_archivos'
    ];
BEGIN
    RAISE NOTICE '🔍 INICIANDO VERIFICACIÓN DE BUCKETS';
    RAISE NOTICE '=' || REPEAT('=', 50);
    
    -- Verificar cada bucket esperado
    FOR i IN 1..array_length(expected_buckets, 1) LOOP
        total_buckets := total_buckets + 1;
        
        SELECT EXISTS (
            SELECT 1 FROM storage.buckets 
            WHERE name = expected_buckets[i]
        ) INTO bucket_record;
        
        IF bucket_record.exists THEN
            buckets_encontrados := buckets_encontrados + 1;
            RAISE NOTICE '✅ Bucket %: EXISTE', expected_buckets[i];
            
            -- Obtener detalles del bucket
            FOR bucket_details IN (
                SELECT 
                    public,
                    file_size_limit,
                    allowed_mime_types,
                    created_at
                FROM storage.buckets 
                WHERE name = expected_buckets[i]
            ) LOOP
                RAISE NOTICE '   📊 Público: %', 
                    CASE WHEN bucket_details.public THEN 'SÍ' ELSE 'NO' END;
                RAISE NOTICE '   📏 Límite: % MB', 
                    ROUND(bucket_details.file_size_limit / (1024.0 * 1024.0), 2);
                RAISE NOTICE '   📋 MIME Types: %', 
                    COALESCE(ARRAY_TO_STRING(bucket_details.allowed_mime_types, ', '), 'Todos');
                RAISE NOTICE '   📅 Creado: %', bucket_details.created_at;
            END LOOP;
        ELSE
            RAISE NOTICE '❌ Bucket %: NO EXISTE', expected_buckets[i];
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
    
    -- Resumen
    RAISE NOTICE '📊 RESUMEN DE BUCKETS:';
    RAISE NOTICE '   📁 Encontrados: %/%', buckets_encontrados, total_buckets;
    
    IF buckets_encontrados = total_buckets THEN
        RAISE NOTICE '🎉 TODOS LOS BUCKETS ESPERADOS EXISTEN';
    ELSE
        RAISE NOTICE '⚠️ FALTAN BUCKETS POR CREAR';
    END IF;
END $$;

-- 2. VERIFICAR ARCHIVOS EN CADA BUCKET
DO $$
DECLARE
    bucket_name TEXT;
    file_count INTEGER;
    total_size BIGINT;
    file_count_total INTEGER := 0;
    total_size_all BIGINT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📁 ANALIZANDO ARCHIVOS POR BUCKET';
    RAISE NOTICE '=' || REPEAT('=', 50);
    
    FOR bucket_name IN ARRAY[
        'branding_images',
        'fotos_perfil',
        'documentacion_privada',
        'administracion_archivos'
    ] LOOP
        -- Verificar si el bucket existe antes de contar archivos
        IF EXISTS (SELECT 1 FROM storage.buckets WHERE name = bucket_name) THEN
            SELECT COUNT(*), COALESCE(SUM(octet_length(size)), 0)
            INTO file_count, total_size
            FROM storage.objects 
            WHERE bucket_id = bucket_name;
            
            file_count_total := file_count_total + file_count;
            total_size_all := total_size_all + total_size;
            
            RAISE NOTICE '📁 Bucket: %', bucket_name;
            RAISE NOTICE '   📄 Archivos: %', file_count;
            RAISE NOTICE '   📊 Tamaño: % MB', ROUND(total_size / (1024.0 * 1024.0), 2);
            
            -- Mostrar archivos recientes si hay
            IF file_count > 0 THEN
                RAISE NOTICE '   📋 Archivos recientes:';
                FOR file_record IN (
                    SELECT name, created_at, (octet_length(size) / 1024.0)::numeric as size_kb
                    FROM storage.objects 
                    WHERE bucket_id = bucket_name
                    ORDER BY created_at DESC 
                    LIMIT 3
                ) LOOP
                    RAISE NOTICE '     📸 % | % KB | %', 
                        file_record.name, 
                        file_record.size_kb, 
                        file_record.created_at;
                END LOOP;
            END IF;
            
            RAISE NOTICE '';
        ELSE
            RAISE NOTICE '❌ Bucket %: NO EXISTE - No se pueden analizar archivos', bucket_name;
            RAISE NOTICE '';
        END IF;
    END LOOP;
    
    -- Resumen total
    RAISE NOTICE '📊 RESUMEN TOTAL DE ARCHIVOS:';
    RAISE NOTICE '   📄 Total archivos: %', file_count_total;
    RAISE NOTICE '   📊 Tamaño total: % MB', ROUND(total_size_all / (1024.0 * 1024.0), 2);
END $$;

-- 3. VERIFICAR POLÍTICAS RLS POR BUCKET
DO $$
DECLARE
    policy_record RECORD;
    bucket_policy_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔐 ANALIZANDO POLÍTICAS RLS';
    RAISE NOTICE '=' || REPEAT('=', 50);
    
    -- Mostrar todas las políticas de storage
    FOR policy_record IN (
        SELECT 
            schemaname,
            tablename,
            policyname,
            permissive,
            roles,
            cmd,
            CASE 
                WHEN qual IS NOT NULL THEN 'RESTRICTED'
                ELSE 'PUBLIC'
            END as access_level
        FROM pg_policies 
        WHERE tablename LIKE 'storage.%'
        ORDER BY schemaname, tablename, policyname
    ) LOOP
        RAISE NOTICE '📋 Política: %', policy_record.policyname;
        RAISE NOTICE '   📁 Tabla: %', policy_record.tablename;
        RAISE NOTICE '   🔐 Comando: %', policy_record.cmd;
        RAISE NOTICE '   👥 Roles: %', COALESCE(policy_record.roles, 'Todos');
        RAISE NOTICE '   🚪 Acceso: %', policy_record.access_level;
        RAISE NOTICE '';
    END LOOP;
    
    -- Contar políticas por tipo
    SELECT COUNT(*) INTO bucket_policy_count
    FROM pg_policies 
    WHERE tablename LIKE 'storage.%';
    
    RAISE NOTICE '📊 Total políticas RLS de storage: %', bucket_policy_count;
    
    IF bucket_policy_count = 0 THEN
        RAISE NOTICE '⚠️ NO HAY POLÍTICAS RLS - Puede causar problemas de acceso';
    ELSE
        RAISE NOTICE '✅ Políticas RLS configuradas';
    END IF;
END $$;

-- 4. PRUEBA DE SUBIDA SIMULADA (SOLO LECTURA)
DO $$
DECLARE
    test_bucket TEXT := 'branding_images';
    test_path TEXT := 'test_connection/test_file.jpg';
    bucket_exists BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 PRUEBA DE CONEXIÓN (SIMULADA)';
    RAISE NOTICE '=' || REPEAT('=', 50);
    
    -- Verificar si el bucket principal existe
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = test_bucket AND public = true
    ) INTO bucket_exists;
    
    IF bucket_exists THEN
        RAISE NOTICE '✅ Bucket principal (%) está accesible', test_bucket;
        
        -- Generar URL de prueba
        DECLARE
            test_url TEXT;
        BEGIN
            SELECT get_public_url(test_path) INTO test_url;
            
            RAISE NOTICE '🔗 URL de prueba generada:';
            RAISE NOTICE '   %', test_url;
            RAISE NOTICE '';
            RAISE NOTICE '💡 Para probar subida real:';
            RAISE NOTICE '   1. Usar la app para subir una imagen';
            RAISE NOTICE '   2. Revisar logs en la consola';
            RAISE NOTICE '   3. Verificar que aparezca en el bucket';
        END;
    ELSE
        RAISE NOTICE '❌ Bucket principal (%) no existe o no es público', test_bucket;
        RAISE NOTICE '';
        RAISE NOTICE '🛠️ SOLUCIONES:';
        RAISE NOTICE '   1. Crear el bucket faltante';
        RAISE NOTICE '   2. Configurarlo como público';
        RAISE NOTICE '   3. Agregar políticas RLS si es necesario';
    END IF;
END $$;

-- 5. RECOMENDACIONES FINALES
SELECT 
    'DIAGNÓSTICO COMPLETADO' as status,
    'Verificar que todos los buckets existan' as paso_1,
    'Asegurar que buckets públicos estén configurados' as paso_2,
    'Revisar políticas RLS para acceso correcto' as paso_3,
    'Probar subidas reales desde la app' as paso_4,
    'Monitorear logs de errores específicos' as paso_5,
    'Verificar contentType en cada subida' as paso_6;
