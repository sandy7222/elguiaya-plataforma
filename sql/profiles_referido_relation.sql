-- MIGRACIÓN: Relación de Referido en Profiles (Foreign Key a Comisionistas)
-- Capitán-YA: Patagonia Edition

-- 1. Agregar columna referido_id a la tabla profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS referido_id UUID;

-- 2. Establecer la relación de Clave Foránea (Foreign Key) apuntando a la tabla comisionistas(id)
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS fk_profiles_referido_id,
ADD CONSTRAINT fk_profiles_referido_id 
FOREIGN KEY (referido_id) 
REFERENCES public.comisionistas(id) 
ON DELETE SET NULL;

-- 3. Crear un índice de alto rendimiento para búsquedas y joins rápidos
CREATE INDEX IF NOT EXISTS idx_profiles_referido_id 
ON public.profiles(referido_id);

-- 4. Comentario explicativo de auditoría
COMMENT ON COLUMN public.profiles.referido_id IS 'Identificador del promotor/comisionista dueño de este usuario para la liquidación de comisiones match.';
