-- =====================================================
-- Solución para Error HTTP 400 en Carga de Imágenes
-- =====================================================

-- El problema: Intenta acceder a un archivo que no existe o está mal configurado
-- URL: https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg

-- 1. VERIFICAR SI EL ARCHIVO EXISTE EN EL BUCKET
SELECT 
    name,
    bucket_id,
    created_at,
    updated_at,
    (octet_length(size) / 1024.0)::numeric as size_kb,
    (octet_length(size) / (1024.0 * 1024.0))::numeric as size_mb
FROM storage.objects 
WHERE bucket_id = 'branding' 
AND name = 'portada_inicio.jpg'
ORDER BY created_at DESC;

-- 2. VERIFICAR TODOS LOS ARCHIVOS EN EL BUCKET BRANDING
SELECT 
    name,
    bucket_id,
    created_at,
    (octet_length(size) / 1024.0)::numeric as size_kb,
    CASE 
        WHEN name LIKE '%portada%' THEN 'PORTADA'
        WHEN name LIKE '%logo%' THEN 'LOGO'
        WHEN name LIKE '%favicon%' THEN 'FAVICON'
        WHEN name LIKE '%background%' THEN 'BACKGROUND'
        ELSE 'OTRO'
    END as file_type
FROM storage.objects 
WHERE bucket_id = 'branding'
ORDER BY created_at DESC;

-- 3. VERIFICAR POLÍTICAS DE ACCESO AL STORAGE
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('storage.objects', 'storage.buckets')
AND schemaname = 'storage'
ORDER BY policyname;

-- 4. VERIFICAR SI EL BUCKET BRANDING ES PÚBLICO
SELECT 
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at,
    owner_id
FROM storage.buckets 
WHERE name = 'branding';

-- 5. CREAR ARCHIVO POR DEFECTO SI NO EXISTE
DO $$
DECLARE
    file_exists BOOLEAN;
    bucket_exists BOOLEAN;
    bucket_public BOOLEAN;
BEGIN
    -- Verificar si el bucket existe
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = 'branding'
    ) INTO bucket_exists;
    
    -- Verificar si el bucket es público
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = 'branding' AND public = true
    ) INTO bucket_public;
    
    -- Verificar si el archivo específico existe
    SELECT EXISTS (
        SELECT 1 FROM storage.objects 
        WHERE bucket_id = 'branding' 
        AND name = 'portada_inicio.jpg'
    ) INTO file_exists;
    
    -- Mostrar estado actual
    RAISE NOTICE '📊 ESTADO DEL STORAGE BRANDING:';
    RAISE NOTICE '  Bucket existe: %', CASE WHEN bucket_exists THEN 'SÍ ✅' ELSE 'NO ❌' END;
    RAISE NOTICE '  Bucket es público: %', CASE WHEN bucket_public THEN 'SÍ ✅' ELSE 'NO ❌' END;
    RAISE NOTICE '  Archivo portada_inicio.jpg existe: %', CASE WHEN file_exists THEN 'SÍ ✅' ELSE 'NO ❌' END;
    
    -- Si el bucket no existe o no es público, crear/configurar
    IF NOT bucket_exists THEN
        RAISE NOTICE '🔧 Creando bucket branding...';
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, owner_id)
        VALUES (
            gen_random_uuid(),
            'branding',
            true,
            52428800, -- 50MB
            ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'],
            auth.uid()
        );
    ELSIF NOT bucket_public THEN
        RAISE NOTICE '🔧 Haciendo bucket branding público...';
        UPDATE storage.buckets 
        SET public = true 
        WHERE name = 'branding';
    END IF;
    
    -- Si el archivo no existe, mostrar advertencia
    IF NOT file_exists THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ ARCHIVO portada_inicio.jpg NO EXISTE';
        RAISE NOTICE '';
        RAISE NOTICE '🎯 SOLUCIONES:';
        RAISE NOTICE '  1. Subir imagen por defecto al bucket branding';
        RAISE NOTICE '  2. Usar URL por defecto en la app';
        RAISE NOTICE '  3. Verificar políticas RLS del storage';
        RAISE NOTICE '';
        RAISE NOTICE '📋 ARCHIVOS ACTUALES EN BRANDING:';
        
        -- Mostrar archivos existentes
        FOR file_record IN (
            SELECT name, created_at, (octet_length(size) / 1024.0)::numeric as size_kb
            FROM storage.objects 
            WHERE bucket_id = 'branding'
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

-- 6. VERIFICAR URL PÚBLICA CORRECTA
DO $$
DECLARE
    public_url TEXT;
BEGIN
    -- Construir URL pública correcta
    SELECT get_public_url('branding/portada_inicio.jpg') INTO public_url;
    
    RAISE NOTICE '🔗 URL PÚBLICA ESPERADA:';
    RAISE NOTICE '  %', public_url;
    
    -- Verificar si la URL en la app coincide
    IF public_url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg' THEN
        RAISE NOTICE '✅ URL en la app es CORRECTA';
    ELSE
        RAISE NOTICE '❌ URL en la app es INCORRECTA';
        RAISE NOTICE '  URL esperada: %', public_url;
    END IF;
END $$;

-- 7. RECOMENDACIONES FINALES
SELECT 
    'DIAGNÓSTICO DE STORAGE COMPLETADO' as status,
    'Verificar si portada_inicio.jpg existe en el bucket' as paso_1,
    'Confirmar que bucket branding sea público' as paso_2,
    'Revisar políticas RLS para acceso público' as paso_3,
    'Probar URL pública con browser directamente' as paso_4,
    'Si no existe, subir imagen por defecto al bucket' as paso_5;
