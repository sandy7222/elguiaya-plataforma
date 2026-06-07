-- ====================================================================
-- SISTEMA DE LEADS Y SOLICITUDES DE CONTACTO
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.solicitudes_contacto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pescador TEXT NOT NULL,
    id_capitan TEXT NOT NULL,
    id_producto UUID REFERENCES public.productos(id),
    fecha TIMESTAMPTZ DEFAULT now(),
    estado TEXT DEFAULT 'pendiente', -- 'pendiente', 'contactado', 'completado'
    mensaje_inicial TEXT
);

-- Habilitar RLS
ALTER TABLE public.solicitudes_contacto ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso (Modo Obra / Desarrollo)
DO $$ BEGIN
    DROP POLICY IF EXISTS "Lectura pública solicitudes" ON public.solicitudes_contacto;
    CREATE POLICY "Lectura pública solicitudes" ON public.solicitudes_contacto FOR SELECT USING (true);
    
    DROP POLICY IF EXISTS "Inserción pública solicitudes" ON public.solicitudes_contacto;
    CREATE POLICY "Inserción pública solicitudes" ON public.solicitudes_contacto FOR INSERT WITH CHECK (true);
    
    DROP POLICY IF EXISTS "Edición para capitanes" ON public.solicitudes_contacto;
    CREATE POLICY "Edición para capitanes" ON public.solicitudes_contacto FOR UPDATE USING (true);
END $$;

-- Índice para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_solicitudes_capitan ON public.solicitudes_contacto(id_capitan);
