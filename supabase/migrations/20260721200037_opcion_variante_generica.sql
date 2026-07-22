-- Tipo genérico "Variante" para señuelos multicolor / sin color único

INSERT INTO public.opciones_variante (nombre, orden)
VALUES ('Variante', 6)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.opcion_variante_valores (opcion_id, valor, orden)
SELECT o.id, v.valor, v.orden
FROM public.opciones_variante o
CROSS JOIN (VALUES
  ('variante 1', 1),
  ('variante 2', 2),
  ('variante 3', 3),
  ('variante 4', 4),
  ('variante 5', 5),
  ('variante 6', 6),
  ('variante 7', 7),
  ('variante 8', 8),
  ('variante 9', 9),
  ('variante 10', 10),
  ('variante 11', 11),
  ('variante 12', 12),
  ('variante 13', 13),
  ('variante 14', 14),
  ('variante 15', 15),
  ('variante 16', 16),
  ('variante 17', 17),
  ('variante 18', 18),
  ('variante 19', 19),
  ('variante 20', 20)
) AS v(valor, orden)
WHERE o.nombre = 'Variante'
ON CONFLICT (opcion_id, valor) DO NOTHING;

NOTIFY pgrst, 'reload schema';
