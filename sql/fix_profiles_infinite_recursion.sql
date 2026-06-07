-- ====================================================================
-- SCRIPT PARA CORREGIR EL ERROR DE RECURSIÓN INFINITA (Error 500 al hacer Login)
-- ====================================================================

BEGIN;

-- 1. Eliminar políticas actuales en la tabla profiles que podrían estar causando el ciclo infinito
DROP POLICY IF EXISTS "Publicar perfiles" ON public.profiles;
DROP POLICY IF EXISTS "Administrar perfiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can see all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can see their own profile" ON public.profiles;

-- Asegurar que la seguridad por fila está habilitada
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Crear políticas seguras sin recursión (NO consultar la tabla profiles dentro de la política de profiles)

-- a. Los usuarios pueden ver y actualizar su propio perfil
CREATE POLICY "Ver propio perfil"
ON public.profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Actualizar propio perfil"
ON public.profiles FOR UPDATE
USING (auth.uid() = user_id);

-- b. Los usuarios pueden insertar su perfil al registrarse
CREATE POLICY "Insertar perfil"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- c. Los Administradores pueden ver y modificar TODOS los perfiles
-- Leemos el rol directamente desde el token JWT (raw_app_meta_data o raw_user_meta_data)
-- en lugar de hacer una consulta a la misma tabla profiles, evitando la recursión infinita.
CREATE POLICY "Admins ver todos los perfiles"
ON public.profiles FOR SELECT
USING (
    (auth.jwt() ->> 'role' = 'admin') OR 
    (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin') OR
    (auth.jwt() -> 'user_metadata' ->> 'rol' = 'admin')
);

CREATE POLICY "Admins actualizar todos los perfiles"
ON public.profiles FOR UPDATE
USING (
    (auth.jwt() ->> 'role' = 'admin') OR 
    (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin') OR
    (auth.jwt() -> 'user_metadata' ->> 'rol' = 'admin')
);

CREATE POLICY "Admins eliminar perfiles"
ON public.profiles FOR DELETE
USING (
    (auth.jwt() ->> 'role' = 'admin') OR 
    (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin') OR
    (auth.jwt() -> 'user_metadata' ->> 'rol' = 'admin')
);

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT '✅ ¡Recursión infinita corregida! Ya puedes iniciar sesión correctamente.' AS resultado;
