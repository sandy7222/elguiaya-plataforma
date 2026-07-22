-- Tipos de variante múltiples (Color, Talle, Litros, etc.)

ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS variante_opcion_id UUID
    REFERENCES public.opciones_variante(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_productos_variante_opcion
  ON public.productos(variante_opcion_id);

-- Semilla de tipos (idempotente)
INSERT INTO public.opciones_variante (nombre, orden) VALUES
  ('Color', 0),
  ('Talle', 1),
  ('Litros', 2),
  ('Kilo', 3),
  ('Docena', 4),
  ('Unidad', 5)
ON CONFLICT (nombre) DO NOTHING;

-- Valores Talle
INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('XS', 1), ('S', 2), ('M', 3), ('L', 4), ('XL', 5), ('XXL', 6)
) AS v(valor, orden)
WHERE o.nombre = 'Talle'
ON CONFLICT (opcion_id, valor) DO NOTHING;

-- Valores Litros
INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('250 ml', 1), ('500 ml', 2), ('750 ml', 3), ('1 L', 4), ('1.5 L', 5), ('2 L', 6)
) AS v(valor, orden)
WHERE o.nombre = 'Litros'
ON CONFLICT (opcion_id, valor) DO NOTHING;

-- Valores Kilo
INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('250 g', 1), ('500 g', 2), ('1 kg', 3), ('2 kg', 4), ('5 kg', 5)
) AS v(valor, orden)
WHERE o.nombre = 'Kilo'
ON CONFLICT (opcion_id, valor) DO NOTHING;

-- Valores Docena
INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('1/2 docena', 1), ('1 docena', 2), ('2 docenas', 3), ('3 docenas', 4)
) AS v(valor, orden)
WHERE o.nombre = 'Docena'
ON CONFLICT (opcion_id, valor) DO NOTHING;

-- Valores Unidad
INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('1 u', 1), ('2 u', 2), ('3 u', 3), ('6 u', 4), ('12 u', 5), ('24 u', 6)
) AS v(valor, orden)
WHERE o.nombre = 'Unidad'
ON CONFLICT (opcion_id, valor) DO NOTHING;

-- Productos con variantes existentes → Color por defecto
UPDATE public.productos p
SET variante_opcion_id = o.id
FROM public.opciones_variante o
WHERE o.nombre = 'Color'
  AND p.variante_opcion_id IS NULL
  AND EXISTS (
    SELECT 1 FROM public.producto_variantes v WHERE v.producto_id = p.id
  );

NOTIFY pgrst, 'reload schema';
