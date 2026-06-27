-- ============================================================
-- FIX v4: PASO A PASO (ejecutar CADA bloque por separado)
-- ============================================================

-- ══════════════════════════════════════════════
-- QUERY 1: Eliminar la vista dependiente
-- ══════════════════════════════════════════════
DROP VIEW IF EXISTS vista_capitan_manifiesto CASCADE;


-- ══════════════════════════════════════════════
-- QUERY 2: Eliminar FK y cambiar tipo de columna
-- (Ejecutar DESPUÉS del Query 1)
-- ══════════════════════════════════════════════
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tc.constraint_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_name = 'viajes_invitados'
      AND kcu.column_name = 'pedido_id'
  LOOP
    EXECUTE format('ALTER TABLE viajes_invitados DROP CONSTRAINT IF EXISTS %I', r.constraint_name);
    RAISE NOTICE 'FK eliminada: %', r.constraint_name;
  END LOOP;

  ALTER TABLE viajes_invitados
    ALTER COLUMN pedido_id TYPE TEXT USING pedido_id::TEXT;

  RAISE NOTICE 'pedido_id convertido a TEXT OK';
END;
$$;


-- ══════════════════════════════════════════════
-- QUERY 3: Recrear la vista con los tipos correctos
-- (Ejecutar DESPUÉS del Query 2)
-- ══════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_capitan_manifiesto AS
SELECT
  p.id::text            AS pedido_id,
  p.capitan_id,
  p.fecha_servicio,
  p.estado,
  p.monto_total,
  vi.nombre,
  vi.apellido,
  vi.dni,
  vi.es_titular,
  vi.foto_dni_url,
  vi.pescador_id
FROM pedidos p
LEFT JOIN viajes_invitados vi ON vi.pedido_id = p.id::text;

-- Verificar OK:
SELECT COUNT(*) FROM vista_capitan_manifiesto;
