-- =====================================================================
-- RECOLECTOR DE BASURA Y PAPELERA GENERAL (CAPITAN YA)
-- =====================================================================
-- Este script define la estructura y automatización para limpiar datos
-- obsoletos (cotizaciones de más de 24 horas) y archivos huérfanos del
-- Storage. Los datos se envían a una papelera temporal por 15 días y
-- luego se eliminan de forma permanente.
-- =====================================================================

-- 1. CREACIÓN DE LAS TABLAS DE LA PAPELERA
-- Papelera de Cotizaciones (sin restricciones de clave foránea para evitar bloqueos)
CREATE TABLE IF NOT EXISTS public.papelera_cotizaciones (
    id UUID,
    pescador_id UUID,
    capitan_id UUID,
    descripcion TEXT,
    presupuesto_monto DECIMAL(10,2),
    estado VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    presupuesto_at TIMESTAMP WITH TIME ZONE,
    respuesta_at TIMESTAMP WITH TIME ZONE,
    punto_partida JSONB,
    punto_destino JSONB,
    coordenadas_partida JSONB,
    coordenadas_destino JSONB,
    expira_en TIMESTAMP WITH TIME ZONE,
    localidad_partida TEXT,
    provincia_partida TEXT,
    movido_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Papelera de Archivos Huérfanos
CREATE TABLE IF NOT EXISTS public.papelera_archivos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    bucket_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    url_original TEXT,
    movido_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS y políticas de acceso para papeleras
ALTER TABLE public.papelera_archivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.papelera_cotizaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir insert papelera archivos" ON public.papelera_archivos;
CREATE POLICY "Permitir insert papelera archivos" ON public.papelera_archivos FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir select papelera archivos" ON public.papelera_archivos;
CREATE POLICY "Permitir select papelera archivos" ON public.papelera_archivos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir insert papelera cotizaciones" ON public.papelera_cotizaciones;
CREATE POLICY "Permitir insert papelera cotizaciones" ON public.papelera_cotizaciones FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir select papelera cotizaciones" ON public.papelera_cotizaciones;
CREATE POLICY "Permitir select papelera cotizaciones" ON public.papelera_cotizaciones FOR SELECT USING (true);

-- Cementerio de Conocimiento Distribuido (El Guía)
CREATE TABLE IF NOT EXISTS public.guia_conocimiento_cementerio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    libreria TEXT NOT NULL,
    categoria TEXT NOT NULL,
    intencion TEXT NOT NULL,
    activadores JSONB NOT NULL,
    respuesta_limpia TEXT NOT NULL,
    maximo_caracteres INT DEFAULT 120,
    limite_libreria INT,
    gif TEXT,
    puntaje FLOAT,
    fecha_consolidacion DATE,
    fecha_aprobacion DATE,
    veces_preguntado INT,
    fecha_ultimo_uso DATE,
    fecha_descarte DATE NOT NULL DEFAULT CURRENT_DATE
);

-- RLS para cementerio
ALTER TABLE public.guia_conocimiento_cementerio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura de cementerio para admin" ON public.guia_conocimiento_cementerio;
CREATE POLICY "Permitir lectura de cementerio para admin" ON public.guia_conocimiento_cementerio
    FOR SELECT USING (
        auth.jwt() ->> 'role' = 'service_role' 
        OR (SELECT rol FROM public.profiles WHERE user_id = auth.uid()) = 'admin' 
        OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );

-- 1b. FUNCIONES RPC PARA LIMPIEZA DE CONOCIMIENTO CONSOLIDADO (EJECUTADAS POR SCRIPT LOCAL O APP MOBILE)
DROP FUNCTION IF EXISTS public.limpiar_conocimiento_aprobado();
DROP FUNCTION IF EXISTS public.limpiar_conocimiento_aprobado_por_categoria(text);

-- Función para limpiar todo lo aprobado
CREATE OR REPLACE FUNCTION public.limpiar_conocimiento_aprobado()
RETURNS integer AS $$
DECLARE
    borradas integer;
BEGIN
    DELETE FROM public.guia_conocimiento_distribuido 
    WHERE aprobado = true;
    
    GET DIAGNOSTICS borradas = ROW_COUNT;
    RAISE NOTICE 'Conocimiento aprobado eliminado: % registros', borradas;
    RETURN borradas;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para limpiar por categoría (usada por la app móvil al sincronizar de forma autónoma)
CREATE OR REPLACE FUNCTION public.limpiar_conocimiento_aprobado_por_categoria(cat_name text)
RETURNS integer AS $$
DECLARE
    borradas integer;
BEGIN
    DELETE FROM public.guia_conocimiento_distribuido 
    WHERE aprobado = true AND categoria = cat_name;
    
    GET DIAGNOSTICS borradas = ROW_COUNT;
    RAISE NOTICE 'Conocimiento aprobado de categoría % eliminado: % registros', cat_name, borradas;
    RETURN borradas;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.limpiar_conocimiento_aprobado TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.limpiar_conocimiento_aprobado_por_categoria TO anon, authenticated, service_role;


-- 2. FUNCIÓN AUXILIAR PARA PARSEAR URLS DE STORAGE A RUTAS DE BUCKET
CREATE OR REPLACE FUNCTION public.url_to_storage_path(url text, OUT bucket_id text, OUT file_path text)
RETURNS record AS $$
DECLARE
    parts text[];
    public_idx int;
BEGIN
    bucket_id := NULL;
    file_path := NULL;
    
    IF url IS NULL OR url = '' THEN
        RETURN;
    END IF;

    -- Separar la URL por '/'
    parts := string_to_array(url, '/');
    
    -- Encontrar el índice de 'public' en la URL
    -- Ejemplo: ['https:', '', 'ref.supabase.co', 'storage', 'v1', 'object', 'public', 'fotos_perfil', 'user_id', 'avatar.jpg']
    FOR i IN 1..array_length(parts, 1) LOOP
        IF parts[i] = 'public' THEN
            public_idx := i;
            EXIT;
        END IF;
    END LOOP;

    -- Si se encontró 'public' y hay suficientes elementos después
    IF public_idx IS NOT NULL AND array_length(parts, 1) > public_idx + 1 THEN
        bucket_id := parts[public_idx + 1];
        file_path := array_to_string(parts[public_idx + 2 : array_length(parts, 1)], '/');
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- 3. TRIGGER PARA DETECTAR Y REGISTRAR ARCHIVOS QUE QUEDAN EN DESUSO
CREATE OR REPLACE FUNCTION public.registrar_archivo_descartado()
RETURNS TRIGGER AS $$
DECLARE
    bucket_val text;
    path_val text;
BEGIN
    -- TABLA: profiles
    IF TG_TABLE_NAME = 'profiles' THEN
        -- avatar_url
        IF (TG_OP = 'DELETE' AND OLD.avatar_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.avatar_url IS DISTINCT FROM NEW.avatar_url AND OLD.avatar_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.avatar_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.avatar_url);
            END IF;
        END IF;

        -- seguro_url
        IF (TG_OP = 'DELETE' AND OLD.seguro_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.seguro_url IS DISTINCT FROM NEW.seguro_url AND OLD.seguro_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.seguro_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.seguro_url);
            END IF;
        END IF;

        -- carnet_url
        IF (TG_OP = 'DELETE' AND OLD.carnet_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.carnet_url IS DISTINCT FROM NEW.carnet_url AND OLD.carnet_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.carnet_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.carnet_url);
            END IF;
        END IF;

        -- embarcacion_url
        IF (TG_OP = 'DELETE' AND OLD.embarcacion_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.embarcacion_url IS DISTINCT FROM NEW.embarcacion_url AND OLD.embarcacion_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.embarcacion_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.embarcacion_url);
            END IF;
        END IF;

    -- TABLA: productos
    ELSIF TG_TABLE_NAME = 'productos' THEN
        -- imagen_url
        IF (TG_OP = 'DELETE' AND OLD.imagen_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.imagen_url IS DISTINCT FROM NEW.imagen_url AND OLD.imagen_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.imagen_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.imagen_url);
            END IF;
        END IF;

    -- TABLA: guias
    ELSIF TG_TABLE_NAME = 'guias' THEN
        -- seguro_url
        IF (TG_OP = 'DELETE' AND OLD.seguro_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.seguro_url IS DISTINCT FROM NEW.seguro_url AND OLD.seguro_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.seguro_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.seguro_url);
            END IF;
        END IF;

        -- embarcacion_url
        IF (TG_OP = 'DELETE' AND OLD.embarcacion_url IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.embarcacion_url IS DISTINCT FROM NEW.embarcacion_url AND OLD.embarcacion_url IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.embarcacion_url) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.embarcacion_url);
            END IF;
        END IF;

    -- TABLA: guia_conocimiento_distribuido
    ELSIF TG_TABLE_NAME = 'guia_conocimiento_distribuido' THEN
        -- gif
        IF (TG_OP = 'DELETE' AND OLD.gif IS NOT NULL) OR 
           (TG_OP = 'UPDATE' AND OLD.gif IS DISTINCT FROM NEW.gif AND OLD.gif IS NOT NULL) THEN
            SELECT * FROM public.url_to_storage_path(OLD.gif) INTO bucket_val, path_val;
            IF bucket_val IS NOT NULL THEN
                INSERT INTO public.papelera_archivos (bucket_id, file_path, url_original)
                VALUES (bucket_val, path_val, OLD.gif);
            END IF;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ADJUNTAR TRIGGERS A LAS TABLAS (DE FORMA SEGURA)
DO $$
BEGIN
    -- Trigger en profiles
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
        DROP TRIGGER IF EXISTS trigger_registrar_descartados_profiles ON public.profiles;
        CREATE TRIGGER trigger_registrar_descartados_profiles
            BEFORE UPDATE OR DELETE ON public.profiles
            FOR EACH ROW
            EXECUTE FUNCTION public.registrar_archivo_descartado();
    END IF;

    -- Trigger en productos
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'productos') THEN
        DROP TRIGGER IF EXISTS trigger_registrar_descartados_productos ON public.productos;
        CREATE TRIGGER trigger_registrar_descartados_productos
            BEFORE UPDATE OR DELETE ON public.productos
            FOR EACH ROW
            EXECUTE FUNCTION public.registrar_archivo_descartado();
    END IF;

    -- Trigger en guias
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'guias') THEN
        DROP TRIGGER IF EXISTS trigger_registrar_descartados_guias ON public.guias;
        CREATE TRIGGER trigger_registrar_descartados_guias
            BEFORE UPDATE OR DELETE ON public.guias
            FOR EACH ROW
            EXECUTE FUNCTION public.registrar_archivo_descartado();
    END IF;

    -- Trigger en guia_conocimiento_distribuido
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'guia_conocimiento_distribuido') THEN
        DROP TRIGGER IF EXISTS trigger_registrar_descartados_guia_conocimiento ON public.guia_conocimiento_distribuido;
        CREATE TRIGGER trigger_registrar_descartados_guia_conocimiento
            BEFORE UPDATE OR DELETE ON public.guia_conocimiento_distribuido
            FOR EACH ROW
            EXECUTE FUNCTION public.registrar_archivo_descartado();
    END IF;
END $$;


-- 5. FUNCIÓN CORE DEL RECOLECTOR DE BASURA (EJECUCIÓN MANUAL O PROGRAMADA)
-- Se define con SECURITY DEFINER para que actúe con permisos de administrador sobre el esquema storage
CREATE OR REPLACE FUNCTION public.ejecutar_recolector_basura()
RETURNS void AS $$
DECLARE
    archivos_borrados_count int := 0;
    cotizaciones_movidas_count int := 0;
    guia_revisar_count int := 0;
    guia_descartado_count int := 0;
BEGIN
    -- FASE 1: MOVER COTIZACIONES EXPIRADAS A LA PAPELERA
    -- Selecciona cotizaciones de más de 24 horas o con expira_en vencida, en estado no finalizado/no aceptado
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'cotizaciones') THEN
        WITH cotizaciones_vencidas AS (
            DELETE FROM public.cotizaciones
            WHERE (expira_en < NOW() OR created_at < NOW() - INTERVAL '24 hours')
              AND estado IN ('pendiente', 'solicitada', 'presupuestado', 'presupuestada')
            RETURNING *
        )
        INSERT INTO public.papelera_cotizaciones (
            id, pescador_id, capitan_id, descripcion, presupuesto_monto, estado, 
            created_at, updated_at, presupuesto_at, respuesta_at, 
            punto_partida, punto_destino, coordenadas_partida, coordenadas_destino, 
            expira_en, localidad_partida, provincia_partida, movido_at
        )
        SELECT 
            id, pescador_id, capitan_id, descripcion, presupuesto_monto, estado, 
            created_at, updated_at, presupuesto_at, respuesta_at, 
            punto_partida, punto_destino, coordenadas_partida, coordenadas_destino, 
            expira_en, localidad_partida, provincia_partida, NOW()
        FROM cotizaciones_vencidas;

        GET DIAGNOSTICS cotizaciones_movidas_count = ROW_COUNT;
        RAISE NOTICE 'Recolector: % cotizaciones enviadas a la papelera.', cotizaciones_movidas_count;
    END IF;

    -- FASE 2: INCINERAR COTIZACIONES DE LA PAPELERA (>15 DÍAS)
    DELETE FROM public.papelera_cotizaciones
    WHERE movido_at < NOW() - INTERVAL '15 days';

    -- FASE 3: INCINERAR ARCHIVOS DEL STORAGE FÍSICO (>15 DÍAS)
    -- Borra de storage.objects si existe el esquema y la tabla
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'storage' AND tablename = 'objects') THEN
        DELETE FROM storage.objects
        USING public.papelera_archivos
        WHERE storage.objects.bucket_id = public.papelera_archivos.bucket_id
          AND storage.objects.name = public.papelera_archivos.file_path
          AND public.papelera_archivos.movido_at < NOW() - INTERVAL '15 days';
    END IF;

    -- Limpia el legajo de la papelera de archivos
    DELETE FROM public.papelera_archivos
    WHERE movido_at < NOW() - INTERVAL '15 days';

    -- FASE A1: ELIMINADA / DESACTIVADA
    -- (No desaprobamos intenciones automáticamente para evitar romper la sincronización local)

    -- FASE A2: MOVER A CEMENTERIO REGISTROS DE GUÍA NO APROBADOS (DRAFTS) SIN USO POR 60 DÍAS
    -- Solo limpiamos registros no aprobados (aprobado = false). Las intenciones aprobadas (aprobado = true) 
    -- solo se eliminan mediante la función RPC limpiar_conocimiento_aprobado() una vez copiadas a los JSON locales.
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'guia_conocimiento_distribuido') AND
       EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'guia_conocimiento_cementerio') THEN
        WITH guia_descartada AS (
            DELETE FROM public.guia_conocimiento_distribuido
            WHERE aprobado = false
              AND (
                (fecha_ultimo_uso IS NOT NULL AND fecha_ultimo_uso < CURRENT_DATE - INTERVAL '60 days')
                OR (fecha_ultimo_uso IS NULL AND fecha_aprobacion IS NOT NULL AND fecha_aprobacion < CURRENT_DATE - INTERVAL '60 days')
                OR (fecha_ultimo_uso IS NULL AND fecha_aprobacion IS NULL AND fecha_consolidacion < CURRENT_DATE - INTERVAL '60 days')
              )
            RETURNING *
        )
        INSERT INTO public.guia_conocimiento_cementerio (
            libreria, categoria, intencion, activadores, respuesta_limpia, maximo_caracteres, 
            limite_libreria, gif, puntaje, fecha_consolidacion, fecha_aprobacion, veces_preguntado, 
            fecha_ultimo_uso, fecha_descarte
        )
        SELECT 
            libreria, categoria, intencion, activadores, respuesta_limpia, maximo_caracteres, 
            limite_libreria, gif, puntaje, fecha_consolidacion, fecha_aprobacion, veces_preguntado, 
            fecha_ultimo_uso, CURRENT_DATE
        FROM guia_descartada;

        GET DIAGNOSTICS guia_descartado_count = ROW_COUNT;
        RAISE NOTICE 'Recolector: % intenciones de guía no aprobadas movidas al cementerio por inactividad (>60 días).', guia_descartado_count;
    END IF;

    -- FASE A3: ELIMINACIÓN DEFINITIVA DEL CEMENTERIO DE GUÍA TRAS 15 DÍAS
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'guia_conocimiento_cementerio') THEN
        DELETE FROM public.guia_conocimiento_cementerio
        WHERE fecha_descarte < CURRENT_DATE - INTERVAL '15 days';
    END IF;

    RAISE NOTICE 'Recolector: Proceso de limpieza finalizado con éxito.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cambiar el propietario de la función a postgres para garantizar privilegios de administración
ALTER FUNCTION public.ejecutar_recolector_basura() OWNER TO postgres;


-- 6. PROGRAMACIÓN DEL JOB CRON EN SUPABASE (DIARIO A LAS 3:00 AM)
-- Usar bloque DO para manejar la habilitación de pg_cron de forma segura
DO $$
BEGIN
    -- Intentar crear la extensión
    BEGIN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'No se pudo crear la extensión pg_cron, es posible que requiera permisos de superusuario.';
    END;

    -- Agendar el job solo si pg_cron está activo y la tabla cron.job existe
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'cron' AND tablename = 'job') THEN
        -- Desvincular job anterior si existe
        PERFORM cron.unschedule(jobid)
        FROM cron.job
        WHERE jobname = 'recolector-basura-automatico';

        -- Agendar nuevo job
        PERFORM cron.schedule(
            'recolector-basura-automatico',
            '0 3 * * *', -- 3:00 AM todos los días
            'SELECT public.ejecutar_recolector_basura();'
        );
    ELSE
        RAISE NOTICE 'La extensión pg_cron no está disponible o no tiene la tabla cron.job activa.';
    END IF;
END $$;
