-- Migration: Crear función marcar_cotizaciones_en_riesgo para el Panel de Alertas de Negocio

CREATE OR REPLACE FUNCTION public.marcar_cotizaciones_en_riesgo()
RETURNS TABLE (
    cotizacion_id UUID,
    capitan_id UUID,
    pescador_id UUID,
    pescador_telefono VARCHAR(30),
    tiempo_transcurrido INTEGER,
    limite_respuesta INTEGER
) AS $$
DECLARE
    cotizaciones_riesgo RECORD;
BEGIN
    FOR cotizaciones_riesgo IN 
        SELECT 
            c.id,
            c.capitan_id,
            c.pescador_id,
            p.telefono_contacto as pescador_telefono,
            (EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60)::INTEGER as tiempo_transcurrido,
            COALESCE(c.limite_respuesta_minutos, 15)::INTEGER as limite_respuesta
        FROM cotizaciones c
        LEFT JOIN profiles p ON c.pescador_id = p.user_id
        WHERE c.estado = 'pendiente'
        AND c.estado != 'en_riesgo'
        AND EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 > COALESCE(c.limite_respuesta_minutos, 15)
        AND (c.riesgo_notificado IS FALSE OR c.riesgo_notificado IS NULL)
    LOOP
        UPDATE cotizaciones 
        SET estado = 'en_riesgo', 
            riesgo_notificado = TRUE,
            updated_at = NOW()
        WHERE id = cotizaciones_riesgo.id;
        
        cotizacion_id := cotizaciones_riesgo.id;
        capitan_id := cotizaciones_riesgo.capitan_id;
        pescador_id := cotizaciones_riesgo.pescador_id;
        pescador_telefono := cotizaciones_riesgo.pescador_telefono;
        tiempo_transcurrido := cotizaciones_riesgo.tiempo_transcurrido;
        limite_respuesta := cotizaciones_riesgo.limite_respuesta;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
