-- =====================================================
-- Diagnóstico Completo de Subidas de Imágenes
-- =====================================================

-- 1. VERIFICAR TODOS LOS BUCKETS DEL STORAGE
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at,
    owner_id
FROM storage.buckets 
ORDER BY created_at;

-- 2. VERIFICAR ARCHIVOS POR BUCKET Y TIPO
DO $$
DECLARE
    bucket_record RECORD;
    file_count INTEGER;
    total_size BIGINT;
BEGIN
    RAISE NOTICE '📊 ANÁLISIS DE BUCKETS Y ARCHIVOS:';
    RAISE NOTICE '';
    
    FOR bucket_record IN 
        SELECT id, name FROM storage.buckets ORDER BY name
    LOOP
        -- Contar archivos en este bucket
        SELECT COUNT(*), COALESCE(SUM(octet_length(size)), 0) 
        INTO file_count, total_size
        FROM storage.objects 
        WHERE bucket_id = bucket_record.name;
        
        RAISE NOTICE '📁 Bucket: %', bucket_record.name;
        RAISE NOTICE '   📄 Archivos: %', file_count;
        RAISE NOTICE '   📊 Tamaño total: % MB', ROUND(total_size / (1024.0 * 1024.0), 2);
        
        -- Mostrar archivos recientes si hay
        IF file_count > 0 THEN
            RAISE NOTICE '   📋 Archivos recientes:';
            FOR file_record IN 
                SELECT name, created_at, (octet_length(size) / 1024.0)::numeric as size_kb
                FROM storage.objects 
                WHERE bucket_id = bucket_record.name
                ORDER BY created_at DESC 
                LIMIT 3
            LOOP
                RAISE NOTICE '     📸 % | % KB | %', 
                    file_record.name, 
                    file_record.size_kb, 
                    file_record.created_at;
            END LOOP;
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
END $$;

-- 3. VERIFICAR POLÍTICAS DE ACCESO POR BUCKET
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename LIKE 'storage.%'
ORDER BY schemaname, tablename, policyname;

-- 4. VERIFICAR ERRORES COMUNES EN CONFIGURACIÓN
DO $$
DECLARE
    branding_exists BOOLEAN;
    branding_public BOOLEAN;
    branding_files INTEGER;
    policies_count INTEGER;
    
    fotos_perfil_exists BOOLEAN;
    documentacion_exists BOOLEAN;
    branding_images_exists BOOLEAN;
    administracion_exists BOOLEAN;
BEGIN
    -- Verificar buckets principales
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'branding'
    ) INTO branding_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'branding' AND public = true
    ) INTO branding_public;
    
    SELECT COUNT(*) INTO branding_files
    FROM storage.objects WHERE bucket_id = 'branding';
    
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies WHERE tablename LIKE 'storage.%';
    
    -- Verificar otros buckets importantes
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'fotos_perfil'
    ) INTO fotos_perfil_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'documentacion_privada'
    ) INTO documentacion_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'branding-images'
    ) INTO branding_images_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE name = 'administracion_archivos'
    ) INTO administracion_exists;
    
    -- Reporte de estado
    RAISE NOTICE '🔍 DIAGNÓSTICO DE CONFIGURACIÓN:';
    RAISE NOTICE '';
    RAISE NOTICE '📁 BUCKETS PRINCIPALES:';
    RAISE NOTICE '   branding: % %', 
        CASE WHEN branding_exists THEN '✅ EXISTE' ELSE '❌ FALTA' END,
        CASE WHEN branding_public THEN '(PÚBLICO)' ELSE '(PRIVADO)' END;
    RAISE NOTICE '   fotos_perfil: %', 
        CASE WHEN fotos_perfil_exists THEN '✅ EXISTE' ELSE '❌ FALTA' END;
    RAISE NOTICE '   documentacion_privada: %', 
        CASE WHEN documentacion_exists THEN '✅ EXISTE' ELSE '❌ FALTA' END;
    RAISE NOTICE '   branding-images: %', 
        CASE WHEN branding_images_exists THEN '✅ EXISTE' ELSE '❌ FALTA' END;
    RAISE NOTICE '   administracion_archivos: %', 
        CASE WHEN administracion_exists THEN '✅ EXISTE' ELSE '❌ FALTA' END;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 ESTADÍSTICAS:';
    RAISE NOTICE '   Archivos en branding: %', branding_files;
    RAISE NOTICE '   Políticas RLS activas: %', policies_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 ANÁLISIS DE MÓDULOS DE SUBIDA:';
    
    -- Analizar cada módulo
    IF branding_exists AND branding_public THEN
        RAISE NOTICE '   ✅ BrandingService: FUNCIONAL (bucket público)';
    ELSE
        RAISE NOTICE '   ❌ BrandingService: PROBLEMAS (bucket no existe o es privado)';
    END IF;
    
    IF fotos_perfil_exists THEN
        RAISE NOTICE '   ✅ PerfilService: FUNCIONAL';
    ELSE
        RAISE NOTICE '   ❌ PerfilService: PROBLEMAS (bucket fotos_perfil no existe)';
    END IF;
    
    IF documentacion_exists THEN
        RAISE NOTICE '   ✅ DocumentaciónService: FUNCIONAL';
    ELSE
        RAISE NOTICE '   ❌ DocumentaciónService: PROBLEMAS (bucket documentacion_privada no existe)';
    END IF;
    
    IF branding_images_exists THEN
        RAISE NOTICE '   ✅ AdminCatalogo: FUNCIONAL';
    ELSE
        RAISE NOTICE '   ❌ AdminCatalogo: PROBLEMAS (bucket branding-images no existe)';
    END IF;
    
    IF administracion_exists THEN
        RAISE NOTICE '   ✅ AdminArchivos: FUNCIONAL';
    ELSE
        RAISE NOTICE '   ❌ AdminArchivos: PROBLEMAS (bucket administracion_archivos no existe)';
    END IF;
END $$;

-- 5. VERIFICAR ARCHIVOS RECIENTES (ÚLTIMAS 24 HORAS)
SELECT 
    bucket_id,
    name,
    created_at,
    (octet_length(size) / 1024.0)::numeric as size_kb,
    CASE 
        WHEN created_at >= NOW() - INTERVAL '24 hours' THEN 'HOY'
        WHEN created_at >= NOW() - INTERVAL '7 days' THEN 'ÚLTIMA SEMANA'
        WHEN created_at >= NOW() - INTERVAL '30 days' THEN 'ÚLTIMO MES'
        ELSE 'ANTIGUO'
    END as tiempo_subida
FROM storage.objects 
WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
LIMIT 20;

-- 6. RECOMENDACIONES AUTOMÁTICAS
SELECT 
    'DIAGNÓSTICO COMPLETADO' as status,
    'Verificar que todos los buckets necesarios existan' as recomendacion_1,
    'Asegurar que buckets públicos estén configurados como public=true' as recomendacion_2,
    'Revisar políticas RLS para acceso correcto' as recomendacion_3,
    'Probar subidas en cada módulo individualmente' as recomendacion_4,
    'Verificar límites de tamaño y MIME types permitidos' as recomendacion_5,
    'Monitorear logs de errores en la app' as recomendacion_6;
