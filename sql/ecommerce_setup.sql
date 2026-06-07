-- ================================================================
-- E-COMMERCE SETUP - CAPITANYA
-- Ejecutar en el SQL Editor de Supabase
-- ================================================================

-- 1. TABLA CATEGORIAS
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    rubro_id UUID REFERENCES public.rubros(id) ON DELETE SET NULL,
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Asegurarse de que el RLS esté activo y tenga permisos de lectura pública y escritura admin
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura pública de categorías" 
    ON public.categorias FOR SELECT USING (true);

CREATE POLICY "Escritura admin categorias" 
    ON public.categorias FOR ALL TO authenticated 
    USING (auth.jwt() ->> 'role' = 'admin' OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin');

-- 2. TABLA PRODUCTOS
-- Verificamos si existe y añadimos columnas que podrían faltar
CREATE TABLE IF NOT EXISTS public.productos (
    id TEXT PRIMARY KEY, -- Usamos texto porque el frontend envía millisecondsSinceEpoch.toString()
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio NUMERIC NOT NULL DEFAULT 0.0,
    stock INTEGER NOT NULL DEFAULT 0,
    stock_minimo INTEGER NOT NULL DEFAULT 5, -- Nuevo campo para inventario
    rubro TEXT NOT NULL,
    rubro_id UUID REFERENCES public.rubros(id) ON DELETE SET NULL,
    categoria_id TEXT NOT NULL, -- En el código actual es texto, pero idealmente sería UUID
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Si la tabla ya existía, añadir stock_minimo por si acaso
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'productos' AND column_name = 'stock_minimo') THEN 
        ALTER TABLE public.productos ADD COLUMN stock_minimo INTEGER NOT NULL DEFAULT 5;
    END IF; 
END $$;

ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura pública de productos" 
    ON public.productos FOR SELECT USING (true);

CREATE POLICY "Escritura admin productos" 
    ON public.productos FOR ALL TO authenticated 
    USING (auth.jwt() ->> 'role' = 'admin' OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin');

-- 3. BUCKET DE STORAGE PARA FOTOS DE PRODUCTOS
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'productos_fotos', 
    'productos_fotos', 
    true, 
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true, 
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- Políticas de Storage
-- Leer fotos es público
CREATE POLICY "Fotos de productos accesibles para todos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'productos_fotos');

-- Insertar/Actualizar/Borrar fotos requiere estar autenticado y ser admin
CREATE POLICY "Solo admin puede modificar fotos de productos"
ON storage.objects FOR ALL TO authenticated
USING (
    bucket_id = 'productos_fotos' 
    AND ((auth.jwt() ->> 'role' = 'admin') OR ((SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'))
)
WITH CHECK (
    bucket_id = 'productos_fotos' 
    AND ((auth.jwt() ->> 'role' = 'admin') OR ((SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'))
);

-- 4. TRIGGER PARA DESCONTAR STOCK AL CREAR UN PEDIDO
CREATE OR REPLACE FUNCTION public.descontar_stock_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Se dispara AFTER INSERT en la tabla pedido_item (asumiendo que se llama así)
    -- NEW contiene los datos de la nueva fila insertada
    
    -- Actualizar stock restando la cantidad pedida
    UPDATE public.productos
    SET 
        stock = stock - NEW.cantidad,
        updated_at = NOW()
    WHERE id = NEW.producto_id;
    
    -- No es necesario retornar nada específico en AFTER INSERT
    RETURN NEW;
END;
$$;

-- Nota: Solo crear el trigger si existe la tabla pedido_item o pedido_items
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pedido_item') THEN
        DROP TRIGGER IF EXISTS trigger_descontar_stock ON public.pedido_item;
        CREATE TRIGGER trigger_descontar_stock
            AFTER INSERT ON public.pedido_item
            FOR EACH ROW
            EXECUTE FUNCTION public.descontar_stock_pedido();
    ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pedido_items') THEN
        DROP TRIGGER IF EXISTS trigger_descontar_stock ON public.pedido_items;
        CREATE TRIGGER trigger_descontar_stock
            AFTER INSERT ON public.pedido_items
            FOR EACH ROW
            EXECUTE FUNCTION public.descontar_stock_pedido();
    END IF;
END $$;
