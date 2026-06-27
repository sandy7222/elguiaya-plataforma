

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/despertador_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/seguridad_service.dart';

class AsistenteElGuiaYaScreen extends StatefulWidget {
  const AsistenteElGuiaYaScreen({super.key});

  @override
  State<AsistenteElGuiaYaScreen> createState() => _AsistenteElGuiaYaScreenState();
}

class _AsistenteElGuiaYaScreenState extends State<AsistenteElGuiaYaScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatHistory = [];
  
  bool _isLoading = false;
  bool _isTyping = false;
  final String _usuarioId = 'usuario_demo';

  // Estado del despertador — se consulta al iniciar para que el Guia esté al tanto
  DespertadorEstado? _estadoDespertador;
  
  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _naranjaIntenso = Color(0xFFFF6600);

  @override
  void initState() {
    super.initState();
    DespertadorService.inicializar();
    _inicializarConversacion();
    _cargarEstadoDespertador();
  }

  Future<void> _cargarEstadoDespertador() async {
    final estado = await DespertadorService.estadoActual();
    if (mounted) setState(() => _estadoDespertador = estado);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _inicializarConversacion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener rol del usuario
      final usuario = await SeguridadService.getUsuarioPorId(_usuarioId);
      final rol = usuario?.rol ?? 'pescador';

      // Inicializar conversacion con el Asistente El Guia YA
      final response = await GeminiAIService.inicializarConversacion(
        usuarioId: _usuarioId,
        rol: rol,
      );

      _addMessageToChat('asistente', response.mensaje);
    } catch (e) {
      _addMessageToChat('asistente', '¡Hola! Soy el Asistente El Guia YA. ¿En que puedo ayudarte hoy?');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _messageController.clear();
    _addMessageToChat('usuario', message);

    // ─── DESPERTADOR: detección antes de Gemini ────────────────────────────
    if (DespertadorService.esCancelacionDespertador(message)) {
      await _cancelarDespertador();
      return;
    }
    if (DespertadorService.esPeticionDespertador(message)) {
      await _procesarDespertador(message);
      return;
    }
    // ──────────────────────────────────────────────────────────────────────

    setState(() { _isTyping = true; });

    try {
      final deteccion = await GeminiAIService.escanearFraudeChat(
        chatId: 'chat_$_usuarioId',
        usuarioId: _usuarioId,
        mensaje: message,
      );

      if (deteccion != null) {
        await GeminiAIService.generarReporteSeguridad(deteccion);
        _addMessageToChat('asistente',
          '⚠️ He detectado actividad sospechosa en tu mensaje. Por tu seguridad y la de los guías, '
          'te recomiendo mantener todas las transacciones dentro de la plataforma El Guia YA.');
        _registrarDeteccionFraude(deteccion);
      } else {
        final response = await GeminiAIService.chatGeneral(
          usuarioId: _usuarioId,
          mensaje: message,
          contextoChat: _chatHistory,
        );
        _addMessageToChat('asistente', response.mensaje);

        if (_messageContieneConsultaSobreGuias(message)) {
          _ofrecerRecomendacionActiva();
        }
      }
    } catch (e) {
      _addMessageToChat('asistente',
        'Disculpa, tuve un problema. ¿Podés reformular tu pregunta?');
    } finally {
      setState(() { _isTyping = false; });
    }
  }

  // ─── Procesar petición de despertador ──────────────────────────────────────
  Future<void> _procesarDespertador(String mensaje) async {
    setState(() { _isTyping = true; });

    try {
      final hora = DespertadorService.extraerHora(mensaje);

      if (hora == null) {
        // El Guia pide aclaración
        _addMessageToChat('asistente',
            '⏰ ¡Dale chamigo! ¿A qué hora querés que te despierte? '
            'Decime algo como "a las 6" o "a las 6:30" y te lo programo ahora.');
        return;
      }

      // Obtener el próximo viaje del usuario para la fecha
      DateTime fechaViaje = DateTime.now().add(const Duration(days: 1));
      String pedidoId = '';
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        if (uid.isNotEmpty) {
          final proximos = await Supabase.instance.client
              .from('pedidos')
              .select('id, cotizaciones(fecha_ida)')
              .eq('pescador_id', uid)
              .inFilter('estado', ['confirmado', 'pagado', 'programado'])
              .order('created_at', ascending: false)
              .limit(1);
          if (proximos is List && proximos.isNotEmpty) {
            pedidoId = proximos.first['id']?.toString() ?? '';
            final fi = proximos.first['cotizaciones']?['fecha_ida']?.toString();
            if (fi != null) fechaViaje = DateTime.tryParse(fi) ?? fechaViaje;
          }
        }
      } catch (_) {}

      final nombre = (await _getNombreUsuario()) ?? 'chamigo';
      final result = await DespertadorService.programar(
        hora:          hora,
        fechaViaje:    fechaViaje,
        nombreCliente: nombre,
        pedidoId:      pedidoId.isNotEmpty ? pedidoId : null,
      );

      if (result.exito) {
        final fechaFmt = '${fechaViaje.day}/${fechaViaje.month}';
        _addMessageToChat('asistente',
            '⏰ ¡Listo, $nombre! Te voy a despertar a las $hora del $fechaFmt.\n\n'
            '${result.mensaje}\n\n'
            '_Podés cancelar en cualquier momento diciéndome '
            '"cancelá el despertador" o "ya no me despiertes"._');
      } else {
        _addMessageToChat('asistente',
            '😅 No pude programar el despertador: ${result.errorMsg}. '
            'Intentá de nuevo con una hora válida.');
      }
    } catch (e) {
      _addMessageToChat('asistente',
          'Ups, tuve un problema para programar el despertador. Intentalo de vuelta.');
    } finally {
      setState(() { _isTyping = false; });
    }
  }

  // ─── Cancelar despertador ──────────────────────────────────────────────────
  Future<void> _cancelarDespertador() async {
    setState(() { _isTyping = true; });
    final cancelado = await DespertadorService.cancelar();
    setState(() { _isTyping = false; });

    if (cancelado) {
      _addMessageToChat('asistente',
          '✅ Listo chamigo, cancelé el despertador. '
          'Si querés volver a programarlo, avisame cuando quieras. 🌙');
    } else {
      _addMessageToChat('asistente',
          'No había ningún despertador programado, así que no hay nada que cancelar. '
          'Si querés que te despierte, pedímelo.');
    }
  }

  Future<String?> _getNombreUsuario() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return null;
      final p = await Supabase.instance.client
          .from('profiles')
          .select('nombre')
          .eq('user_id', uid)
          .maybeSingle();
      return p?['nombre']?.toString();
    } catch (_) { return null; }
  }

  bool _messageContieneConsultaSobreGuias(String message) {
    final palabrasClave = [
      'guia', 'guia', 'capitan', 'capitan', 'pesca', 
      'salida', 'viaje', 'excursion', 'disponible',
      'recomendacion', 'mejor', 'precio', 'costo'
    ];
    
    return palabrasClave.any((palabra) => 
      message.toLowerCase().contains(palabra));
  }

  Future<void> _ofrecerRecomendacionActiva() async {
    // Esperar un momento para simular procesamiento
    await Future.delayed(const Duration(seconds: 2));

    try {
      final response = await GeminiAIService.intervenirVentaActiva(
        pescadorId: _usuarioId,
        guiaId: 'guia_demo', // En produccion obtener del contexto
        contexto: 'explorando lista de guias',
      );

      _addMessageToChat('asistente', response.mensaje);
    } catch (e) {
      // Si falla, no mostrar error para no interrumpir experiencia
    }
  }

  void _registrarDeteccionFraude(DeteccionFraude deteccion) {
    // En produccion: enviar a Panel de Seguridad
    print('Deteccion de fraude registrada: ${deteccion.tipoViolacion}');
  }

  void _addMessageToChat(String role, String message) {
    setState(() {
      _chatHistory.add({
        'role': role,
        'message': message,
        'timestamp': DateTime.now(),
      });
    });

    // Hacer scroll hacia abajo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'usuario';
    final timestamp = message['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Avatar del Asistente El Guia YA
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _azulVibrante,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.anchor,
                color: _blancoPuro,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser 
                    ? _azulVibrante 
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser 
                      ? Colors.transparent 
                      : Colors.white.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Text(
                      'Asistente El Guia YA',
                      style: TextStyle(
                        color: _verdeBrillante,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message['message'],
                    style: TextStyle(
                      color: isUser ? _blancoPuro : _blancoPuro.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: (isUser ? _blancoPuro : _blancoPuro.withOpacity(0.6)),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            // Avatar del usuario
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _naranjaIntenso,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: _blancoPuro,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _azulVibrante,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.anchor,
              color: _blancoPuro,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Asistente El Guia YA esta escribiendo',
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_blancoPuro),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones rapidas',
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildQuickActionChip('Buscar guias', Icons.search),
              _buildQuickActionChip('Disponibilidad', Icons.calendar_today),
              _buildQuickActionChip('Precios', Icons.attach_money),
              _buildQuickActionChip('Ayuda', Icons.help),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: _blancoPuro),
      label: Text(
        label,
        style: TextStyle(
          color: _blancoPuro,
          fontSize: 12,
        ),
      ),
      backgroundColor: _azulVibrante.withOpacity(0.2),
      onPressed: () {
        _messageController.text = label;
        _sendMessage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _azulVibrante,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.anchor,
                color: _blancoPuro,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente El Guia YA',
                  style: TextStyle(
                    color: _blancoPuro,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tu experto en pesca',
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // Limpiar chat
              setState(() {
                _chatHistory.clear();
              });
              _inicializarConversacion();
            },
            icon: Icon(Icons.refresh, color: _blancoPuro),
          ),
        ],
      ),
      body: Column(
        children: [
          // Area de mensajes
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Conectando con Asistente El Guia YA...',
                          style: TextStyle(
                            color: _blancoPuro,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _chatHistory.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _chatHistory.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_chatHistory[index]);
                    },
                  ),
          ),
          
          // Acciones rapidas
          _buildQuickActions(),
          
          // Area de entrada
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: _blancoPuro),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: TextStyle(
                        color: _blancoPuro.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _azulVibrante,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.chat,
                        color: _blancoPuro.withOpacity(0.7),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _azulVibrante,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(
                      Icons.send,
                      color: _blancoPuro,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
