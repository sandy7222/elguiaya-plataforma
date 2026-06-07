@echo off
echo ==========================================
echo  SCRIPT DE PRUEBA - FLUJO DE EMBARQUE
echo ==========================================
echo.

echo Este script ejecutará la simulación completa del flujo de embarque
echo incluyendo: cotización, respuesta del capitán, productos y ticket final.
echo.

echo Presione cualquier tecla para continuar o Ctrl+C para cancelar...
pause > nul

echo.
echo Ejecutando script SQL de prueba...
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

REM Ejecutar el script de prueba
psql -h localhost -U postgres -d capitanya_db -f "script_prueba_embarque.sql"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Falló la ejecución del script SQL
    echo Verifica que PostgreSQL esté corriendo y que la base de datos exista
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  PRUEBA COMPLETADA EXITOSAMENTE
echo ==========================================
echo.
echo Revisa la salida anterior para ver:
echo - El JSON completo del Ticket de Embarque
echo - El resumen financiero con todos los montos
echo - Los DNI de los pasajeros cargados
echo - La verificación del contador administrador
echo.
pause
