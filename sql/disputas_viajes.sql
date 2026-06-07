-- Migración para crear la tabla de disputas_viajes
CREATE TABLE IF NOT EXISTS public.disputas_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    viaje_id UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
    reclamante_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    motivo VARCHAR(100) NOT NULL,
    descargo TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'resuelta', 'en_revision')),
    resolucion TEXT,
    monto_retenido DECIMAL(12,2) DEFAULT 0.0,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en disputas_viajes
ALTER TABLE public.disputas_viajes ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Usuarios pueden ver sus propias disputas" ON public.disputas_viajes;
CREATE POLICY "Usuarios pueden ver sus propias disputas"
ON public.disputas_viajes FOR SELECT
USING (auth.uid() = reclamante_id);

DROP POLICY IF EXISTS "Usuarios pueden insertar sus propias disputas" ON public.disputas_viajes;
CREATE POLICY "Usuarios pueden insertar sus propias disputas"
ON public.disputas_viajes FOR INSERT
WITH CHECK (auth.uid() = reclamante_id);

DROP POLICY IF EXISTS "Admins pueden ver todas las disputas" ON public.disputas_viajes;
CREATE POLICY "Admins pueden ver todas las disputas"
ON public.disputas_viajes FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid()
        AND admin = TRUE
    )
);
