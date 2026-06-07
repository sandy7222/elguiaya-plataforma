# Script de Prueba - Flujo Completo de Embarque

## 📋 Descripción

Este script simula el proceso completo desde que un pescador solicita una cotización hasta la generación del ticket de embarque final con todos los montos y datos de pasajeros.

## 🎯 Objetivos de la Prueba

1. ✅ **Simular Pescador creando cotización**
2. ✅ **Simular Capitán respondiendo con $50.000**
3. ✅ **Agregar productos de tienda ($10.000 + envío $3.500)**
4. ✅ **Verificar contador administrador "Cotizado"**
5. ✅ **Generar JSON completo del Ticket de Embarque**
6. ✅ **Mostrar DNI de pasajeros cargados**

## 🚀 Ejecución

### Opción 1: Usar el archivo .bat (Recomendado en Windows)

```bash
# Ejecutar directamente
cd c:\Users\sandy\OneDrive\Desktop\capitanya_master\test
ejecutar_prueba_embarque.bat
```

### Opción 2: Ejecutar SQL directamente

```bash
# Conectarse a PostgreSQL y ejecutar
psql -h localhost -U postgres -d capitanya_db -f script_prueba_embarque.sql
```

### Opción 3: Copiar y pegar en cliente SQL

Copia el contenido de `script_prueba_embarque.sql` y pégalo en tu cliente SQL preferido (pgAdmin, DBeaver, etc.)

## 📊 Resultados Esperados

### Contador Administrador
- **Estado**: "Cotizado" 
- **Cantidad**: 1 (la cotización creada en la prueba)

### Montos Calculados
- **Presupuesto Viaje**: $50.000
- **Productos Tienda**: $15.000
  - Carnada fresca especial (2x $5.000) = $10.000
  - Bebidas isotónicas (1x $2.000) = $2.000
  - Protector solar (2x $1.500) = $3.000
- **Envío Correo Argentino**: $3.500
- **TOTAL FINAL**: $68.500
- **Comisión Plataforma (10%)**: $6.850
- **Monto Neto**: $61.650

### Pasajeros y DNI
- **Juan Carlos Pérez** - DNI: 12345678 ✅
- **María González** - DNI: 87654321 ✅
- **Roberto López** - DNI: 11223344 ✅
- **Ana Martínez** - DNI: 55667788 ✅

### JSON del Ticket de Embarque
El script generará un JSON completo con:
- ID del viaje y detalles del capitán
- Información del pescador
- Coordenadas y lugar de encuentro
- Desglose completo de costos
- Lista detallada de productos
- Datos completos de pasajeros con DNI
- Estados y timestamps
- Resumen financiero final

## 🔍 Verificación Manual

Después de ejecutar el script, puedes verificar en la base de datos:

```sql
-- Verificar cotización creada
SELECT * FROM cotizaciones WHERE pescador_id = '11111111-1111-1111-1111-111111111111';

-- Verificar productos agregados
SELECT * FROM productos_viajes WHERE viaje_id = [ID_COTIZACION];

-- Verificar pasajeros
SELECT nombre_pasajero, apellido_pasajero, dni_pasajero, datos_validados 
FROM manifiesto_pasajeros WHERE id_viaje = [ID_COTIZACION];

-- Verificar contador administrador
SELECT COUNT(*) FROM cotizaciones WHERE estado = 'presupuestado';
```

## 🛠️ Requisitos Previos

1. **PostgreSQL instalado** y corriendo
2. **Base de datos `capitanya_db`** creada
3. **Tablas del sistema** creadas (ejecutar scripts SQL anteriores)
4. **Permisos de administrador** en la base de datos

## 🚨 Solución de Problemas

### Error: "psql no está instalado"
- Instala PostgreSQL desde https://www.postgresql.org/download/
- Agrega `psql` al PATH del sistema

### Error: "Base de datos no existe"
- Crea la base de datos: `createdb capitanya_db`
- Ejecuta los scripts SQL de creación de tablas primero

### Error: "Relación no existe"
- Asegúrate de haber ejecutado todos los scripts SQL anteriores
- Verifica que las tablas existan: `\dt` en psql

## 📈 Métricas de Prueba

El script mostrará en consola:

```
==========================================
🎫 TICKET DE EMBARQUE - JSON COMPLETO
==========================================
[JSON completo con todos los datos]

==========================================
📊 RESUMEN FINANCIERO
==========================================
Presupuesto Viaje: $50,000.00
Productos Tienda: $15,000.00
Envío Correo Argentino: $3,500.00
------------------------------------------
TOTAL FINAL: $68,500.00
Comisión Plataforma (10%): $6,850.00
Monto Neto: $61,650.00

==========================================
👥 PASAJEROS Y DNI CARGADOS
==========================================
Juan Carlos Pérez      12345678    ✅ Validado
María González         87654321    ✅ Validado
Roberto López           11223344    ✅ Validado
Ana Martínez            55667788    ✅ Validado

==========================================
🔢 VERIFICACIÓN ADMINISTRADOR
==========================================
✅ Contador "Cotizado" para Admin: 1
✅ Cotización ID: [UUID]
✅ Estado: presupuestado
✅ Monto: $50,000.00
✅ Productos: 3 items
✅ Pasajeros: 4 personas
✅ Bultos: 3
```

## 🎉 Éxito de la Prueba

Si todo funciona correctamente, verás:
- ✅ El JSON completo del ticket de embarque
- ✅ Todos los montos sumados correctamente
- ✅ Los DNI de los 4 pasajeros cargados y validados
- ✅ El contador administrador mostrando "1" en estado "Cotizado"
- ✅ Mensaje final de "SIMULACIÓN COMPLETADA EXITOSAMENTE"

## 📝 Notas Adicionales

- El script usa IDs de prueba fijos para pescador y capitán
- Los productos y montos son realistas para un viaje de pesca
- El envío de Correo Argentino es un monto fijo estándar
- Todos los timestamps usan la fecha y hora actual de ejecución
