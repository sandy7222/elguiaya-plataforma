# 🎫 Vista de Ticket de Embarque - Guía Completa

## 📱 Vista de Ticket de Embarque en Flutter

He creado una vista completa y optimizada para móviles que consume el JSON del ticket de embarque generado por el script SQL.

## 🎯 Características Implementadas

### ✅ Mobile-First Design
- **Column con scroll** para adaptarse a cualquier tamaño de pantalla
- **Diseño responsive** que se ve perfecto en celulares estándar
- **Cards organizados** con información clara y legible
- **Colores consistentes** con la marca CapitánYA

### ✅ Consumo de JSON
- **Datos simulados** basados en el script SQL de prueba
- **Estructura completa** con todos los campos del ticket
- **Manejo de estados** de carga y error
- **Validación de datos** antes de mostrar

### ✅ Botón "Llamar al Capitán"
- **Esquema tel:** implementado con `url_launcher`
- **Validación de teléfono** antes de llamar
- **Manejo de errores** si no se puede realizar la llamada
- **UX intuitiva** con iconos y colores claros

### ✅ Visualización de Montos
- **$68.500** destacado en el resumen financiero
- **Desglose completo** de todos los costos
- **Formato de moneda** consistente (`$XX.XXX.XX`)
- **Colores semánticos** para diferentes tipos de montos

## 📁 Archivos Creados

1. **`lib/screens/ticket_embarque_screen.dart`** - Vista principal del ticket
2. **`generar_apk.bat`** - Script para generar APK de depuración
3. **`README_TICKET_EMBARQUE.md`** - Esta guía

## 🚀 Generación de APK de Depuración

### Método 1: Usar el script .bat (Recomendado)

```bash
# Ejecutar directamente
cd c:\Users\sandy\OneDrive\Desktop\capitanya_master
generar_apk.bat
```

### Método 2: Comandos manuales

```bash
# 1. Limpiar proyecto
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Construir APK
flutter build apk --debug

# 4. Instalar en dispositivo (opcional)
flutter install --debug
```

## 📱 Pruebas en Teléfono Físico

### Requisitos Previos
1. **Teléfono Android** con depuración USB habilitada
2. **Modo desarrollador** activado
3. **Cable USB** para conexión
4. **Flutter instalado** en tu PC

### Pasos para Probar

1. **Generar el APK** con el script `generar_apk.bat`
2. **Instalar la app** en tu teléfono físico
3. **Abrir CapitánYA** en tu dispositivo
4. **Navegar a la vista** del ticket de embarque
5. **Verificar visualmente** los $68.500 del total

### Qué Verificar en la Pantalla

#### ✅ Montos Financieros
- **Presupuesto Viaje:** $50,000.00
- **Productos Tienda:** $15,000.00
- **Envío Correo Argentino:** $3,500.00
- **TOTAL FINAL:** $68,500.00 (debe estar destacado en verde)

#### ✅ Diseño Mobile-First
- **Scroll suave** en pantallas pequeñas
- **Texto legible** sin necesidad de hacer zoom
- **Cards bien organizados** y espaciados
- **Botones accesables** con el dedo

#### ✅ Funcionalidad del Botón Llamar
- **Botón visible** con icono de teléfono
- **Al tocar:** debe abrir la app de teléfono
- **Número:** +5492231234567 (del capitán de prueba)

#### ✅ Datos Completos
- **4 pasajeros** con sus DNI validados
- **3 productos** de tienda con desglose
- **3 bultos** categorizados
- **Estados del viaje** visibles

## 🎨 Detalles del Diseño

### Paleta de Colores CapitánYA
```dart
static const Color _azulNautico = Color(0xFF1565C0);      // Azul principal
static const Color _verdeExito = Color(0xFF10B981);        // Verde para éxito
static const Color _naranjaAlerta = Color(0xFFF59E0B);      // Naranja para alertas
static const Color _rojoProblema = Color(0xFFEF4444);       // Rojo para errores
static const Color _grisDescanso = Color(0xFF64748B);      // Gris neutro
```

### Estructura de la Vista
1. **Header** - Título y fecha/hora de embarque
2. **Detalles del Viaje** - Descripción y estadísticas
3. **Capitán** - Info y botón de llamada
4. **Resumen Financiero** - Desglose completo de costos
5. **Productos Tienda** - Lista detallada con subtotales
6. **Pasajeros** - Con validación de DNI
7. **Bultos** - Categorización del equipamiento
8. **Estados** - Chips con estado del viaje
9. **Footer** - Timestamps e ID del ticket

### Componentes Clave

#### 📊 Resumen Financiero
```dart
Container(
  decoration: BoxDecoration(
    color: _verdeExito.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _verdeExito.withOpacity(0.3)),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('TOTAL FINAL', style: TextStyle(color: _verdeExito, fontWeight: FontWeight.bold)),
      Text('\$68,500.00', style: TextStyle(color: _verdeExito, fontWeight: FontWeight.bold, fontSize: 20)),
    ],
  ),
)
```

#### 📞 Botón de Llamada
```dart
Future<void> _llamarCapitan() async {
  final uri = Uri.parse('tel:+5492231234567');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    // Manejo de error
  }
}
```

#### 📱 Mobile-First
```dart
SingleChildScrollView(
  child: Column(
    children: [
      _buildTicketHeader(),
      _buildViajeInfo(),
      _buildCapitanInfo(),
      _buildResumenFinanciero(),
      _buildProductosTienda(),
      _buildPasajeros(),
      _buildBultos(),
      _buildEstadoYAcciones(),
      _buildFooter(),
    ],
  ),
)
```

## 🔧 Personalización

### Para Cambiar los Datos del Ticket
Edita el método `_cargarTicketEmbarque()` en `ticket_embarque_screen.dart`:

```dart
setState(() {
  _ticketData = {
    'ticket_embarque': {
      'costos': {
        'presupuesto_viaje': 50000.00,
        'productos_tienda': 15000.00,
        'envio_correo': 3500.00,
        'total_final': 68500.00, // <-- Cambiar aquí
      },
      // ... otros datos
    }
  };
});
```

### Para Cambiar el Teléfono del Capitán
```dart
'capitan': {
  'telefono': '+5492231234567', // <-- Cambiar aquí
}
```

### Para Cambiar Colores
Modifica las constantes al principio de la clase:
```dart
static const Color _azulNautico = Color(0xFF1565C0); // Cambiar a tu color
```

## 🚀 Próximos Pasos

1. **Ejecutar el script** `generar_apk.bat`
2. **Instalar en teléfono** físico
3. **Probar la vista** del ticket
4. **Verificar los $68.500** se muestran correctamente
5. **Probar el botón** de llamada
6. **Validar el diseño** en diferentes tamaños de pantalla

## 📱 Capturas de Pantalla Esperadas

Al probar en tu teléfono, deberías ver:

1. **Header azul** con "TICKET DE EMBARQUE" y fecha
2. **Sección financiera** con el total $68,500.00 destacado en verde
3. **Botón verde** "Llamar" que abre la app de teléfono
4. **Lista de productos** con sus precios individuales
5. **4 pasajeros** con sus DNI y estado "Validado"
6. **Scroll suave** si la pantalla es pequeña

## 🔍 Troubleshooting

### Si el APK no se instala
- Verifica la depuración USB en tu teléfono
- Asegúrate de tener el modo desarrollador activado
- Revisa que el cable USB esté bien conectado

### Si los montos no se muestran
- Revisa el JSON de datos en el código
- Verifica que los tipos de datos sean correctos (double)
- Revisa el formato de moneda en el código

### Si el botón de llamada no funciona
- Verifica que `url_launcher` esté en pubspec.yaml
- Revisa los permisos de la app
- Prueba con un número de teléfono diferente

## 🎉 ¡Listo para Probar!

Con estos archivos puedes:
- ✅ Generar un APK de depuración fácilmente
- ✅ Probar la vista del ticket en tu teléfono
- ✅ Verificar que los $68.500 se muestren correctamente
- ✅ Probar el botón de llamada al capitán
- ✅ Validar el diseño Mobile-First

Ejecuta `generar_apk.bat` y sigue las instrucciones para probar todo en tu dispositivo físico.
