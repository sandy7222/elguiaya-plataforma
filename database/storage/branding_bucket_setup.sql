-- Configuración para bucket de Supabase Storage para imágenes de branding

-- Nota: Este script debe ejecutarse manualmente en el dashboard de Supabase Storage
-- o usando la API de Supabase Storage directamente desde Flutter

-- Bucket: 'branding-images'
-- Políticas de acceso:
-- 1. Solo administradores pueden subir imágenes
-- 2. Todos los usuarios pueden leer imágenes públicas
-- 3. Límite de tamaño: 10MB por archivo
-- 4. Formatos permitidos: jpg, jpeg, png, gif, webp

-- Estructura de carpetas recomendada:
-- branding-images/
-- ├── login-background/
-- │   ├── background-1.jpg
-- │   ├── background-2.jpg
-- │   └── ...
-- ├── logos/
-- │   ├── logo-primary.png
-- │   ├── logo-secondary.png
-- │   └── ...
-- └── banners/
--     ├── banner-home.jpg
--     ├── banner-about.jpg
--     └── ...

-- Políticas RLS para Storage (ejecutar en dashboard de Supabase):

-- Política: Permitir lectura pública de imágenes de branding
-- CREATE POLICY "Imágenes de branding son públicas" ON storage.objects
-- FOR SELECT USING (
--   bucket_id = 'branding-images'
-- );

-- Política: Solo administradores pueden subir imágenes
-- CREATE POLICY "Solo administradores pueden subir branding" ON storage.objects
-- FOR INSERT WITH CHECK (
--   bucket_id = 'branding-images' AND
--   EXISTS (
--     SELECT 1 FROM auth.users u
--     WHERE u.id = auth.uid()
--       AND u.raw_user_meta_data->>'rol' = 'admin'
--   )
-- );

-- Política: Solo administradores pueden actualizar imágenes
-- CREATE POLICY "Solo administradores pueden actualizar branding" ON storage.objects
-- FOR UPDATE USING (
--   bucket_id = 'branding-images' AND
--   EXISTS (
--     SELECT 1 FROM auth.users u
--     WHERE u.id = auth.uid()
--       AND u.raw_user_meta_data->>'rol' = 'admin'
--   )
-- );

-- Política: Solo administradores pueden eliminar imágenes
-- CREATE POLICY "Solo administradores pueden eliminar branding" ON storage.objects
-- FOR DELETE USING (
--   bucket_id = 'branding-images' AND
--   EXISTS (
--     SELECT 1 FROM auth.users u
--     WHERE u.id = auth.uid()
--       AND u.raw_user_meta_data->>'rol' = 'admin'
--   )
-- );

-- Configuración de CORS para el bucket (si es necesario):
-- En el dashboard de Supabase Storage, configurar CORS para permitir:
-- Origin: * (o dominios específicos)
-- Methods: GET, POST, PUT, DELETE
-- Headers: Content-Type, Authorization
-- Max Age: 3600
