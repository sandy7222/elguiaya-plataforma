-- Campos de embarcación para precargar despacho PNA y documentación contractual

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nombre_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS matricula_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS nacionalidad_embarcacion TEXT DEFAULT 'Argentina',
  ADD COLUMN IF NOT EXISTS tipo_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS puerto_base TEXT;

ALTER TABLE public.guias
  ADD COLUMN IF NOT EXISTS nombre_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS matricula_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS nacionalidad_embarcacion TEXT DEFAULT 'Argentina',
  ADD COLUMN IF NOT EXISTS tipo_embarcacion TEXT,
  ADD COLUMN IF NOT EXISTS puerto_base TEXT;

COMMENT ON COLUMN public.profiles.nombre_embarcacion IS
  'Nombre comercial de la embarcación (despacho PNA, directorio, contratos).';
COMMENT ON COLUMN public.profiles.matricula_embarcacion IS
  'Matrícula o identificación de la embarcación para Prefectura Naval.';

NOTIFY pgrst, 'reload schema';
