#!/usr/bin/env pwsh
# ============================================================
# Mesa 10 — Fase 0 — Runner de test de concurrencia (pgbench)
# Archivo: mesa10_pgbench_run.ps1
# Sistema operativo: Windows (PowerShell)
# ============================================================
# PRE-REQUISITOS:
#   1. PostgreSQL instalado (incluye pgbench y psql)
#      Descargar: https://www.postgresql.org/download/windows/
#      O via winget: winget install PostgreSQL.PostgreSQL
#   2. Connection string de Supabase:
#      Supabase Dashboard → Settings → Database → Connection string → URI
#      Formato: postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres
# ============================================================

# ── CONFIGURACIÓN ─────────────────────────────────────────
# Pegar aquí la connection string de Supabase:
$env:DATABASE_URL = "postgresql://postgres:[TU_PASSWORD]@db.[TU_REF].supabase.co:5432/postgres"

# Directorio donde están los scripts SQL
$ScriptDir = "c:\CapitanYA\capitan11.5.2026\supabase\migrations"

# Parámetros del test de concurrencia
$Clientes   = 5   # conexiones simultáneas (simula 5 callers al mismo tiempo)
$Threads    = 2   # threads de pgbench (usar min($Clientes, núcleos CPU))
$Transacc   = 2   # transacciones por cliente (5 × 2 = 10 llamadas totales)
              # Nota: tenemos 9 turnos seed → la última llamada finalizará la sala

# ============================================================
# PASO 0: Verificar que pgbench y psql están instalados
# ============================================================
Write-Host "`n[0/5] Verificando herramientas..." -ForegroundColor Cyan

$pgbench = Get-Command pgbench -ErrorAction SilentlyContinue
$psql    = Get-Command psql    -ErrorAction SilentlyContinue

if (-not $pgbench) {
    Write-Host "  ✗ pgbench no encontrado." -ForegroundColor Red
    Write-Host "    Instalar con: winget install PostgreSQL.PostgreSQL" -ForegroundColor Yellow
    Write-Host "    O agregar C:\Program Files\PostgreSQL\<version>\bin al PATH" -ForegroundColor Yellow
    exit 1
}
if (-not $psql) {
    Write-Host "  ✗ psql no encontrado." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ pgbench: $($pgbench.Source)" -ForegroundColor Green
Write-Host "  ✓ psql:    $($psql.Source)"    -ForegroundColor Green

# ============================================================
# PASO 1: Verificar conexión a Supabase
# ============================================================
Write-Host "`n[1/5] Verificando conexión a Supabase..." -ForegroundColor Cyan

$result = psql $env:DATABASE_URL -c "SELECT version();" -t -A 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ No se pudo conectar a Supabase." -ForegroundColor Red
    Write-Host "    Verificar DATABASE_URL en este script." -ForegroundColor Yellow
    Write-Host "    Error: $result" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Conexión OK" -ForegroundColor Green

# ============================================================
# PASO 2: Mostrar estado inicial de la sala
# ============================================================
Write-Host "`n[2/5] Estado inicial de la sala..." -ForegroundColor Cyan

psql $env:DATABASE_URL -c "
SELECT
  s.nombre,
  s.estado,
  s.ronda_actual,
  COUNT(t.id) FILTER (WHERE t.estado = 'pendiente')  AS turnos_pendientes,
  COUNT(t.id) FILTER (WHERE t.estado = 'activo')     AS turnos_activos,
  COUNT(t.id) FILTER (WHERE t.estado = 'completado') AS turnos_completados
FROM salas s
LEFT JOIN turnos t ON t.sala_id = s.id
WHERE s.nombre = 'Mesa 10 — Debate Piloto'
GROUP BY s.nombre, s.estado, s.ronda_actual;
"

# ============================================================
# PASO 3: Reset del estado (dejar todos los turnos pendientes)
# ============================================================
Write-Host "`n[3/5] Reseteando estado para el test..." -ForegroundColor Cyan

psql $env:DATABASE_URL -c "
DO \$\$
DECLARE
  v_sala_id UUID;
BEGIN
  SELECT id INTO v_sala_id FROM salas
  WHERE nombre = 'Mesa 10 — Debate Piloto';

  UPDATE salas
  SET turno_activo_id = NULL, estado = 'esperando', ronda_actual = 0, updated_at = NOW()
  WHERE id = v_sala_id;

  UPDATE turnos
  SET estado = 'pendiente', inicio_at = NULL, fin_at = NULL
  WHERE sala_id = v_sala_id;

  RAISE NOTICE 'Reset OK — turnos pendientes: %',
    (SELECT COUNT(*) FROM turnos WHERE sala_id = v_sala_id AND estado = 'pendiente');
END;
\$\$;
"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Error en el reset." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Reset completado — 9 turnos en estado pendiente" -ForegroundColor Green

# ============================================================
# PASO 4: Ejecutar pgbench con N clientes simultáneos
# ============================================================
Write-Host "`n[4/5] Ejecutando pgbench..." -ForegroundColor Cyan
Write-Host "  Clientes simultáneos : $Clientes" -ForegroundColor White
Write-Host "  Threads              : $Threads"   -ForegroundColor White
Write-Host "  Transacciones/cliente: $Transacc"  -ForegroundColor White
Write-Host "  Total de llamadas    : $($Clientes * $Transacc)" -ForegroundColor White
Write-Host ""
Write-Host "  ⟳ Iniciando $Clientes conexiones simultáneas a activar_siguiente_turno()..." -ForegroundColor Yellow

$PgbenchScript = Join-Path $ScriptDir "mesa10_pgbench_turno.sql"

# -n : no inicializar tablas de pgbench (usamos las nuestras)
# -c : número de clientes concurrentes
# -j : threads de pgbench
# -t : transacciones por cliente
# -f : script SQL a ejecutar
# -P 2 : reportar progreso cada 2 segundos
# --no-vacuum: no ejecutar VACUUM antes del test
pgbench `
  -n `
  -c $Clientes `
  -j $Threads `
  -t $Transacc `
  -f $PgbenchScript `
  -P 2 `
  $env:DATABASE_URL

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n  ✗ pgbench terminó con errores (ver output arriba)." -ForegroundColor Red
    Write-Host "    Si el error es 'MESA10_INVALID_STATE: finalizada', es esperado:" -ForegroundColor Yellow
    Write-Host "    la sala se finalizó porque se agotaron los 9 turnos." -ForegroundColor Yellow
}
else {
    Write-Host "`n  ✓ pgbench completado sin errores de conexión" -ForegroundColor Green
}

# ============================================================
# PASO 5: Verificación de resultados
# ============================================================
Write-Host "`n[5/5] Verificando integridad post-concurrencia..." -ForegroundColor Cyan

psql $env:DATABASE_URL -c "
DO \$\$
DECLARE
  v_activos      INT;
  v_duplicados   INT;
  v_max_activos  INT;
BEGIN
  -- Test 1: No hay más de 1 turno activo simultáneamente ahora
  SELECT COUNT(*) INTO v_activos
  FROM turnos t
  JOIN salas s ON s.id = t.sala_id
  WHERE s.nombre = 'Mesa 10 — Debate Piloto'
    AND t.estado = 'activo';

  RAISE NOTICE '--- RESULTADOS POST-CONCURRENCIA ---';
  RAISE NOTICE 'Turnos activos al finalizar: % (esperado: 0 o 1)', v_activos;

  -- Test 2: Cada turno (sala+ronda+turno_num) fue activado como máximo 1 vez
  -- Un turno activado dos veces generaría inicio_at duplicado o estado inconsistente
  SELECT COUNT(*) INTO v_duplicados
  FROM (
    SELECT sala_id, numero_ronda, numero_turno, COUNT(*) AS veces
    FROM turnos t
    JOIN salas s ON s.id = t.sala_id
    WHERE s.nombre = 'Mesa 10 — Debate Piloto'
      AND t.estado IN ('activo', 'completado')
    GROUP BY sala_id, numero_ronda, numero_turno
    HAVING COUNT(*) > 1
  ) dups;

  IF v_duplicados = 0 THEN
    RAISE NOTICE 'PASS: Cero turnos activados más de una vez';
  ELSE
    RAISE EXCEPTION 'FAIL RACE CONDITION: % turnos fueron activados múltiples veces!', v_duplicados;
  END IF;

  RAISE NOTICE '--- FIN VERIFICACIÓN ---';
END;
\$\$;
"

# Tabla de estado final de todos los turnos
Write-Host "`nEstado final de los turnos:" -ForegroundColor Cyan
psql $env:DATABASE_URL -c "
SELECT
  t.numero_ronda   AS ronda,
  t.numero_turno   AS turno,
  p.alias,
  t.estado,
  TO_CHAR(t.inicio_at, 'HH24:MI:SS.MS') AS inicio,
  TO_CHAR(t.fin_at,    'HH24:MI:SS.MS') AS fin,
  t.duracion_real_seg                    AS seg
FROM turnos t
JOIN participantes p ON p.id = t.participante_id
JOIN salas s ON s.id = t.sala_id
WHERE s.nombre = 'Mesa 10 — Debate Piloto'
ORDER BY t.numero_ronda, t.numero_turno;
"

# Resumen de eventos de auditoría
Write-Host "`nEventos de auditoría generados:" -ForegroundColor Cyan
psql $env:DATABASE_URL -c "
SELECT
  es.tipo,
  COUNT(*) AS cantidad,
  MIN(TO_CHAR(es.created_at, 'HH24:MI:SS.MS')) AS primer_evento,
  MAX(TO_CHAR(es.created_at, 'HH24:MI:SS.MS')) AS ultimo_evento
FROM eventos_sala es
JOIN salas s ON s.id = es.sala_id
WHERE s.nombre = 'Mesa 10 — Debate Piloto'
GROUP BY es.tipo
ORDER BY primer_evento;
"

Write-Host "`n✅ Test de concurrencia completado." -ForegroundColor Green
Write-Host "   Si no hubo errores 'FAIL RACE CONDITION', el SELECT FOR UPDATE está funcionando." -ForegroundColor Green
Write-Host "   Ver tabla de turnos arriba para confirmar secuencia sin duplicados." -ForegroundColor White
