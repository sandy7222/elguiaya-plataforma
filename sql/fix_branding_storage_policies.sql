-- ==============================================================================
-- Script de Ajuste de Políticas de Storage para Branding (Desarrollo / MVP)
-- Descripción: Relaja las políticas RLS del bucket 'branding' para permitir 
-- al usuario administrador "bypass" subir imágenes sin una sesión autenticada real.
-- ==============================================================================

-- 1. Eliminar políticas restrictivas previas (si existen)
DROP POLICY IF EXISTS "Usuarios autenticados pueden subir archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar sus archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Administradores pueden gestionar todos los archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden subir archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar archivos de branding" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar archivos de branding" ON storage.objects;

-- 2. Crear nuevas políticas relajadas para el bucket 'branding'
-- IMPORTANTE: Estas políticas permiten acceso completo de escritura a cualquier persona
-- Sólo para entornos de MVP o Desarrollo, donde el admin hace login sin sesión de Supabase real.

CREATE POLICY "Permitir subida pública a branding" ON storage.objects
FOR INSERT TO public
WITH CHECK (bucket_id = 'branding');

CREATE POLICY "Permitir actualización pública a branding" ON storage.objects
FOR UPDATE TO public
USING (bucket_id = 'branding');

CREATE POLICY "Permitir eliminación pública a branding" ON storage.objects
FOR DELETE TO public
USING (bucket_id = 'branding');

-- Asegurarnos que la política de lectura pública siga existiendo
DROP POLICY IF EXISTS "Imagenes públicas de branding son visibles para todos" ON storage.objects;
CREATE POLICY "Imagenes públicas de branding son visibles para todos" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'branding');

-- Confirmación
DO $$
BEGIN
  RAISE NOTICE 'Políticas relajadas aplicadas exitosamente al bucket branding.';
END $$;
