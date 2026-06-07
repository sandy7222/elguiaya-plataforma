-- ====================================================================
-- SCRIPT PARA CREAR FUNCIÓN RPC DE LIMPIEZA DE CONOCIMIENTO CONSOLIDADO
--
-- INSTRUCCIONES:
-- 1. Copia este código.
-- 2. Ejecútalo una sola vez en el SQL Editor de Supabase (https://supabase.com).
-- ====================================================================

-- Eliminar la función previa si existía con otra firma o tipo de retorno (ej. void)
DROP FUNCTION IF EXISTS public.limpiar_conocimiento_aprobado();

CREATE OR REPLACE FUNCTION public.limpiar_conocimiento_aprobado()
RETURNS integer AS $$
DECLARE
    borradas integer;
BEGIN
    -- Borra de la tabla de Supabase las intenciones que ya han sido aprobadas
    -- (el script local de la computadora se encargará de llamarlo una vez que las copie a los JSON)
    DELETE FROM public.guia_conocimiento_distribuido 
    WHERE aprobado = true;
    
    GET DIAGNOSTICS borradas = ROW_COUNT;
    RAISE NOTICE 'Conocimiento aprobado eliminado: % registros', borradas;
    RETURN borradas;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Otorgar permisos de ejecución para que el script de desarrollo pueda llamarlo
GRANT EXECUTE ON FUNCTION public.limpiar_conocimiento_aprobado TO anon, authenticated, service_role;
