-- ====================================================================
-- FUNCIÓN RPC PARA AUTO-APROBACIÓN SEGURA (48 HORAS)
-- ====================================================================
-- Esta función se ejecuta con privilegios de administrador (SECURITY DEFINER)
-- para poder modificar perfiles y registrar capitanes/pescadores de forma
-- controlada por el servidor, sin delegar la lógica ni las fechas al cliente.

CREATE OR REPLACE FUNCTION public.verificar_y_auto_aprobar_perfil(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER -- Bypasa las políticas de RLS para ejecutar de forma segura con privilegios de dueño de la DB
AS $$
DECLARE
    v_created_at TIMESTAMPTZ;
    v_estado TEXT;
    v_es_capitan BOOLEAN;
    v_expediente TEXT;
    v_nombre TEXT;
    v_dni TEXT;
    v_telefono TEXT;
    v_email TEXT;
    v_localidad TEXT;
    v_direccion_calle TEXT;
    v_direccion_numero TEXT;
    v_provincia TEXT;
    v_avatar_url TEXT;
    v_seguro_url TEXT;
    v_embarcacion_url TEXT;
    v_foto_dni_url TEXT;
    v_carnet_url TEXT;
    v_referido TEXT;
    v_cbu TEXT;
    v_banco_nombre TEXT;
    v_cp TEXT;
    v_dni_int INTEGER;
    v_timestamp TEXT;
    v_prefix TEXT;
    v_new_state TEXT := 'activo';
BEGIN
    -- 1. Obtener datos actuales del perfil del usuario
    SELECT 
        created_at, 
        estado, 
        es_capitan, 
        expediente, 
        nombre, 
        dni, 
        telefono, 
        email,
        localidad, 
        direccion_calle, 
        direccion_numero, 
        provincia, 
        avatar_url,
        seguro_url, 
        embarcacion_url, 
        foto_dni_url, 
        carnet_url, 
        referido, 
        cbu, 
        banco_nombre, 
        cp
    INTO 
        v_created_at, 
        v_estado, 
        v_es_capitan, 
        v_expediente, 
        v_nombre, 
        v_dni, 
        v_telefono, 
        v_email,
        v_localidad, 
        v_direccion_calle, 
        v_direccion_numero, 
        v_provincia, 
        v_avatar_url,
        v_seguro_url, 
        v_embarcacion_url, 
        v_foto_dni_url, 
        v_carnet_url, 
        v_referido, 
        v_cbu, 
        v_banco_nombre, 
        v_cp
    FROM public.profiles
    WHERE user_id = p_user_id;

    -- Si el perfil no existe, o ya no se encuentra en estado 'pendiente', salir sin hacer cambios.
    IF NOT FOUND OR v_estado != 'pendiente' THEN
        RETURN COALESCE(v_estado, 'no_encontrado');
    END IF;

    -- 2. Verificar si pasaron más de 48 horas desde la fecha real de creación
    IF NOW() >= v_created_at + INTERVAL '48 hours' THEN
        
        -- Generar número de legajo/expediente automático si no posee uno
        IF v_expediente IS NULL THEN
            v_timestamp := substr(floor(extract(epoch from now()))::text, 8);
            IF v_es_capitan THEN
                v_prefix := 'CAP';
            ELSE
                v_prefix := 'PES';
            END IF;
            v_expediente := v_prefix || '-2026-' || v_timestamp;
        END IF;

        -- 3. Actualizar el perfil maestro
        UPDATE public.profiles
        SET 
            estado = v_new_state,
            verificado = true,
            expediente = v_expediente,
            updated_at = now()
        WHERE user_id = p_user_id;

        -- 4. Convertir DNI a entero de forma segura para las tablas legadas
        BEGIN
            v_dni_int := regexp_replace(v_dni, '\D', '', 'g')::integer;
        EXCEPTION WHEN OTHERS THEN
            v_dni_int := 0;
        END;

        -- 5. Traspasar inmediatamente los datos a la tabla legada correspondiente
        IF v_es_capitan THEN
            -- Sincronizar en tabla 'guias'
            INSERT INTO public.guias (
                id, nombre, dni, telefono, email, localidad, provincia, calle, altura, cp,
                avatar_url, carnet_timonel, poliza_seguro, expediente, capacidad_personas, referido, cbu, banco_nombre
            ) VALUES (
                p_user_id, v_nombre, COALESCE(v_dni_int, 0), v_telefono, COALESCE(v_email, ''), COALESCE(v_localidad, ''), COALESCE(v_provincia, ''), 
                COALESCE(v_direccion_calle, ''), COALESCE(v_direccion_numero, ''), COALESCE(v_cp, ''),
                v_avatar_url, v_carnet_url, v_seguro_url, v_expediente, 0, v_referido, v_cbu, v_banco_nombre
            )
            ON CONFLICT (id) DO UPDATE SET
                nombre = EXCLUDED.nombre,
                dni = EXCLUDED.dni,
                telefono = EXCLUDED.telefono,
                email = EXCLUDED.email,
                localidad = EXCLUDED.localidad,
                provincia = EXCLUDED.provincia,
                calle = EXCLUDED.calle,
                altura = EXCLUDED.altura,
                cp = EXCLUDED.cp,
                avatar_url = EXCLUDED.avatar_url,
                carnet_timonel = EXCLUDED.carnet_timonel,
                poliza_seguro = EXCLUDED.poliza_seguro,
                expediente = EXCLUDED.expediente,
                referido = EXCLUDED.referido,
                cbu = EXCLUDED.cbu,
                banco_nombre = EXCLUDED.banco_nombre;
        ELSE
            -- Sincronizar en tabla 'pescadores'
            INSERT INTO public.pescadores (
                user_id, nombre, dni, email, telefono, localidad, provincia, avatar_url, dni_url, expediente, referido
            ) VALUES (
                p_user_id, v_nombre, COALESCE(v_dni_int, 0), COALESCE(v_email, ''), v_telefono, COALESCE(v_localidad, ''), COALESCE(v_provincia, ''),
                v_avatar_url, v_foto_dni_url, v_expediente, v_referido
            )
            ON CONFLICT (user_id) DO UPDATE SET
                nombre = EXCLUDED.nombre,
                dni = EXCLUDED.dni,
                email = EXCLUDED.email,
                telefono = EXCLUDED.telefono,
                localidad = EXCLUDED.localidad,
                provincia = EXCLUDED.provincia,
                avatar_url = EXCLUDED.avatar_url,
                dni_url = EXCLUDED.dni_url,
                expediente = EXCLUDED.expediente,
                referido = EXCLUDED.referido;
        END IF;

        RETURN v_new_state;
    END IF;

    -- Si no pasaron las 48 horas, se mantiene en su estado original ('pendiente')
    RETURN v_estado;
END;
$$;
