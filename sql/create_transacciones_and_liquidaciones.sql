-- SCRIPT PARA CREAR LAS TABLAS DE TRANSACCIONES Y LIQUIDACIONES DE CAPITANES
-- Ejecutar esto en el SQL Editor de Supabase para solucionar el error de tabla inexistente (code: 42P01)

-- 1. Crear tabla transacciones_capitanes si no existe
CREATE TABLE IF NOT EXISTS public.transacciones_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
    monto DECIMAL(12,2) NOT NULL DEFAULT 0.0,
    tipo VARCHAR(50) NOT NULL, -- e.g., 'ganancia_viaje', 'debito_liquidacion', etc.
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- e.g., 'pendiente', 'disponible', 'liquidado'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    liquidacion_at TIMESTAMP WITH TIME ZONE
);

-- 2. Crear tabla liquidaciones si no existe
CREATE TABLE IF NOT EXISTS public.liquidaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    monto DECIMAL(12,2) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagado', 'rechazado')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    pagado_at TIMESTAMP WITH TIME ZONE,
    comprobante_url TEXT,
    comentarios TEXT
);

-- 3. Habilitar RLS en ambas tablas
ALTER TABLE public.transacciones_capitanes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liquidaciones ENABLE ROW LEVEL SECURITY;

-- 4. Asegurar columna admin en profiles por si acaso se usa en alguna policy
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS admin BOOLEAN DEFAULT false;

-- 5. Crear políticas para transacciones_capitanes
DROP POLICY IF EXISTS "Capitanes ver sus transacciones" ON public.transacciones_capitanes;
CREATE POLICY "Capitanes ver sus transacciones"
ON public.transacciones_capitanes FOR SELECT
USING (auth.uid() = capitan_id);

DROP POLICY IF EXISTS "Admin puede ver todas las transacciones" ON public.transacciones_capitanes;
CREATE POLICY "Admin puede ver todas las transacciones"
ON public.transacciones_capitanes FOR ALL
USING (
    (auth.jwt() ->> 'role' = 'admin') OR 
    (EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = auth.uid() 
        AND admin = true
    ))
);

-- 6. Crear políticas para liquidaciones
DROP POLICY IF EXISTS "Capitanes ver sus liquidaciones" ON public.liquidaciones;
CREATE POLICY "Capitanes ver sus liquidaciones"
ON public.liquidaciones FOR SELECT
USING (auth.uid() = capitan_id);

DROP POLICY IF EXISTS "Capitanes insertar sus liquidaciones" ON public.liquidaciones;
CREATE POLICY "Capitanes insertar sus liquidaciones"
ON public.liquidaciones FOR INSERT
WITH CHECK (auth.uid() = capitan_id);

DROP POLICY IF EXISTS "Admin puede ver todas las liquidaciones" ON public.liquidaciones;
CREATE POLICY "Admin puede ver todas las liquidaciones"
ON public.liquidaciones FOR ALL
USING (
    (auth.jwt() ->> 'role' = 'admin') OR 
    (EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = auth.uid() 
        AND admin = true
    ))
);

-- 7. Crear/Re-crear función get_saldos_capitan de forma corregida y robusta
CREATE OR REPLACE FUNCTION public.get_saldos_capitan(p_capitan_id UUID)
RETURNS TABLE (
    saldo_a_confirmar DECIMAL,
    saldo_disponible DECIMAL,
    total_viajes INTEGER,
    viajes_pendientes_confirmacion INTEGER,
    ultimo_viaje_confirmado TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    WITH transacciones_capitan AS (
        SELECT 
            tc.monto,
            tc.estado,
            tc.created_at,
            tc.tipo
        FROM public.transacciones_capitanes tc
        WHERE tc.capitan_id = p_capitan_id
    ),
    saldos_calculados AS (
        SELECT 
            -- Saldo pendiente de confirmación (ganancias en estado pendiente)
            COALESCE(SUM(CASE WHEN tc.estado = 'pendiente' THEN tc.monto ELSE 0.0 END), 0.0) as saldo_a_confirmar,
            -- Saldo disponible neto (ganancias disponibles + ganancias liquidadas + debito liquidado)
            COALESCE(SUM(CASE WHEN tc.estado IN ('disponible', 'liquidado') THEN tc.monto ELSE 0.0 END), 0.0) as saldo_disponible,
            -- Cantidad total de viajes facturados
            COUNT(*) FILTER (WHERE tc.tipo = 'ganancia_viaje')::INTEGER as total_viajes,
            -- Viajes que aún están pendientes
            COUNT(*) FILTER (WHERE tc.tipo = 'ganancia_viaje' AND tc.estado = 'pendiente')::INTEGER as viajes_pendientes_confirmacion,
            -- Última vez que se liberó saldo de un viaje
            MAX(tc.created_at) FILTER (WHERE tc.tipo = 'ganancia_viaje' AND tc.estado IN ('disponible', 'liquidado')) as ultimo_viaje_confirmado
        FROM transacciones_capitan tc
    )
    SELECT 
        sc.saldo_a_confirmar,
        sc.saldo_disponible,
        sc.total_viajes,
        sc.viajes_pendientes_confirmacion,
        sc.ultimo_viaje_confirmado
    FROM saldos_calculados sc;
END;
$$ LANGUAGE plpgsql;

-- 8. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';
