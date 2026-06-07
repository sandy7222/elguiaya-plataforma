-- =====================================================
-- Configuración de Storage para Bucket de Branding
-- =====================================================

-- 1. Crear bucket de branding si no existe
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'branding', 
    'branding', 
    true, 
    10485760, -- 10MB límite
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
) ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Políticas de Storage para el bucket branding

-- Política SELECT: Permitir que cualquiera pueda ver las imágenes (público)
CREATE POLICY "Imagenes públicas de branding son visibles para todos" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'branding' AND 
        (storage.foldername(name))[1] = 'branding'
    );

-- Política INSERT: Permitir subir archivos solo a usuarios autenticados
CREATE POLICY "Usuarios autenticados pueden subir archivos de branding" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'branding'
    );

-- Política UPDATE: Permitir actualizar archivos solo a usuarios autenticados (propietarios)
CREATE POLICY "Usuarios autenticados pueden actualizar sus archivos de branding" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'branding' AND
        auth.uid()::text = (storage.foldername(name))[2]
    );

-- Política DELETE: Permitir eliminar archivos solo a usuarios autenticados (propietarios)
CREATE POLICY "Usuarios autenticados pueden eliminar sus archivos de branding" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'branding' AND
        auth.uid()::text = (storage.foldername(name))[2]
    );

-- 3. Permisos adicionales para usuarios autenticados
GRANT ALL ON SCHEMA storage TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;
GRANT ALL ON storage.objects TO authenticated;

-- 4. Permisos públicos para lectura
GRANT SELECT ON storage.objects TO anon;
GRANT SELECT ON storage.buckets TO anon;

-- 5. Función auxiliar para verificar estructura de carpetas
CREATE OR REPLACE FUNCTION storage.foldername(text)
RETURNS text[]
LANGUAGE sql IMMUTABLE STRICT
AS $$
    SELECT string_to_array($1, '/')
$$;

-- 6. Política alternativa más permisiva para administradores
CREATE POLICY "Administradores pueden gestionar todos los archivos de branding" ON storage.objects
    FOR ALL USING (
        bucket_id = 'branding' AND 
        (
            auth.role() = 'authenticated' AND
            (
                -- Es administrador (verificando metadata)
                auth.jwt() ->> 'role' = 'admin' OR
                auth.jwt() ->> 'rol' = 'admin' OR
                -- O es el propietario del archivo
                auth.uid()::text = (storage.foldername(name))[2]
            )
        )
    ) WITH CHECK (
        bucket_id = 'branding' AND 
        (
            auth.role() = 'authenticated' AND
            (
                -- Es administrador
                auth.jwt() ->> 'role' = 'admin' OR
                auth.jwt() ->> 'rol' = 'admin' OR
                -- O está subiendo su propio archivo
                auth.uid()::text = (storage.foldername(name))[2]
            )
        )
    );

-- 7. Limpiar políticas existentes si hay conflictos
DROP POLICY IF EXISTS "Imagenes públicas de branding son visibles para todos" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden subir archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Administradores pueden gestionar todos los archivos de branding" ON storage.objects;

-- 8. Recrear políticas limpias
CREATE POLICY "Imagenes públicas de branding son visibles para todos" ON storage.objects
    FOR SELECT USING (bucket_id = 'branding');

CREATE POLICY "Usuarios autenticados pueden subir archivos de branding" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated'
    );

CREATE POLICY "Usuarios autenticados pueden actualizar archivos de branding" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated'
    );

CREATE POLICY "Usuarios autenticados pueden eliminar archivos de branding" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'branding' AND 
        auth.role() = 'authenticated'
    );
