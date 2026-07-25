-- ================================================================
-- FIX PERMISOS DE VIDEO Y FORMATOS PARA BANNERS EN SUPABASE
-- Ejecutar este comando en el SQL Editor de Supabase (supabase.com)
-- ================================================================

-- Permite videos MP4, WebM, animaciones JSON y aumenta el límite a 50 MB
UPDATE storage.buckets 
SET 
    allowed_mime_types = NULL,
    file_size_limit = 52428800
WHERE id = 'branding';

DO $$
BEGIN
    RAISE NOTICE '✅ BUCKET BRANDING ACTUALIZADO: Ahora acepta videos MP4, WebM y archivos de hasta 50 MB.';
END $$;
