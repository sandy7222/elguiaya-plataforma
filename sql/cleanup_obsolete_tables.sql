-- ================================================================
-- CLEANUP OBSOLETE TABLES - CAPITANYA
-- Ejecutar en el SQL Editor de Supabase
-- ================================================================

-- 1. ELIMINAR TABLAS EN INGLÉS (REZAGOS)
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.guides CASCADE;
DROP TABLE IF EXISTS public.fishermen CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;

-- 2. ELIMINAR TABLAS DE PRUEBA O TEMPORALES
DROP TABLE IF EXISTS public.test_table CASCADE;
DROP TABLE IF EXISTS public.temp_table CASCADE;
DROP TABLE IF EXISTS public.productos_old CASCADE;
DROP TABLE IF EXISTS public.categorias_old CASCADE;
DROP TABLE IF EXISTS public.pedidos_old CASCADE;

-- 3. ELIMINAR TABLAS CON PREFIJO WINDSURF (SI EXISTEN)
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'windsurf_%') LOOP 
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP; 
END $$;

-- 4. VERIFICACIÓN DE TABLAS CANÓNICAS (NO ELIMINAR)
-- Estas tablas deben permanecer:
-- categorias, productos, pedidos, pedido_items, rubros, guias, pescadores,
-- viajes_invitados, documentos_usuarios, usuarios, admin_users, admin_logs, 
-- logs_admin, configuracion_app, favoritos, direcciones_envio, banner_promos
