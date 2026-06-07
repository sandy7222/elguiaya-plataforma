-- PASO 1 — Supabase: Crear la tabla guia_conocimiento_distribuido con limite_libreria

CREATE TABLE IF NOT EXISTS public.guia_conocimiento_distribuido (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    libreria TEXT NOT NULL,
    categoria TEXT NOT NULL CHECK (categoria IN ('tecnico', 'lenguaje', 'emergencia')),
    intencion TEXT NOT NULL,
    activadores JSONB NOT NULL, -- Array de strings
    respuesta_limpia TEXT NOT NULL,
    maximo_caracteres INT DEFAULT 120,
    limite_libreria INT NOT NULL, -- Tope máximo permitido para esta librería (ej: 40 para peces)
    gif TEXT,
    puntaje FLOAT,
    aprobado BOOLEAN DEFAULT false,
    fecha_consolidacion DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_aprobacion DATE,
    veces_preguntado INT DEFAULT 0,
    fecha_ultimo_uso DATE,
    CONSTRAINT check_respuesta_limpia_length CHECK (char_length(respuesta_limpia) <= maximo_caracteres)
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.guia_conocimiento_distribuido ENABLE ROW LEVEL SECURITY;

-- Políticas de Seguridad (RLS)
DROP POLICY IF EXISTS "Permitir lectura para todos" ON public.guia_conocimiento_distribuido;
CREATE POLICY "Permitir lectura para todos" ON public.guia_conocimiento_distribuido
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir insercion para todos" ON public.guia_conocimiento_distribuido;
CREATE POLICY "Permitir insercion para todos" ON public.guia_conocimiento_distribuido
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir actualizacion para administradores y service_role" ON public.guia_conocimiento_distribuido;
CREATE POLICY "Permitir actualizacion para administradores y service_role" ON public.guia_conocimiento_distribuido
    FOR UPDATE USING (
        auth.jwt() ->> 'role' = 'service_role' 
        OR (SELECT rol FROM public.profiles WHERE user_id = auth.uid()) = 'admin' 
        OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );

DROP POLICY IF EXISTS "Permitir borrado para administradores y service_role" ON public.guia_conocimiento_distribuido;
CREATE POLICY "Permitir borrado para administradores y service_role" ON public.guia_conocimiento_distribuido
    FOR DELETE USING (
        auth.jwt() ->> 'role' = 'service_role' 
        OR (SELECT rol FROM public.profiles WHERE user_id = auth.uid()) = 'admin' 
        OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );
