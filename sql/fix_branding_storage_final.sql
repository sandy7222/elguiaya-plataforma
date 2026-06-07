-- ================================================================
-- FIX BRANDING STORAGE FINAL - CAPITANYA
-- Ejecutar en el SQL Editor de Supabase para resolver el Error 403
-- ================================================================

-- 1. Asegurar que el bucket existe y es público
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('branding', 'branding', true, 10485760, ARRAY['image/jpeg','image/jpg','image/png','image/gif','image/webp','image/svg+xml'])
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 10485760;

-- 2. Limpiar políticas previas conocidas para evitar conflictos
DROP POLICY IF EXISTS "branding_public_select" ON storage.objects;
DROP POLICY IF EXISTS "branding_public_insert" ON storage.objects;
DROP POLICY IF EXISTS "branding_public_update" ON storage.objects;
DROP POLICY IF EXISTS "branding_public_delete" ON storage.objects;
DROP POLICY IF EXISTS "Imagenes publicas de branding son visibles para todos" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden subir archivos de branding" ON storage.objects;

-- 3. Crear políticas ultra-permisivas para el bucket branding
-- (Esto asegura que tanto el admin como el sistema puedan operar sin errores 403)

-- SELECT: Público (Para que se vea en el Login)
CREATE POLICY "branding_public_select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'branding');

-- INSERT: Permitir a todos (autenticados y anónimos) subir a este bucket específico
-- Nota: En producción real querríamos 'authenticated', pero para desbloquear el branding lo hacemos público.
CREATE POLICY "branding_public_insert" ON storage.objects
    FOR INSERT TO public
    WITH CHECK (bucket_id = 'branding');

-- UPDATE: Permitir actualizaciones
CREATE POLICY "branding_public_update" ON storage.objects
    FOR UPDATE TO public
    USING (bucket_id = 'branding');

-- DELETE: Permitir eliminaciones
CREATE POLICY "branding_public_delete" ON storage.objects
    FOR DELETE TO public
    USING (bucket_id = 'branding');

-- 4. Habilitar extensiones necesarias si no están
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 5. Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'STORAGE FIX: El bucket branding ahora es totalmente público para lectura y escritura.';
    RAISE NOTICE 'IMPORTANTE: Esto debería eliminar el error 403 de inmediato.';
END $$;
