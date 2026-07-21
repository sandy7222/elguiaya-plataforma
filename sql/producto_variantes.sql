-- Mirror of supabase/migrations/20260721192036_producto_variantes.sql
-- Variantes de venta (color) para catálogo CapitanYA.

CREATE TABLE IF NOT EXISTS public.opciones_variante (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE,
  orden INT NOT NULL DEFAULT 0,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.opcion_variante_valores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  opcion_id UUID NOT NULL REFERENCES public.opciones_variante(id) ON DELETE CASCADE,
  valor TEXT NOT NULL,
  codigo_hex TEXT,
  orden INT NOT NULL DEFAULT 0,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (opcion_id, valor)
);

CREATE TABLE IF NOT EXISTS public.producto_variantes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE CASCADE,
  sku TEXT,
  color TEXT NOT NULL,
  opcion_valor_id UUID REFERENCES public.opcion_variante_valores(id) ON DELETE SET NULL,
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  precio NUMERIC(12, 2),
  imagen_url TEXT,
  galeria_urls TEXT[] NOT NULL DEFAULT '{}',
  es_default BOOLEAN NOT NULL DEFAULT FALSE,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  orden INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_producto_variantes_producto
  ON public.producto_variantes(producto_id);

ALTER TABLE public.pedido_items
  ADD COLUMN IF NOT EXISTS variante_id UUID REFERENCES public.producto_variantes(id) ON DELETE SET NULL;

ALTER TABLE public.pedido_items
  ADD COLUMN IF NOT EXISTS variante_label TEXT;

ALTER TABLE public.opciones_variante ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opcion_variante_valores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.producto_variantes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura publica opciones_variante" ON public.opciones_variante;
CREATE POLICY "Lectura publica opciones_variante"
  ON public.opciones_variante FOR SELECT USING (true);

DROP POLICY IF EXISTS "Auth gestiona opciones_variante" ON public.opciones_variante;
CREATE POLICY "Auth gestiona opciones_variante"
  ON public.opciones_variante FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Lectura publica opcion_variante_valores" ON public.opcion_variante_valores;
CREATE POLICY "Lectura publica opcion_variante_valores"
  ON public.opcion_variante_valores FOR SELECT USING (true);

DROP POLICY IF EXISTS "Auth gestiona opcion_variante_valores" ON public.opcion_variante_valores;
CREATE POLICY "Auth gestiona opcion_variante_valores"
  ON public.opcion_variante_valores FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Lectura publica producto_variantes" ON public.producto_variantes;
CREATE POLICY "Lectura publica producto_variantes"
  ON public.producto_variantes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Auth gestiona producto_variantes" ON public.producto_variantes;
CREATE POLICY "Auth gestiona producto_variantes"
  ON public.producto_variantes FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

INSERT INTO public.opciones_variante (nombre, orden)
VALUES ('Color', 0)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.opcion_variante_valores (opcion_id, valor, codigo_hex, orden)
SELECT o.id, v.valor, v.hex, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('Rojo', '#E53935', 1),
  ('Verde', '#43A047', 2),
  ('Azul', '#1E88E5', 3),
  ('Negro', '#212121', 4),
  ('Blanco', '#FAFAFA', 5),
  ('Amarillo', '#FDD835', 6),
  ('Naranja', '#FB8C00', 7),
  ('Plateado', '#B0BEC5', 8)
) AS v(valor, hex, orden)
WHERE o.nombre = 'Color'
ON CONFLICT (opcion_id, valor) DO NOTHING;

CREATE OR REPLACE FUNCTION public.descontar_stock_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.variante_id IS NOT NULL THEN
    UPDATE public.producto_variantes
    SET stock = GREATEST(0, stock - NEW.cantidad),
        updated_at = NOW()
    WHERE id = NEW.variante_id;

    UPDATE public.productos p
    SET stock = COALESCE((
          SELECT SUM(v.stock)
          FROM public.producto_variantes v
          WHERE v.producto_id = NEW.producto_id AND v.activo = TRUE
        ), 0),
        updated_at = NOW()
    WHERE p.id = NEW.producto_id;
  ELSE
    UPDATE public.productos
    SET stock = GREATEST(0, stock - NEW.cantidad),
        updated_at = NOW()
    WHERE id = NEW.producto_id;
  END IF;
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
