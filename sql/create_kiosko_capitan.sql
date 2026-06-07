-- ====================================================================
-- CREACIÓN DE LA TABLA kiosko_capitan Y POLÍTICAS DE ACCESO
-- Ejecutar este archivo en el Editor SQL de Supabase (SQL Editor)
-- ====================================================================

-- 1. Crear tabla kiosko_capitan
CREATE TABLE IF NOT EXISTS public.kiosko_capitan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES public.profiles(user_id) ON DELETE CASCADE NOT NULL,
    nombre_producto TEXT NOT NULL,
    descripcion TEXT,
    precio NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    categoria TEXT NOT NULL,
    imagen_url TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 2. Trigger para actualizar el campo updated_at automáticamente
CREATE OR REPLACE FUNCTION update_kiosko_capitan_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_kiosko_capitan_updated_at ON public.kiosko_capitan;
CREATE TRIGGER trigger_update_kiosko_capitan_updated_at
    BEFORE UPDATE ON public.kiosko_capitan
    FOR EACH ROW
    EXECUTE FUNCTION update_kiosko_capitan_updated_at();

-- 3. Habilitar Seguridad a Nivel de Fila (RLS)
ALTER TABLE public.kiosko_capitan ENABLE ROW LEVEL SECURITY;

-- 4. Crear políticas RLS
DROP POLICY IF EXISTS "Lectura pública de kiosko_capitan" ON public.kiosko_capitan;
CREATE POLICY "Lectura pública de kiosko_capitan" ON public.kiosko_capitan
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Capitanes pueden insertar sus propios productos" ON public.kiosko_capitan;
CREATE POLICY "Capitanes pueden insertar sus propios productos" ON public.kiosko_capitan
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = capitan_id);

DROP POLICY IF EXISTS "Capitanes pueden actualizar sus propios productos" ON public.kiosko_capitan;
CREATE POLICY "Capitanes pueden actualizar sus propios productos" ON public.kiosko_capitan
    FOR UPDATE TO authenticated
    USING (auth.uid() = capitan_id)
    WITH CHECK (auth.uid() = capitan_id);

DROP POLICY IF EXISTS "Capitanes pueden eliminar sus propios productos" ON public.kiosko_capitan;
CREATE POLICY "Capitanes pueden eliminar sus propios productos" ON public.kiosko_capitan
    FOR DELETE TO authenticated
    USING (auth.uid() = capitan_id);

-- ====================================================================
-- CONFIGURACIÓN DEL BUCKET DE ALMACENAMIENTO 'productos'
-- ====================================================================

-- Asegurar que el bucket 'productos' existe y es público
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'productos', 
    'productos', 
    true, 
    5242880, -- Límite de 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true, 
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- Habilitar RLS en objetos de almacenamiento por si no está habilitado (omitido por permisos de propietario)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Políticas de lectura pública para fotos del bucket 'productos'
DROP POLICY IF EXISTS "Lectura pública de fotos de productos" ON storage.objects;
CREATE POLICY "Lectura pública de fotos de productos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'productos');

-- Permitir subir fotos a usuarios autenticados en su propia carpeta (el folder es su userId)
DROP POLICY IF EXISTS "Usuarios pueden subir fotos a su propia carpeta" ON storage.objects;
CREATE POLICY "Usuarios pueden subir fotos a su propia carpeta"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'productos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Permitir actualizar/borrar fotos en su propia carpeta
DROP POLICY IF EXISTS "Usuarios pueden modificar fotos de su propia carpeta" ON storage.objects;
CREATE POLICY "Usuarios pueden modificar fotos de su propia carpeta"
ON storage.objects FOR ALL TO authenticated
USING (
    bucket_id = 'productos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'productos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);
