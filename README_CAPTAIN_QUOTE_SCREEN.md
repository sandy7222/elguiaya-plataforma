# 🚢 UI del Capitán - CaptainQuoteScreen

## 📱 Vista Mobile-First para Capitanes

He creado una interfaz completa y optimizada para capitanes con enfoque Mobile-First, perfecta para usar en exteriores con alta visibilidad.

## 🎯 Características Implementadas

### ✅ Scaffold Principal - CaptainQuoteScreen
- **Diseño Mobile-First** con scroll vertical
- **AppBar oscuro** con icono de barco
- **Navegación fluida** y responsive

### ✅ Widget de Mapa con Google Maps
- **Contenedor de 300px** optimizado para móviles
- **Marcador naranja** en punto de encuentro
- **Controles de zoom** y ubicación
- **Centrado automático** en el marcador

### ✅ Formulario de Cotización Numérico
- **TextField con keyboardType.number**
- **Presupuesto por defecto: $50.000**
- **Formateo de miles** automático
- **Validación completa** del monto

### ✅ Validación de Intermediario
- **Sin datos de contacto** del pescador
- **Solo nombre visible** (sin apellido ni teléfono)
- **Advertencia amarilla** sobre protección de datos
- **Mensajes informativos** anti-puenteo

### ✅ Estilo de Alto Contraste
- **Fondo oscuro** (#1A1A1A) para exteriores
- **Blanco puro** para texto principal
- **Colores vibrantes** (azul, verde, naranja, rojo)
- **Botones grandes** y fáciles de tocar

## 🎨 Paleta de Colores - Alto Contraste

```dart
// Colores optimizados para exteriores
static const Color _fondoOscuro = Color(0xFF1A1A1A);      // Fondo oscuro
static const Color _blancoPuro = Color(0xFFFFFFFF);        // Blanco puro
static const Color _azulVibrante = Color(0xFF0066FF);      // Azul vibrante
static const Color _verdeBrillante = Color(0xFF00FF00);     // Verde brillante
static const Color _naranjaIntenso = Color(0xFFFF6600);     // Naranja intenso
static const Color _rojoFuerte = Color(0xFFFF0000);          // Rojo fuerte
static const Color _amarilloVivo = Color(0xFFFFFF00);       // Amarillo vivo
```

## 📱 Estructura Mobile-First

```dart
SingleChildScrollView(
  child: Column(
    children: [
      _buildMapaContainer(),        // 🗺️ Mapa con marcador
      _buildInfoCotizacion(),       // 📋 Info del pescador (sin contacto)
      _buildFormularioPresupuesto(), // 💰 Formulario numérico
    ],
  ),
)
```

## 🗺️ Widget de Mapa

**Implementación con Google Maps:**

```dart
Container(
  height: 300, // Altura fija para móviles
  decoration: BoxDecoration(
    color: _blancoPuro,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _azulVibrante.withOpacity(0.3)),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
    ],
  ),
  child: GoogleMap(
    onMapCreated: (GoogleMapController controller) {
      _mapController = controller;
      _centrarMapaEnMarcador();
    },
    initialCameraPosition: CameraPosition(
      target: LatLng(lat, lng),
      zoom: 15,
    ),
    markers: _markers,
    myLocationEnabled: true,
    zoomControlsEnabled: true,
    mapType: MapType.normal,
  ),
)
```

**Marcador del punto de encuentro:**
```dart
_markers.add(
  Marker(
    markerId: MarkerId(widget.cotizacionId),
    position: LatLng(lat, lng),
    infoWindow: InfoWindow(
      title: 'Punto de Encuentro',
      snippet: 'Puerto de Mar del Plata',
    ),
    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
  ),
);
```

## 💰 Formulario de Cotización

**TextField numérico con validación:**

```dart
TextFormField(
  controller: _presupuestoController,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    ThousandsSeparatorInputFormatter(), // Formateo automático
  ],
  decoration: InputDecoration(
    labelText: 'Presupuesto (ARS)',
    prefixText: '\$',
    prefixStyle: TextStyle(color: _verdeBrillante, fontWeight: FontWeight.bold),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: _azulVibrante),
      borderRadius: BorderRadius.circular(8),
    ),
    filled: true,
    fillColor: _blancoPuro,
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, ingresa el presupuesto';
    }
    final monto = double.tryParse(value.replaceAll(',', ''));
    if (monto == null || monto <= 0) {
      return 'El presupuesto debe ser mayor a 0';
    }
    if (monto < 10000) {
      return 'El presupuesto mínimo es $10.000';
    }
    return null;
  },
)
```

**Presupuesto por defecto:**
```dart
@override
void initState() {
  super.initState();
  _presupuestoController.text = '50000'; // $50.000 por defecto
  _cargarCotizacion();
}
```

## 🛡️ Validación de Intermediario

**Protección anti-puenteo:**

```dart
// Solo mostramos el nombre del pescador
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: _fondoOscuro,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Pescador:', style: TextStyle(color: _blancoPuro, fontWeight: FontWeight.bold)),
      Text(cotizacion['pescador_nombre'], style: TextStyle(color: _blancoPuro)),
      
      // Advertencia de protección
      Row(
        children: [
          Icon(Icons.info_outline, color: _amarilloVivo, size: 16),
          Expanded(
            child: Text(
              'Los datos de contacto están protegidos para evitar el puenteo del negocio',
              style: TextStyle(color: _amarilloVivo, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    ],
  ),
)
```

**En el servicio backend:**
```dart
// NOTA: No incluimos apellido ni teléfono (protección anti-puenteo)
final response = await supabase
    .from('cotizaciones')
    .select('''
      *,
      profiles!inner(
        user_id,
        nombre
        -- NOTA: No incluimos apellido ni teléfono del pescador
      )
    ''');
```

## 🎨 Estilo de Alto Contraste para Exteriores

**Diseño optimizado para usar al aire libre:**

```dart
Scaffold(
  backgroundColor: _fondoOscuro, // Fondo oscuro
  appBar: AppBar(
    backgroundColor: _fondoOscuro,
    foregroundColor: _blancoPuro, // Texto blanco brillante
    elevation: 0,
  ),
  body: SingleChildScrollView(
    child: Column(
      children: [
        // Cards con bordes vibrantes
        Container(
          decoration: BoxDecoration(
            color: _blancoPuro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _azulVibrante.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
            ],
          ),
        ),
        
        // Botón verde brillante
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _verdeBrillante,
            foregroundColor: _blancoPuro,
            elevation: 4,
          ),
          child: Text('Enviar Presupuesto'),
        ),
      ],
    ),
  ),
)
```

## 📱 Vista Previa del Diseño Móvil

**Así se ve la pantalla en un celular estándar:**

```
┌─────────────────────────────────┐
│  🔙 Cotización                   │
├─────────────────────────────────┤
│  🗺️ Mapa (300px)                 │
│     📍 Marcador naranja          │
│     🔍 Controles de zoom         │
├─────────────────────────────────┤
│  📋 Detalles de la Cotización     │
│  ┌─────────────────────────────┐ │
│  │ 🌑 Pescador:                 │ │
│  │ Pescador Test                │ │
│  │ ⚠️ Datos protegidos          │ │
│  └─────────────────────────────┘ │
│  📅 15/03/2026   ⏰ 08:00      │
│  👥 4 personas                 │
│  📍 Puerto de Mar del Plata      │
├─────────────────────────────────┤
│  💰 Formulario de Presupuesto     │
│  ┌─────────────────────────────┐ │
│  │ $50,000                    │ │
│  │ (formateado automáticamente) │ │
│  └─────────────────────────────┘ │
│  📝 Mensaje para el Pescador     │
│  ┌─────────────────────────────┐ │
│  │ [Campo de texto 3 líneas]   │ │
│  └─────────────────────────────┘ │
│  ℹ️ • El presupuesto será visible│
│     • Tu mensaje será enviado   │
│     • Datos protegidos          │
│     • No compartas info personal│
│  ┌─────────────────────────────┐ │
│  │ 🟢 Enviar Presupuesto        │ │
│  │ (56px de alto)                │ │
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## 🔧 Características Técnicas

### Mobile-First
- **Scroll vertical** para pantallas pequeñas
- **Botones de 56px** para fácil tacto
- **Padding adecuado** entre elementos
- **Texto legible** sin necesidad de zoom

### Validación Completa
- **Presupuesto mínimo**: $10.000
- **Formato numérico** con separadores de miles
- **Mensaje obligatorio** para el pescador
- **Feedback visual** en tiempo real

### Protección Anti-Puenteo
- **Sin teléfono** del pescador
- **Sin apellido** del pescador
- **Advertencias visuales** sobre protección
- **Validación backend** de datos expuestos

### Alto Contraste
- **Fondo oscuro** para exteriores soleados
- **Texto blanco brillante** para máxima legibilidad
- **Colores vibrantes** para botones importantes
- **Sombras profundas** para mejor contraste

## 🚀 Métodos del Servicio

**Nuevos métodos agregados a SupabaseService:**

```dart
// Actualizar cotización con respuesta del capitán
static Future<void> actualizarCotizacionConRespuesta(
  String cotizacionId,
  double presupuesto,
  String respuesta,
);

// Obtener cotizaciones para el capitán (sin contacto)
static Future<List<Map<String, dynamic>>> getCotizacionesCapitan(String capitanId);

// Obtener detalles de cotización (sin datos de contacto)
static Future<Map<String, dynamic>> getDetallesCotizacionCapitan(String cotizacionId);

// Verificar si puede ver contacto
static Future<bool> verificarContactoHabilitadoParaCapitan(String cotizacionId);
```

## 📦 Dependencias Requeridas

**Agregar a pubspec.yaml:**

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.5.0
  supabase_flutter: ^2.0.0
  # ... otras dependencias
```

## 🎯 Uso Práctico

**Para usar la pantalla:**

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CaptainQuoteScreen(
      cotizacionId: 'uuid-de-la-cotizacion',
    ),
  ),
);
```

**Flujo del capitán:**
1. **Ver mapa** con punto de encuentro
2. **Revisar detalles** (sin contacto del pescador)
3. **Ingresar presupuesto** (por defecto $50.000)
4. **Escribir mensaje** para el pescador
5. **Enviar presupuesto** y volver al panel

## 🎉 Características Destacadas

- ✅ **Mobile-First** optimizado para exteriores
- ✅ **Mapa interactivo** con marcador naranja
- ✅ **Formulario numérico** con $50.000 por defecto
- ✅ **Protección anti-puenteo** completa
- ✅ **Alto contraste** para máxima visibilidad
- ✅ **Validación completa** de datos
- ✅ **Botones grandes** y fáciles de tocar
- ✅ **Feedback visual** en tiempo real

**La interfaz está lista para usar y ofrece una experiencia perfecta para capitanes trabajando en exteriores con alta visibilidad y protección completa del negocio.**
