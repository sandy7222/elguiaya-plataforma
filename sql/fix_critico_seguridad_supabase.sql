-- ====================================================================
-- SCRIPT DE BASE DE DATOS PARA CORRECCIÓN DE SEGURIDAD CRÍTICA (RLS & VISTAS)
--
-- INSTRUCCIONES:
-- 1. Copia el contenido completo de este script.
-- 2. Ve a tu consola de Supabase (https://supabase.com).
-- 3. Entra en tu proyecto (PescadorYA / CapitánYA-MAESTRO).
-- 4. En el menú lateral izquierdo, haz clic en "SQL Editor".
-- 5. Crea una nueva consulta ("New Query").
-- 6. Pega este código y haz clic en el botón "Run" (Ejecutar).
-- ====================================================================

BEGIN;

-- ====================================================================
-- STEP 1: HABILITAR RLS EN TODAS LAS TABLAS DEL ESQUEMA PÚBLICO
-- ====================================================================
-- Este bloque de código dinámico busca todas las tablas existentes en el 
-- esquema 'public' y les habilita Row Level Security (RLS) automáticamente.
-- Esto asegura que ninguna tabla quede expuesta públicamente por error.

DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE 'Iniciando habilitación de RLS en todas las tablas...';
    FOR r IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
        RAISE NOTICE 'RLS habilitado para la tabla: public.%', r.tablename;
    END LOOP;
END $$;


-- ====================================================================
-- STEP 2: RECREAR VISTA vista_gestion_usuarios CON SEGURIDAD (SECURITY INVOKER)
-- ====================================================================
-- Las vistas por defecto se ejecutan con los privilegios del creador (postgres),
-- lo que permitía a cualquier rol anónimo o autenticado acceder indirectamente
-- a los datos privados de la tabla auth.users.
-- Al agregar "WITH (security_invoker = true)", la vista respetará los permisos 
-- del usuario que la consulta, bloqueando a pescadores/capitanes comunes.

DROP VIEW IF EXISTS public.vista_gestion_usuarios;

CREATE OR REPLACE VIEW public.vista_gestion_usuarios 
WITH (security_invoker = true) AS
SELECT
    u.id,
    COALESCE(u.raw_user_meta_data->>'nombre', split_part(u.email, '@', 1)) AS nombre,
    u.email,
    COALESCE(u.raw_user_meta_data->>'rol', 'usuario') AS rol,
    COALESCE(u.raw_user_meta_data->>'estado_cuenta', 'activo') AS estado_cuenta,
    COALESCE((u.raw_user_meta_data->>'verificado')::boolean, false) AS verificado,
    NULL::TIMESTAMP WITH TIME ZONE AS fecha_verificacion,
    NULL::TEXT AS motivo_baneo,
    NULL::TIMESTAMP WITH TIME ZONE AS fecha_baneo,
    u.created_at AS creado_at,
    NULL::TEXT AS baneado_por_email,
    COALESCE((u.raw_user_meta_data->>'esta_baneado')::boolean, false) AS esta_baneado,
    COALESCE((u.raw_user_meta_data->>'es_capitan_verificado')::boolean, false) AS es_capitan_verificado
FROM auth.users u;

-- Otorgar select al rol autenticado (pero al tener security_invoker = true, 
-- PostgreSQL comprobará sus permisos sobre auth.users, el cual está bloqueado para usuarios comunes).
GRANT SELECT ON public.vista_gestion_usuarios TO authenticated;


-- ====================================================================
-- STEP 3: RECREAR VISTA vista_configuracion_branding CON SEGURIDAD
-- ====================================================================
-- Recreamos esta vista con "security_invoker = true" para que herede y respete 
-- las políticas RLS habilitadas en la tabla configuracion_app.

DROP VIEW IF EXISTS public.vista_configuracion_branding;

CREATE OR REPLACE VIEW public.vista_configuracion_branding 
WITH (security_invoker = true) AS
SELECT
    id,
    clave,
    valor,
    tipo_valor,
    descripcion,
    actualizado_at,
    NULL::TEXT AS categoria,  -- Columna de compatibilidad
    NULL::TEXT AS actualizado_por_email,
    NULL::TEXT AS actualizado_por_nombre
FROM public.configuracion_app
ORDER BY clave;

GRANT SELECT ON public.vista_configuracion_branding TO anon;
GRANT SELECT ON public.vista_configuracion_branding TO authenticated;


-- ====================================================================
-- STEP 4: FORZAR RECARGA DEL CACHÉ DEL ESQUEMA
-- ====================================================================
-- Notifica a PostgREST para que actualice la estructura y aplique los cambios inmediatamente.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- Mensaje de finalización exitosa
SELECT '✅ ¡Seguridad de Supabase corregida con éxito! Vuelve a correr el Advisor para verificar.' AS resultado;
