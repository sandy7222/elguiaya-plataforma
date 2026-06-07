-- ASEGURAR ESTRUCTURA PARA CATEGORÍAS Y SUBCATEGORÍAS
DO $$ 
BEGIN 
    -- Columnas para categorias
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categorias' AND column_name='parent_id') THEN
        ALTER TABLE public.categorias ADD COLUMN parent_id UUID REFERENCES public.categorias(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categorias' AND column_name='rubro_id') THEN
        ALTER TABLE public.categorias ADD COLUMN rubro_id TEXT REFERENCES public.rubros(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categorias' AND column_name='activa') THEN
        ALTER TABLE public.categorias ADD COLUMN activa BOOLEAN DEFAULT true;
    END IF;

    -- Relaxar rubro legacy si existe
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categorias' AND column_name='rubro') THEN
        ALTER TABLE public.categorias ALTER COLUMN rubro DROP NOT NULL;
    END IF;

    -- Columnas para productos
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='productos' AND column_name='categoria_id') THEN
        ALTER TABLE public.productos ADD COLUMN categoria_id UUID REFERENCES public.categorias(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='productos' AND column_name='rubro_id') THEN
        ALTER TABLE public.productos ADD COLUMN rubro_id TEXT REFERENCES public.rubros(id);
    END IF;

END $$;
