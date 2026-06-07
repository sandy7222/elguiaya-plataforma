-- =====================================================
-- Script de Diagnóstico para Storage y Buckets
-- =====================================================

-- Verificar buckets existentes
SELECT 
    name, 
    public, 
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets 
ORDER BY created_at;

-- Verificar políticas de storage existentes
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
ORDER BY schemaname, tablename, policyname;

-- Verificar archivos en bucket branding (últimos 10)
SELECT 
    name,
    bucket_id,
    created_at,
    updated_at,
    metadata,
    (octet_length(size) / 1024.0)::numeric as size_kb,
    (octet_length(size) / (1024.0 * 1024.0))::numeric as size_mb
FROM storage.objects 
WHERE bucket_id = 'branding' 
ORDER BY created_at DESC 
LIMIT 10;

-- Verificar configuración de RLS en storage
SELECT 
    nspname,
    relname,
    relrowsecurity,
    relforcerls
FROM pg_class 
WHERE relname IN ('storage.objects', 'storage.buckets');

-- Contar archivos por tipo en branding
SELECT 
    CASE 
        WHEN name LIKE '%.jpg' OR name LIKE '%.jpeg' THEN 'JPEG'
        WHEN name LIKE '%.png' THEN 'PNG'
        WHEN name LIKE '%.gif' THEN 'GIF'
        WHEN name LIKE '%.webp' THEN 'WebP'
        WHEN name LIKE '%.svg' THEN 'SVG'
        ELSE 'OTRO'
    END as file_type,
    COUNT(*) as count,
    SUM(octet_length(size)) as total_size_bytes,
    (SUM(octet_length(size)) / (1024.0 * 1024.0))::numeric as total_size_mb
FROM storage.objects 
WHERE bucket_id = 'branding'
GROUP BY 
    CASE 
        WHEN name LIKE '%.jpg' OR name LIKE '%.jpeg' THEN 'JPEG'
        WHEN name LIKE '%.png' THEN 'PNG'
        WHEN name LIKE '%.gif' THEN 'GIF'
        WHEN name LIKE '%.webp' THEN 'WebP'
        WHEN name LIKE '%.svg' THEN 'SVG'
        ELSE 'OTRO'
    END
ORDER BY count DESC;

-- Verificar permisos de usuario actual
SELECT 
    current_user,
    current_email,
    is_authenticated,
    user_role,
    session_valid
FROM (
    SELECT 
        auth.uid() as current_user,
        auth.email() as current_email,
        auth.role() as is_authenticated,
        COALESCE(auth.jwt() ->> 'role', 'anon') as user_role,
        CASE 
            WHEN auth.jwt() IS NOT NULL THEN 'invalid'
            WHEN auth.jwt() ->> 'exp' < EXTRACT(EPOCH FROM NOW()) THEN 'expired'
            ELSE 'valid'
        END as session_valid
) user_info;

-- Verificar si el bucket branding existe y está público
DO $$
DECLARE
    bucket_exists BOOLEAN;
    bucket_public BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = 'branding'
    ) INTO bucket_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = 'branding' AND public = true
    ) INTO bucket_public;
    
    IF bucket_exists THEN
        RAISE NOTICE 'Bucket branding existe: %', 
            CASE WHEN bucket_public THEN 'Y está PÚBLICO ✅' ELSE 'Y es PRIVADO ❌' END;
    ELSE
        RAISE NOTICE 'Bucket branding NO existe ❌';
    END IF;
END $$;

-- Recomendaciones de configuración
SELECT 
    'DIAGNÓSTICO COMPLETADO' as status,
    'Revisar logs de la app para errores específicos' as recomendacion_1,
    'Verificar políticas RLS en Supabase > Storage > Policies' as recomendacion_2,
    'Ejecutar sql/storage_permissions.sql si hay problemas de roles' as recomendacion_3,
    'Probar subida con diferentes tipos de archivo y tamaños' as recomendacion_4;
