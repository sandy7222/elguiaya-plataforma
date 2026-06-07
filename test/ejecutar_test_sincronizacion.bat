@echo off
echo ==========================================
echo  TEST DE SINCRONIZACIÓN ENTRE PANELES
echo ==========================================
echo.

echo Este script ejecutará el test completo de sincronización
echo entre Pescador, Capitán y Administrador en Glew.
echo.

echo Presione cualquier tecla para continuar o Ctrl+C para cancelar...
pause > nul

echo.
echo 🔍 Verificando conexión PostgreSQL...
echo.

REM Verificar si psql está disponible
where psql >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: psql no está instalado o no está en el PATH
    echo Por favor, instala PostgreSQL o agrega psql al PATH del sistema
    echo.
    pause
    exit /b 1
)

echo ✅ PostgreSQL encontrado
psql --version

echo.
echo 🗄️ Verificando base de datos...
echo.

REM Verificar si la base de datos existe
psql -h localhost -U postgres -d capitanya_db -c "SELECT 1;" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: No se puede conectar a la base de datos capitanya_db
    echo Verifica que PostgreSQL esté corriendo y que la base de datos exista
    echo.
    pause
    exit /b 1
)

echo ✅ Base de datos capitanya_db conectada

echo.
echo 📋 Ejecutando test de sincronización...
echo.

cd /d "c:\Users\sandy\OneDrive\Desktop\capitanya_master"

REM Ejecutar el script de test
psql -h localhost -U postgres -d capitanya_db -f "test/test_sincronizacion_paneles.sql"

if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Falló la ejecución del test de sincronización
    echo.
    echo Posibles soluciones:
    echo 1. Verifica que las tablas existan (ejecuta scripts SQL anteriores)
    echo 2. Revisa los permisos del usuario postgres
    echo 3. Verifica que las funciones RPC estén creadas
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  TEST COMPLETADO EXITOSAMENTE
echo ==========================================
echo.
echo 📊 Resultados esperados:
echo ✅ Paso 1: Pescador crea trip_request (PENDIENTE)
echo ✅ Verificación 1: Contador Administrador muestra '1 Pendiente'
echo ✅ Paso 2: Capitán genera trip_offer ($50.000)
echo ✅ Verificación 2: Contador Administrador actualizado
echo.
echo 📢 Notificaciones enviadas a Glew:
echo • trip_request_creada
echo • trip_offer_generada
echo.
echo 🎯 Para ver los resultados en detalle:
echo 1. Revisa la salida del script SQL
echo 2. Verifica los contadores en las verificaciones
echo 3. Confirma las notificaciones enviadas a Glew
echo.
pause
