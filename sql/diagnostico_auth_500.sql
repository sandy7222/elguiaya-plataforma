-- ================================================================
-- DIAGNÓSTICO DEFINITIVO - PASO 1
-- Ejecutar PRIMERO para ver el estado real del problema
-- Dashboard → SQL Editor → Correr este script → Leer los resultados
-- ================================================================

-- A. Ver TODOS los campos del usuario admin (incluyendo tokens)
SELECT 
    id,
    email,
    email_confirmed_at,
    last_sign_in_at,
    created_at,
    updated_at,
    is_super_admin,
    -- Campos de token que GoTrue NECESITA (deben ser '' no NULL)
    CASE WHEN confirmation_token IS NULL THEN '❌ NULL' ELSE '✅ OK' END AS confirmation_token,
    CASE WHEN recovery_token IS NULL THEN '❌ NULL' ELSE '✅ OK' END AS recovery_token,
    CASE WHEN email_change_token_new IS NULL THEN '❌ NULL' ELSE '✅ OK' END AS email_change_token_new,
    CASE WHEN email_change_token_current IS NULL THEN '❌ NULL' ELSE '✅ OK' END AS email_change_token_current,
    CASE WHEN reauthentication_token IS NULL THEN '❌ NULL' ELSE '✅ OK' END AS reauthentication_token,
    -- Campo crítico: encrypted_password
    CASE 
        WHEN encrypted_password IS NULL THEN '❌ NULL - SIN CONTRASEÑA'
        WHEN encrypted_password LIKE '$2%' THEN '✅ bcrypt válido'
        ELSE '⚠️ Hash inválido: ' || LEFT(encrypted_password, 10)
    END AS password_status,
    -- Rol
    role AS auth_role
FROM auth.users
WHERE email = 'admin@capitanya.com';

-- B. Verificar extensiones críticas para GoTrue
SELECT 
    name,
    installed_version,
    CASE WHEN installed_version IS NOT NULL THEN '✅ INSTALADA' ELSE '❌ FALTA' END AS estado
FROM pg_available_extensions
WHERE name IN ('pgcrypto', 'pgjwt', 'uuid-ossp', 'pg_stat_statements')
ORDER BY name;

-- C. Ver TODOS los triggers en auth.users
SELECT 
    t.tgname AS trigger_name,
    p.proname AS function_name,
    n.nspname AS function_schema,
    t.tgenabled AS enabled,
    CASE t.tgtype::integer & 66
        WHEN 2 THEN 'BEFORE'
        WHEN 64 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END AS timing
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace cn ON c.relnamespace = cn.oid
WHERE cn.nspname = 'auth' AND c.relname = 'users'
ORDER BY t.tgname;

-- D. Verificar Auth Hooks en Supabase (custom hooks que bloquean el login)
SELECT *
FROM vault.secrets
WHERE name LIKE '%hook%' OR name LIKE '%auth%'
LIMIT 10;

-- E. Verificar permisos del rol supabase_auth_admin sobre auth.users
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY grantee, privilege_type;
