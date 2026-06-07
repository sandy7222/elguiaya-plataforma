# ✅ Plan de Reconexión de Overlay - COMPLETADO

## Resumen de Cambios Aplicados

### 1. **Verificación Previa** ✅
- ✅ Se eliminó `contexto: motor.contexto` de llamadas a `GroqService()` (ya estaba hecho)
- ✅ Todos los `print()` estaban siendo reemplazados por `debugPrint()`

### 2. **Cambios Realizados Hoy** ✅
Se completaron 4 reemplazos críticos de logging:

#### **baqueano_ia_service.dart**
- ✅ Línea 388: `print()` → `debugPrint('[BaqueanoRouter] Error de ping con Groq: $e')`
- ✅ Línea 411: `print()` → `debugPrint('[BaqueanoRouter] Error de ping con Ollama en estado: $e')`

#### **el_guia_engine.dart**
- ✅ Línea 1057: `print()` → `debugPrint('✅ [EL-GUIA] v2.0 inicializado...')`
- ✅ Línea 1061: `print()` → `debugPrint('⚠️ [EL-GUIA] Error al inicializar: $e')`

### 3. **Infraestructura de Overlay** ✅
**main.dart — builder configurado:**
```dart
builder: (context, child) {
  return Stack(
    children: [
      child ?? const SizedBox.shrink(),
      const GuiaOverlay(),
    ],
  );
},
```
**Resultado:** GuiaOverlay aparece flotando sobre TODAS las pantallas.

---

## Mapeo de Intenciones → Rutas

### En `BaqueanoIAService._obtenerRutaParaIntencion()` ✅

| Intención | Ruta |
|-----------|------|
| `tienda` | `/tienda` |
| `carrito` | `/carrito` |
| `perfil_pescador` / `activar_guia` | `/perfil` |
| `gps` / `crear_viaje` | `/mapa` |
| `notificaciones` | `/notificaciones` |
| `historial_viajes` | `/inicio` |

### En `ElGuiaEngine._generarRespuesta()` ✅

Rutas asignadas directamente en respuestas offline:
- ✅ `crear_viaje` → `rutaNavegacion: '/mapa'`
- ✅ `notificaciones` → `rutaNavegacion: '/notificaciones'`
- ✅ `perfil_pescador` → `rutaNavegacion: ruta ?? '/perfil'`
- ✅ `activar_guia` → `rutaNavegacion: '/perfil'`
- ✅ `carrito` → `rutaNavegacion: '/carrito'`
- ✅ `historial_viajes` → `rutaNavegacion: '/inicio'`
- ✅ `gps` / `tienda` → rutas desde librerías JSON (con fallbacks)

---

**BaqueanoIAService.responder()** implementa dos tiers:

```
Tier 1: Groq Cloud (si hay conexión)
        ↓ (si falla o no hay red)
Tier 2: ElGuiaEngine (motor offline)
        
Cada tier enriquece la respuesta con: _agregarRuta(resp, _obtenerRutaParaIntencion(intencion))
```

---

## Validación de Compilación ✅

```
✅ flutter analyze: 3189 issues (pre-existentes, ninguno nuevo introducido)
✅ No hay errores sintácticos en baqueano_ia_service.dart
✅ No hay errores sintácticos en el_guia_engine.dart
```

---

## Plan de Pruebas Manuales

### **Paso 1: Levantar la app**
```bash
cd c:\CapitanYA\capitan11.5.2026
flutter run --release
```
*(o en puerto 8080 si lo tienes configurado)*

### **Paso 2: Verificar que el overlay aparece**
✅ El robot flotante "GuiaOverlay" debe estar visible en la esquina inferior derecha (o donde esté posicionado).

### **Paso 3: Probar cada comando de voz/texto**

Abre la interfaz web o móvil y prueba:

| Comando | Intención Esperada | Navegación Esperada |
|---------|-------------------|---------------------|
| "Quiero ir a la tienda" | `tienda` | → `/tienda` |
| "Ver carrito" | `carrito` | → `/carrito` |
| "Mi perfil" | `perfil_pescador` | → `/perfil` |
| "Quiero pescar" o "crear viaje" | `crear_viaje` | → `/mapa` |
| "Ver historial" | `historial_viajes` | → `/inicio` |
| "Ver notificaciones" | `notificaciones` | → `/notificaciones` |
| "Activa la guía" | `activar_guia` | → `/perfil` |

### **Paso 4: Verificar logs en DevTools**
Busca en la consola (DevTools o logcat):
```
✅ [BaqueanoRouter] intent=tienda | offline_count=...
✅ [BaqueanoRouter] → GROQ ONLINE
✅ [BaqueanoRouter] intent=crear_viaje | offline_count=...
✅ [BaqueanoRouter] → MOTOR LOCAL (offline #1)
```

Desconecta la red y prueba:
- El robot debe seguir respondiendo
- Las rutas deben seguir funcionando
- Los logs deben mostrar `MOTOR LOCAL (offline #X)`

---

## Checklist de Implementación Final

- ✅ `ElGuiaRespuesta` tiene `rutaNavegacion`
- ✅ `GuiaOverlay` está en el `builder` de `MaterialApp`
- ✅ `_obtenerRutaParaIntencion()` mapea todas las intenciones
- ✅ `_agregarRuta()` enriquece respuestas correctamente
- ✅ Se llama `_agregarRuta()` en los tiers (Groq, Motor local)
- ✅ `ElGuiaEngine` asigna rutas en `_generarRespuesta()`
- ✅ Todos los `print()` reemplazados por `debugPrint()`
- ✅ No hay `contexto:` en llamadas a servicios
- ✅ `flutter analyze` sin nuevos errores

---

## Notas Técnicas

### GuiaOverlay
- Posicionado como `Stack` global en `MaterialApp.builder`
- Aparece encima de toda la UI pero por debajo de diálogos
- El robot se ve flotando en todas las pantallas

### Navegación
- Las rutas se pasan a través de `ElGuiaRespuesta.rutaNavegacion`
- El widget `guia_overlay.dart` o el chat deben leer este campo y disparar navegación
- Si no existe una ruta, la respuesta se muestra sin cambiar de pantalla

### Modo Offline
- Si Groq falla, se usa `ElGuiaEngine` automáticamente
- El caché de respuestas se reutiliza si está disponible
- Las intenciones se detectan localmente sin dependencia de red

---

**Estado**: ✅ LISTO PARA PRUEBAS  
**Última actualización**: 3 de Junio de 2026  
**Próximo paso**: Ejecutar `flutter run` y verificar en la interfaz web/móvil
