-- =====================================================
-- FIX INTEGRAL: LOGIN 500 + PERMISOS BRANDING
-- =====================================================

-- 1. LIMPIEZA DE TRIGGERS ROTOS (Fix Error 500)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;

-- 2. RECREACIÓN DE FUNCIÓN DE PERFIL (Segura y silenciosa)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW; -- No bloquea el login si falla el insert
END;
$$;

-- 3. ACTIVAR EL TRIGGER NUEvamente
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 4. CONFIGURAR ADMIN Y CONFIRMAR EMAIL
UPDATE auth.users 
SET 
    email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb,
    updated_at = NOW()
WHERE email = 'admin@capitanya.com';

-- 5. POLÍTICAS DE STORAGE (Para el velero unnamed.jpg)
-- Asegurar que el bucket existe
INSERT INTO storage.buckets (id, name, public)
VALUES ('branding', 'branding', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Liberar permisos de subida para autenticados
DROP POLICY IF EXISTS "Permitir subida a usuarios autenticados" ON storage.objects;
CREATE POLICY "Permitir subida a usuarios autenticados"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'branding');

-- Permitir ver las imágenes a todo el mundo (Público)
DROP POLICY IF EXISTS "Permitir lectura pública" ON storage.objects;
CREATE POLICY "Permitir lectura pública"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'branding');

-- 6. VERIFICACIÓN FINAL
SELECT 
    email,
    email_confirmed_at IS NOT NULL AS puede_loguear,
    raw_user_meta_data->>'role' AS rol_asignado
FROM auth.users 
WHERE email = 'admin@capitanya.com';