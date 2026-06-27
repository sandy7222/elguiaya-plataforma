-- Ficha contractual del viaje: campos de perfil + snapshot JSONB + RPC
-- Ejecutar en Supabase SQL Editor (proyecto ymgsxwfwntbqvguvbhoa)

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS numero_carnet TEXT,
  ADD COLUMN IF NOT EXISTS aseguradora TEXT,
  ADD COLUMN IF NOT EXISTS tipo_seguro TEXT,
  ADD COLUMN IF NOT EXISTS numero_poliza TEXT,
  ADD COLUMN IF NOT EXISTS expediente TEXT,
  ADD COLUMN IF NOT EXISTS nombre VARCHAR(255),
  ADD COLUMN IF NOT EXISTS vencimiento_seguro TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS vencimiento_carnet TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS capacidad_personas INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS capacidad_kilos INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS servicio_carnada TEXT DEFAULT 'No',
  ADD COLUMN IF NOT EXISTS servicio_lenia TEXT DEFAULT 'false',
  ADD COLUMN IF NOT EXISTS servicio_almacen TEXT DEFAULT 'false',
  ADD COLUMN IF NOT EXISTS bio_pescador JSONB DEFAULT '{}'::jsonb;

ALTER TABLE public.presupuestos
  ADD COLUMN IF NOT EXISTS contrato_snapshot JSONB;

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS contrato_snapshot JSONB;

-- Backfill presupuestos sin snapshot
-- (subconsulta: en UPDATE no se puede referenciar la tabla destino "p" dentro de JOINs del FROM)
UPDATE public.presupuestos p
SET contrato_snapshot = src.snapshot
FROM (
  SELECT
    pres.id AS presupuesto_id,
    jsonb_build_object(
      'capturado_en', COALESCE(pres.created_at, NOW())::text,
      'capitan', jsonb_build_object(
        'nombre', COALESCE(
          NULLIF(TRIM(pres.capitan_nombre), ''),
          NULLIF(TRIM(g.nombre), ''),
          NULLIF(TRIM(pr.nombre), ''),
          'Capitán'
        ),
        'expediente', COALESCE(
          NULLIF(TRIM(g.expediente), ''),
          NULLIF(TRIM(pr.expediente), '')
        ),
        'numero_carnet', NULLIF(TRIM(pr.numero_carnet), ''),
        'vencimiento_carnet', pr.vencimiento_carnet,
        'aseguradora', NULLIF(TRIM(pr.aseguradora), ''),
        'tipo_seguro', NULLIF(TRIM(pr.tipo_seguro), ''),
        'numero_poliza', NULLIF(TRIM(pr.numero_poliza), ''),
        'vencimiento_seguro', pr.vencimiento_seguro,
        'telefono', COALESCE(NULLIF(TRIM(pr.telefono), ''), NULLIF(TRIM(g.telefono), ''))
      ),
      'embarcacion', jsonb_build_object(
        'barco_nombre', COALESCE(
          NULLIF(TRIM(pres.barco_nombre), ''),
          CASE
            WHEN COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), '')) IS NOT NULL
              THEN 'Embarcación de ' || COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), ''))
            ELSE 'Embarcación Principal'
          END
        ),
        'embarcacion_url', COALESCE(
          NULLIF(TRIM(pres.embarcacion_url), ''),
          NULLIF(TRIM(g.embarcacion_url), ''),
          NULLIF(TRIM(pr.embarcacion_url), '')
        ),
        'capacidad_personas', COALESCE(pr.capacidad_personas, 0),
        'capacidad_kilos', COALESCE(pr.capacidad_kilos, 0)
      ),
      'servicios', jsonb_build_object(
        'carnada', COALESCE(pr.servicio_carnada, 'No'),
        'lenia', COALESCE(pr.servicio_lenia::text, 'false'),
        'almacen', COALESCE(pr.servicio_almacen::text, 'false'),
        'cabania', COALESCE((pr.bio_pescador::jsonb) ->> 'cabania', 'false'),
        'banio', COALESCE((pr.bio_pescador::jsonb) ->> 'banio', 'false'),
        'parrilla', COALESCE((pr.bio_pescador::jsonb) ->> 'parrilla', 'false')
      ),
      'viaje', jsonb_build_object(
        'fecha_ida', c.fecha_ida,
        'hora_encuentro', c.hora_encuentro,
        'lugar_encuentro', c.lugar_encuentro,
        'cantidad_personas', c.cantidad_personas,
        'distancia_km', c.distancia_km,
        'descripcion', c.descripcion
      ),
      'oferta', jsonb_build_object(
        'monto', pres.monto,
        'detalles', pres.detalles
      )
    ) AS snapshot
  FROM public.presupuestos pres
  INNER JOIN public.profiles pr ON pr.user_id = pres.capitan_id
  LEFT JOIN public.guias g ON g.id = pres.capitan_id
  LEFT JOIN public.cotizaciones c ON c.id = pres.cotizacion_id
  WHERE pres.contrato_snapshot IS NULL
) src
WHERE p.id = src.presupuesto_id;

-- Backfill pedidos pagados/activos desde presupuesto
UPDATE public.pedidos pe
SET contrato_snapshot = pr.contrato_snapshot
FROM public.presupuestos pr
WHERE pr.id = pe.presupuesto_id
  AND pe.contrato_snapshot IS NULL
  AND pr.contrato_snapshot IS NOT NULL;

CREATE OR REPLACE FUNCTION public.obtener_ficha_contractual(p_pedido_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_pedido RECORD;
  v_snapshot JSONB;
BEGIN
  IF v_uid IS NULL OR p_pedido_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    pe.id,
    pe.estado,
    pe.monto_total,
    pe.fecha_servicio,
    pe.contacto_habilitado,
    pe.pescador_id,
    pe.capitan_id,
    pe.presupuesto_id,
    pe.cotizacion_id,
    pe.contrato_snapshot AS pedido_snapshot,
    pr.contrato_snapshot AS presupuesto_snapshot
  INTO v_pedido
  FROM public.pedidos pe
  LEFT JOIN public.presupuestos pr ON pr.id = pe.presupuesto_id
  WHERE pe.id = p_pedido_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_uid <> v_pedido.pescador_id AND v_uid <> v_pedido.capitan_id THEN
    RETURN NULL;
  END IF;

  IF v_pedido.estado NOT IN (
    'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado', 'programado'
  ) THEN
    RETURN NULL;
  END IF;

  IF v_uid = v_pedido.pescador_id
     AND COALESCE(v_pedido.contacto_habilitado, FALSE) = FALSE
     AND v_pedido.estado IN ('programado') THEN
    RETURN NULL;
  END IF;

  v_snapshot := COALESCE(v_pedido.pedido_snapshot, v_pedido.presupuesto_snapshot);

  RETURN jsonb_build_object(
    'pedido_id', v_pedido.id,
    'estado', v_pedido.estado,
    'monto_total', v_pedido.monto_total,
    'fecha_servicio', v_pedido.fecha_servicio,
    'contacto_habilitado', COALESCE(v_pedido.contacto_habilitado, FALSE),
    'capitan_id', v_pedido.capitan_id,
    'pescador_id', v_pedido.pescador_id,
    'presupuesto_id', v_pedido.presupuesto_id,
    'cotizacion_id', v_pedido.cotizacion_id,
    'contrato_snapshot', v_snapshot
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_ficha_contractual(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'OK: contrato_viaje_snapshot + obtener_ficha_contractual' AS resultado;
