-- ====================================================================
-- SISTEMA DE E-COMMERCE ROBUSTO V2 (CON SUBCATEGORÍAS)
-- ====================================================================

-- 1. LIMPIEZA DE CONFLICTOS LEGACY
-- Si existen columnas que causan error por ser NOT NULL y no usarse, las liberamos
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categorias' AND column_name='rubro') THEN
        ALTER TABLE public.categorias ALTER COLUMN rubro DROP NOT NULL;
    END IF;
END $$;

-- 2. TABLA DE RUBROS
CREATE TABLE IF NOT EXISTS public.rubros (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TABLA DE CATEGORÍAS (CON SOPORTE PARA SUBCATEGORÍAS)
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Asegurar integridad de categorias
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS rubro_id TEXT REFERENCES public.rubros(id);
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.categorias(id) ON DELETE CASCADE; -- Para subcategorías
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS icono_url TEXT;
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS activa BOOLEAN DEFAULT true;
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 4. TABLA DE PRODUCTOS
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    precio DECIMAL(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Asegurar integridad de productos
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS descripcion TEXT;
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS stock INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS rubro_id TEXT REFERENCES public.rubros(id);
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS categoria_id UUID REFERENCES public.categorias(id);
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS imagen_url TEXT;
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 5. TABLA DE PEDIDOS
CREATE TABLE IF NOT EXISTS public.pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS total DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS estado TEXT DEFAULT 'pendiente';
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS estado_envio TEXT DEFAULT 'preparando';
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS direccion_envio TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS notas TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS ticket_envio_url TEXT;
ALTER TABLE public.pedidos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 6. TABLA DE ITEMS DEL PEDIDO
CREATE TABLE IF NOT EXISTS public.pedido_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES public.productos(id),
    cantidad INTEGER NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ====================================================================
-- RLS Y POLÍTICAS (IDEMPOTENTE)
-- ====================================================================

ALTER TABLE public.rubros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedido_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    -- Rubros
    DROP POLICY IF EXISTS "Lectura pública de rubros" ON public.rubros;
    CREATE POLICY "Lectura pública de rubros" ON public.rubros FOR SELECT USING (true);

    DROP POLICY IF EXISTS "Admins gestionan rubros" ON public.rubros;
    CREATE POLICY "Admins gestionan rubros" ON public.rubros FOR ALL 
    USING (
        auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin' OR 
            auth.jwt() ->> 'role' = 'service_role'
        )
    );
    
    -- Categorias
    DROP POLICY IF EXISTS "Lectura pública de categorias" ON public.categorias;
    CREATE POLICY "Lectura pública de categorias" ON public.categorias FOR SELECT USING (true);
    
    DROP POLICY IF EXISTS "Admins gestionan categorias" ON public.categorias;
    CREATE POLICY "Admins gestionan categorias" ON public.categorias FOR ALL 
    USING (
        auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin' OR 
            auth.jwt() ->> 'role' = 'service_role'
        )
    );
    
    -- Productos
    DROP POLICY IF EXISTS "Lectura pública de productos" ON public.productos;
    CREATE POLICY "Lectura pública de productos" ON public.productos FOR SELECT USING (true);
    
    DROP POLICY IF EXISTS "Admins gestionan productos" ON public.productos;
    CREATE POLICY "Admins gestionan productos" ON public.productos FOR ALL 
    USING (
        auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin' OR 
            auth.jwt() ->> 'role' = 'service_role'
        )
    );
    
    -- Pedidos
    DROP POLICY IF EXISTS "Usuarios ven sus propios pedidos" ON public.pedidos;
    CREATE POLICY "Usuarios ven sus propios pedidos" ON public.pedidos FOR SELECT 
    USING (auth.uid()::text = usuario_id::text OR (auth.jwt() ->> 'role' = 'service_role'));

    DROP POLICY IF EXISTS "Usuarios crean sus propios pedidos" ON public.pedidos;
    CREATE POLICY "Usuarios crean sus propios pedidos" ON public.pedidos FOR INSERT 
    WITH CHECK (auth.uid()::text = usuario_id::text);

    DROP POLICY IF EXISTS "Admins gestionan todos los pedidos" ON public.pedidos;
    CREATE POLICY "Admins gestionan todos los pedidos" ON public.pedidos FOR ALL 
    USING (
        auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin' OR 
            auth.jwt() ->> 'role' = 'service_role'
        )
    );

    -- Items de Pedidos
    DROP POLICY IF EXISTS "Usuarios ven sus propios items de pedidos" ON public.pedido_items;
    CREATE POLICY "Usuarios ven sus propios items de pedidos" ON public.pedido_items FOR SELECT 
    USING (
        (auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin'
        )) OR
        EXISTS (
            SELECT 1 FROM public.pedidos 
            WHERE pedidos.id = pedido_items.pedido_id 
              AND (pedidos.usuario_id::text = auth.uid()::text OR (auth.jwt() ->> 'role' = 'service_role'))
        )
    );

    DROP POLICY IF EXISTS "Usuarios crean sus propios items de pedidos" ON public.pedido_items;
    CREATE POLICY "Usuarios crean sus propios items de pedidos" ON public.pedido_items FOR INSERT 
    WITH CHECK (
        (auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin'
        )) OR
        EXISTS (
            SELECT 1 FROM public.pedidos 
            WHERE pedidos.id = pedido_items.pedido_id 
              AND (pedidos.usuario_id::text = auth.uid()::text)
        )
    );

    DROP POLICY IF EXISTS "Admins gestionan todos los items de pedidos" ON public.pedido_items;
    CREATE POLICY "Admins gestionan todos los items de pedidos" ON public.pedido_items FOR ALL 
    USING (
        auth.role() = 'authenticated' AND (
            auth.jwt() ->> 'role' = 'admin' OR 
            auth.jwt() ->> 'rol' = 'admin' OR 
            auth.jwt() ->> 'role' = 'service_role'
        )
    );
END $$;

-- ====================================================================
-- DATOS SEMILLA (RUBROS BÁSICOS)
-- ====================================================================

INSERT INTO public.rubros (id, nombre, descripcion)
VALUES 
('pesca', 'Pesca Deportiva', 'Todo para el pescador'),
('camping', 'Outdoor & Camping', 'Equipamiento de aventura')
ON CONFLICT (id) DO NOTHING;

-- ====================================================================
-- LÓGICA DE STOCK
-- ====================================================================

CREATE OR REPLACE FUNCTION public.descontar_stock_pedido()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.productos
    SET stock = stock - NEW.cantidad,
        updated_at = now()
    WHERE id = NEW.producto_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_descontar_stock ON public.pedido_items;
CREATE TRIGGER tr_descontar_stock
AFTER INSERT ON public.pedido_items
FOR EACH ROW
EXECUTE FUNCTION public.descontar_stock_pedido();
