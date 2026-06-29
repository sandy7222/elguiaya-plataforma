-- ══════════════════════════════════════════════════════════════════════════════
-- FIX RLS PARA TABLA PAPELERA_ARCHIVOS
-- ══════════════════════════════════════════════════════════════════════════════
-- Soluciona el error 42501 (new row violates row-level security policy for table "papelera_archivos")
-- al actualizar o subir documentos del capitán.

-- 1. Habilitar Row Level Security en las tablas de la papelera
ALTER TABLE IF EXISTS public.papelera_archivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.papelera_cotizaciones ENABLE ROW LEVEL SECURITY;

-- 2. Políticas permisivas de INSERT y SELECT para usuarios autenticados y anónimos
DROP POLICY IF EXISTS "Permitir insert papelera archivos" ON public.papelera_archivos;
CREATE POLICY "Permitir insert papelera archivos" ON public.papelera_archivos FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir select papelera archivos" ON public.papelera_archivos;
CREATE POLICY "Permitir select papelera archivos" ON public.papelera_archivos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir insert papelera cotizaciones" ON public.papelera_cotizaciones;
CREATE POLICY "Permitir insert papelera cotizaciones" ON public.papelera_cotizaciones FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir select papelera cotizaciones" ON public.papelera_cotizaciones;
CREATE POLICY "Permitir select papelera cotizaciones" ON public.papelera_cotizaciones FOR SELECT USING (true);

-- 3. Actualizar la función del trigger para que se ejecute como SECURITY DEFINER (administrador)
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
