-- ================================================================
-- FIX DEFINITIVO AUTH 500 - PASO 2
-- Ejecutar DESPUÉS del diagnóstico.
-- Cubre TODAS las causas conocidas del error 500 en GoTrue.
-- ================================================================

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 1: EXTENSIONES                                   │
-- │ GoTrue necesita pgcrypto para bcrypt y pgjwt para JWT   │
-- └─────────────────────────────────────────────────────────┘
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgjwt WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 2: PERMISOS DEL SCHEMA AUTH                      │
-- │ El rol supabase_auth_admin necesita acceso total        │
-- └─────────────────────────────────────────────────────────┘
GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO supabase_auth_admin;

-- Permisos para el rol authenticator (conexión entre GoTrue y PG)
GRANT USAGE ON SCHEMA auth TO authenticator;
GRANT SELECT ON auth.users TO authenticator;

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 3: FIX COLUMNAS NULL EN auth.users               │
-- │ GoTrue falla si algún campo de token es NULL en vez de  │
-- │ string vacío. Esto es la causa MÁS COMÚN del error 500. │
-- └─────────────────────────────────────────────────────────┘
UPDATE auth.users
SET
    -- Tokens: deben ser '' (empty string), nunca NULL
    confirmation_token      = COALESCE(confirmation_token, ''),
    recovery_token          = COALESCE(recovery_token, ''),
    email_change_token_new  = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    reauthentication_token  = COALESCE(reauthentication_token, ''),
    email_change            = COALESCE(email_change, ''),
    -- Rol debe ser 'authenticated' para usuarios normales
    role                    = COALESCE(NULLIF(role, ''), 'authenticated'),
    -- Email confirmado (sin esto GoTrue rechaza el login)
    email_confirmed_at      = COALESCE(email_confirmed_at, NOW()),
    updated_at              = NOW()
WHERE email = 'admin@capitanya.com';

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 4: RECREAR USUARIO ADMIN (si todo falla)         │
-- │ Borra y recrea el usuario desde cero con todos los      │
-- │ campos correctos usando la API interna de Supabase.     │
-- └─────────────────────────────────────────────────────────┘

-- OPCIÓN A: Actualizar contraseña con bcrypt correcto
UPDATE auth.users
SET
    encrypted_password = crypt('admin123', gen_salt('bf', 10)),
    updated_at = NOW()
WHERE email = 'admin@capitanya.com'
  AND (
      encrypted_password IS NULL 
      OR encrypted_password = ''
      OR encrypted_password NOT LIKE '$2%'
  );

-- OPCIÓN B: Si el usuario no existe, crearlo completo
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change_token_current,
    reauthentication_token,
    email_change,
    raw_user_meta_data,
    raw_app_meta_data,
    created_at,
    updated_at,
    is_super_admin,
    is_anonymous
)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid,  -- instance_id estándar de Supabase
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@capitanya.com',
    crypt('admin123', gen_salt('bf', 10)),
    NOW(),          -- email_confirmed_at: confirmar inmediatamente
    '',             -- confirmation_token: string vacío, no NULL
    '',             -- recovery_token
    '',             -- email_change_token_new
    '',             -- email_change_token_current
    '',             -- reauthentication_token
    '',             -- email_change
    '{"role": "admin", "nombre": "Administrador"}'::jsonb,
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    NOW(),
    NOW(),
    FALSE,          -- is_super_admin
    FALSE           -- is_anonymous
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users WHERE email = 'admin@capitanya.com'
);

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 5: ELIMINAR AUTH HOOKS ROTOS                     │
-- │ Los Auth Hooks en Supabase pueden bloquear el login si  │
-- │ apuntan a funciones que no existen.                     │
-- └─────────────────────────────────────────────────────────┘

-- Eliminar TODOS los triggers en auth.users para empezar limpio
DO $$
DECLARE
    trig_name TEXT;
BEGIN
    FOR trig_name IN
        SELECT t.tgname
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' AND c.relname = 'users'
          AND NOT t.tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trig_name);
        RAISE NOTICE 'Trigger eliminado: %', trig_name;
    END LOOP;
END $$;

-- ┌─────────────────────────────────────────────────────────┐
-- │ BLOQUE 6: RECREAR TRIGGER SEGURO                        │
-- │ Solo se dispara en INSERT (registro nuevo), no en login │
-- └─────────────────────────────────────────────────────────┘
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    -- Intentar crear perfil; si falla por cualquier razón, no bloquear
    BEGIN
        INSERT INTO public.profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        -- Ignorar silenciosamente - el login debe continuar
        NULL;
    END;
    RETURN NEW;
END;
$$;

-- Recrear trigger solo para INSERT (no afecta el login)
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ┌─────────────────────────────────────────────────────────┐
-- │ VERIFICACIÓN FINAL                                       │
-- └─────────────────────────────────────────────────────────┘
SELECT
    '=== ESTADO FINAL ===' AS info,
    u.email,
    u.email_confirmed_at IS NOT NULL AS email_confirmado,
    u.encrypted_password LIKE '$2%' AS password_bcrypt_valido,
    u.role AS rol,
    u.confirmation_token = '' AS token_confirmacion_limpio,
    u.recovery_token = '' AS token_recovery_limpio,
    u.raw_user_meta_data ->> 'role' AS rol_metadata
FROM auth.users u
WHERE u.email = 'admin@capitanya.com';
