-- =====================================================================
-- CAPITAN-YA: MÓDULO DE TOKENS PUSH (FCM_TOKENS)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE UNIQUE,
    token TEXT NOT NULL,
    dispositivo VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Permitir a usuarios autenticados insertar/actualizar sus propios tokens
DROP POLICY IF EXISTS "Permitir insertar/actualizar tokens propios" ON public.fcm_tokens;
CREATE POLICY "Permitir insertar/actualizar tokens propios" 
ON public.fcm_tokens 
FOR ALL 
TO authenticated 
USING (auth.uid() = usuario_id) 
WITH CHECK (auth.uid() = usuario_id);

-- Permitir a cualquier usuario autenticado leer los tokens para enviar notificaciones push (ej: al liquidar o completar viajes)
DROP POLICY IF EXISTS "Permitir lectura de tokens a autenticados" ON public.fcm_tokens;
CREATE POLICY "Permitir lectura de tokens a autenticados" 
ON public.fcm_tokens 
FOR SELECT 
TO authenticated 
USING (true);

-- Índice de alto rendimiento para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_usuario ON public.fcm_tokens(usuario_id);
