-- Fecha de nacimiento en declaración de pasajeros (requisito despacho PNA)
ALTER TABLE public.viajes_invitados
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;

COMMENT ON COLUMN public.viajes_invitados.fecha_nacimiento IS
  'Fecha de nacimiento del pasajero para manifiesto y despacho Prefectura Naval.';

NOTIFY pgrst, 'reload schema';
