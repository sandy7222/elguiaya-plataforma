@echo off
echo ==========================================
echo  TEST DE VUELTA: CAPITÁN A PESCADOR
echo ==========================================
echo.

echo Este script ejecutará el test completo del flujo de vuelta:
echo Capitán envía oferta → Pescador recibe y acepta
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
echo 🚢 Ejecutando Test de Vuelta: Capitán a Pescador...
echo.

cd /d "c:\Users\sandy\OneDrive\Desktop\capitanya_master"

REM Ejecutar el script de test de vuelta
psql -h localhost -U postgres -d capitanya_db -f "test/test_vuelta_capitan_pescador.sql"

if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Falló la ejecución del test de vuelta
    echo.
    echo Posibles soluciones:
    echo 1. Verifica que las tablas existan (ejecuta scripts SQL anteriores)
    echo 2. Revisa los permisos del usuario postgres
    echo 3. Verifica que las funciones RPC estén creadas
    echo 4. Asegúrate de haber ejecutado el test de ida primero
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  TEST DE VUELTA COMPLETADO
echo ==========================================
echo.
echo 📊 Resultados esperados:
echo ✅ Capitán completó QuoteFormScreen ($50.000)
echo ✅ Trip_offer actualizada a estado ENVIADO
echo ✅ Administrador verificó cambio de estado
echo ✅ Pescador recibió oferta con JSON completo
echo ✅ Pescador aceptó la oferta
echo.
echo 💰 Montos finales verificados:
echo 🚢 Presupuesto Capitán: $50.000
echo 🛒 Productos Tienda: $15.000
echo 📬 Envío Correo Argentino: $3.500
echo 💎 TOTAL FINAL: $68.500
echo.
echo 📢 Notificaciones enviadas a Glew:
echo • oferta_capitan_enviada
echo • oferta_aceptada_pescador
echo.
echo 🎯 Para ver los resultados en detalle:
echo 1. Revisa la salida del script SQL
echo 2. Verifica el JSON completo del Pescador
echo 3. Confirma los contadores del Administrador
echo 4. Valida las notificaciones a Glew
echo.
pause
