$filePath = "lib/screens/chat_asistido_screen.dart"
$content = Get-Content $filePath -Raw

# Bloque nuevo de código con la lógica optimizada y rutas sincronizadas con main.dart
$newFunction = @'
  Future<void> _enviarMensaje() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty) return;

    final textoLimpio = texto.toLowerCase().trim();

    // =========================================================
    // 📡 INTERCEPTOR DE COMANDOS CALIBRADO CON MAIN.DART
    // =========================================================

    // 🗺️ A. MAPA SATELITAL
    if (textoLimpio == 'mapa' || textoLimpio.contains('ver mapa') || textoLimpio.contains('satelital')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/mapa');
      return;
    }

    // 🛒 B. PORTADA DE LA TIENDA
    if (textoLimpio == 'tienda' || textoLimpio.contains('ir a la tienda') || textoLimpio.contains('productos')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/tienda');
      return;
    }

    // 📥 C. BANDEJA DE NOTIFICACIONES
    if (textoLimpio == 'notificaciones' || textoLimpio.contains('ver notificaciones') || textoLimpio.contains('avisos')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/notificaciones');
      return;
    }

    // 📋 D. FORMULARIO / GESTIÓN DE VIAJE
    if (textoLimpio.contains('viaje') || textoLimpio.contains('pedir viaje') || textoLimpio.contains('formulario')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/admin/viajes');
      return;
    }

    // 💵 E. PRESUPUESTOS / PEDIDOS / COTIZACIONES
    if (textoLimpio.contains('presupuesto') || textoLimpio.contains('cotizacion') || textoLimpio.contains('cotización') || textoLimpio.contains('pedidos')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/admin/pedidos');
      return;
    }

    // 👤 F. INFORMACIÓN DEL USUARIO / PERFIL
    if (textoLimpio.contains('usuario') || textoLimpio.contains('perfil') || textoLimpio.contains('mi info') || textoLimpio.contains('editar')) {
      _messageController.clear(); _focusNode.unfocus();
      Navigator.pushNamed(context, '/perfil');
      return;
    }
    // =========================================================

    setState(() {
      _isSending = true;
      _mensajesSimulados.insert(0, Mensaje(
        id: DateTime.now().toString(),
        reservaId: widget.reservaId,
        emisorId: 'usuario_pescador_prueba',
        texto: texto,
        tipoEmisor: 'pescador',
        creadoAt: DateTime.now(),
        leido: true,
      ));
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          String respuestaBot = "Copiado, chamigo. Analizando el rumbo en el Paraná.";

          if (textoLimpio.contains('pesca') || textoLimpio.contains('dorado')) {
            respuestaBot = "Para el dorado en la corredera, metele señuelo de paleta larga y tiralo donde el agua remansa, chamigo.";
          } else if (textoLimpio.contains('raya') || textoLimpio.contains('picadura')) {
            respuestaBot = "Alerta: Introduce el pie herido en agua caliente para neutralizar el veneno de la raya. No cortes la herida.";
          } else if (textoLimpio.contains('bagre')) {
            respuestaBot = "El bagre amarillo busca el barro hondo, chamigo. Encarná con lombriz gorda o coluda y plomada pesada para aguantar la correntada.";
          } else if (textoLimpio.contains('hola') || textoLimpio.contains('buenas')) {
            respuestaBot = "¡Hola chamigo! Soy El GuIA, tu robot baqueano. Listo para navegar el Paraná. ¿Qué data estás necesitando?";
          }

          _mensajesSimulados.insert(0, Mensaje(
            id: DateTime.now().toString(),
            reservaId: widget.reservaId,
            emisorId: 'el_guia_bot',
            texto: respuestaBot,
            tipoEmisor: 'capitan',
            creadoAt: DateTime.now(),
            leido: false,
          ));
        });
      }
    });

    _messageController.clear();
    _focusNode.unfocus();

    setState(() {
      _isSending = false;
    });
  }
'@

# Expresión regular para barrer de forma milimétrica el _enviarMensaje anterior
$pattern = "(?s)Future<void> _enviarMensaje\(\) async \{.*?setState\(\{.*?_isSending = false;.*?\);.*?\}"
$content = $content -replace $pattern, $newFunction

Set-Content -Path $filePath -Value $content -Encoding utf8
Write-Host "🚀 ¡Función reestructurada e inyectada por el agente sin errores!" -ForegroundColor Green
