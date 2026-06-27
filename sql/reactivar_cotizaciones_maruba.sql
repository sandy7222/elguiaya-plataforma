-- ============================================================
-- Reactivar cotizaciones de Martha para pruebas reales
-- Las vuelve a poner vigentes desde HOY + 7 días
-- ============================================================

-- Reactivar TODAS las cotizaciones pendientes de Martha con fecha futura
UPDATE cotizaciones 
SET 
  expira_en = NOW() + INTERVAL '7 days',
  estado = 'pendiente'
WHERE pescador_id = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf'
  AND estado = 'pendiente';

-- Verificar resultado
SELECT 
  id,
  descripcion,
  estado,
  expira_en,
  CASE 
    WHEN expira_en > NOW() THEN '✅ ACTIVA AHORA'
    ELSE '❌ AÚN VENCIDA'
  END AS vigencia
FROM cotizaciones
WHERE pescador_id = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf'
ORDER BY created_at DESC;
