-- =====================================================
-- RLS DEFINITIVO PARA BUCKET "branding"
-- Ejecutar este script en el SQL Editor de Supabase
-- Orden correcto: DROP → CREATE (sin conflictos)
-- =====================================================

-- PASO 1: Limpiar políticas existentes para evitar duplicados
DROP POLICY IF EXISTS "Imagenes públicas de branding son visibles para todos" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden subir archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Administradores pueden gestionar todos los archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar archivos de branding" ON storage.objects;

-- PASO 2: Crear o actualizar el bucket "branding" como público
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'branding',
    'branding',
    true,           -- PÚBLICO: para que las URLs funcionen sin autenticación
    52428800,       -- 50MB de límite
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
) ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'];

-- PASO 3: Habilitar RLS en storage.objects (ya debería estar activo)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- PASO 4: Crear políticas limpias

-- SELECT: Cualquiera puede ver imágenes del bucket branding (es público)
CREATE POLICY "branding_select_publico"
ON storage.objects FOR SELECT
USING (bucket_id = 'branding');

-- INSERT: Solo usuarios autenticados pueden subir
CREATE POLICY "branding_insert_autenticado"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'branding' AND
    auth.role() = 'authenticated'
);

-- UPDATE: Solo usuarios autenticados pueden actualizar
CREATE POLICY "branding_update_autenticado"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'branding' AND
    auth.role() = 'authenticated'
);

-- DELETE: Solo usuarios autenticados pueden eliminar
CREATE POLICY "branding_delete_autenticado"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'branding' AND
    auth.role() = 'authenticated'
);

-- PASO 5: Verificar resultado
SELECT
    policyname,
    cmd,
    roles,
    permissive
FROM pg_policies
WHERE tablename = 'objects'
  AND schemaname = 'storage'
  AND policyname LIKE 'branding%'
ORDER BY policyname;

-- PASO 6: Verificar que el bucket existe y es público
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE name = 'branding';
