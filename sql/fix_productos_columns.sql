-- ====================================================================
-- FIX: AGREGAR COLUMNAS FALTANTES A LA TABLA PRODUCTOS
-- Este script soluciona el error PGRST204 (columna galeria_urls no encontrada)
-- ====================================================================

DO $$ 
BEGIN 
    -- 1. Agregar columna galeria_urls (Array de texto para múltiples URLs)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'galeria_urls') THEN 
        ALTER TABLE public.productos ADD COLUMN galeria_urls TEXT[] DEFAULT '{}';
    END IF;

    -- 2. Agregar columna video_url (Para links de YouTube/Vimeo)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'video_url') THEN 
        ALTER TABLE public.productos ADD COLUMN video_url TEXT;
    END IF;

    -- 3. Agregar columna destacado (Para mostrar en carruseles principales)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'destacado') THEN 
        ALTER TABLE public.productos ADD COLUMN destacado BOOLEAN DEFAULT false;
    END IF;

    -- 4. Agregar columna rubro (Nombre del rubro en texto, usado por el frontend)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'rubro') THEN 
        ALTER TABLE public.productos ADD COLUMN rubro TEXT;
    END IF;

    -- 5. Agregar columna vendedor_id (Referencia opcional al perfil que lo publica)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'vendedor_id') THEN 
        ALTER TABLE public.productos ADD COLUMN vendedor_id UUID;
    END IF;

END $$;

-- 6. Forzar recarga del schema cache para que PostgREST reconozca los cambios
NOTIFY pgrst, 'reload schema';

-- 7. Verificar que las políticas RLS permitan al rol anon o authenticated realizar cambios
-- (Esto asume que el usuario que usa la app es admin o tiene permisos)
-- Si el error persiste, revisar las políticas de la tabla productos.
