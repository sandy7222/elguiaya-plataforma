-- Tabla de auditoría referenciada por RPCs de billetera/liquidaciones (no existía en remoto).

CREATE TABLE IF NOT EXISTS public.logs_sistema (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo VARCHAR(50) NOT NULL,
  descripcion TEXT NOT NULL,
  user_id UUID,
  cotizacion_id UUID,
  pedido_id UUID,
  datos_adicionales JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_sistema_tipo ON public.logs_sistema (tipo);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_user_id ON public.logs_sistema (user_id);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_cotizacion_id ON public.logs_sistema (cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_pedido_id ON public.logs_sistema (pedido_id);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_created_at ON public.logs_sistema (created_at DESC);

ALTER TABLE public.logs_sistema ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins ver todos los logs" ON public.logs_sistema;
CREATE POLICY "Admins ver todos los logs"
ON public.logs_sistema
FOR SELECT
USING (public.is_admin_user());

DROP POLICY IF EXISTS "Usuarios ver sus logs" ON public.logs_sistema;
CREATE POLICY "Usuarios ver sus logs"
ON public.logs_sistema
FOR SELECT
USING (auth.uid() = user_id);

-- Inserciones solo vía funciones SECURITY DEFINER (sin INSERT directo desde cliente)
DROP POLICY IF EXISTS "Sistema insertar logs" ON public.logs_sistema;

NOTIFY pgrst, 'reload schema';
