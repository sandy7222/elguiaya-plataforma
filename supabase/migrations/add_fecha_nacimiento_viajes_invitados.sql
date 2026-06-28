-- Fecha de nacimiento en declaración de pasajeros (requisito PNA)
ALTER TABLE viajes_invitados
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;
