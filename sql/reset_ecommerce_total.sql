-- ====================================================================
-- REINICIO TOTAL DE E-COMMERCE: CAPITANYA
-- ESTE SCRIPT BORRA LAS TABLAS VIEJAS Y LAS CREA DE CERO CON UUIDs
-- ====================================================================

-- 1. ELIMINACIÓN DE TABLAS VIEJAS (LIMPIEZA TOTAL)
DROP TABLE IF EXISTS public.pedido_items CASCADE;
DROP TABLE IF EXISTS public.pedidos CASCADE;
DROP TABLE IF EXISTS public.productos CASCADE;
DROP TABLE IF EXISTS public.categorias CASCADE;
DROP TABLE IF EXISTS public.rubros CASCADE;

-- 2. TABLA DE RUBROS
CREATE TABLE public.rubros (
    id TEXT PRIMARY KEY, -- 'pesca', 'camping'
    nombre TEXT NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TABLA DE CATEGORÍAS
CREATE TABLE public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    rubro_id TEXT REFERENCES public.rubros(id),
    parent_id UUID REFERENCES public.categorias(id) ON DELETE CASCADE,
    icono_url TEXT,
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TABLA DE PRODUCTOS
CREATE TABLE public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    rubro_id TEXT REFERENCES public.rubros(id),
    categoria_id UUID REFERENCES public.categorias(id),
    imagen_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. TABLA DE PEDIDOS
CREATE TABLE public.pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES auth.users(id),
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado TEXT DEFAULT 'pendiente',
    estado_envio TEXT DEFAULT 'preparando',
    direccion_envio TEXT,
    notes TEXT,
    ticket_envio_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. TABLA DE ITEMS DEL PEDIDO
CREATE TABLE public.pedido_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES public.productos(id),
    cantidad INTEGER NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ====================================================================
-- SEGURIDAD RLS
-- ====================================================================

ALTER TABLE public.rubros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedido_items ENABLE ROW LEVEL SECURITY;

-- Políticas Simplificadas para que el Admin pueda operar sin bloqueos
CREATE POLICY "Lectura pública general" ON public.rubros FOR SELECT USING (true);
CREATE POLICY "Lectura pública general" ON public.categorias FOR SELECT USING (true);
CREATE POLICY "Lectura pública general" ON public.productos FOR SELECT USING (true);

-- Permisos totales para el Admin en Categorias y Productos
CREATE POLICY "Admin full access categorias" ON public.categorias FOR ALL USING (true);
CREATE POLICY "Admin full access productos" ON public.productos FOR ALL USING (true);
CREATE POLICY "Admin full access rubros" ON public.rubros FOR ALL USING (true);

-- Pedidos
CREATE POLICY "Usuarios ven sus pedidos" ON public.pedidos FOR SELECT USING (auth.uid() = usuario_id);
CREATE POLICY "Usuarios crean sus pedidos" ON public.pedidos FOR INSERT WITH CHECK (auth.uid() = usuario_id);
CREATE POLICY "Admin gestiona pedidos" ON public.pedidos FOR ALL USING (true);

-- Items
CREATE POLICY "Ver items pedidos" ON public.pedido_items FOR SELECT USING (true);
CREATE POLICY "Crear items pedidos" ON public.pedido_items FOR INSERT WITH CHECK (true);

-- ====================================================================
-- DATOS SEMILLA (RUBROS Y CATEGORÍAS)
-- ====================================================================

INSERT INTO public.rubros (id, nombre, descripcion)
VALUES 
('pesca', 'Pesca Deportiva', 'Todo para el pescador'),
('camping', 'Outdoor & Camping', 'Equipamiento de aventura');

-- Insertar Categorías principales
INSERT INTO public.categorias (nombre, rubro_id) VALUES 
('Cañas', 'pesca'),
('Reeles', 'pesca'),
('Carpas', 'camping');

-- ====================================================================
-- TRIGGERS DE STOCK
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

CREATE TRIGGER tr_descontar_stock
AFTER INSERT ON public.pedido_items
FOR EACH ROW
EXECUTE FUNCTION public.descontar_stock_pedido();
