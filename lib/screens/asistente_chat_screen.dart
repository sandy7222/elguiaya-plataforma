

import 'package:flutter/material.dart';

import '../services/gemini_ai_service.dart';
import '../services/moderacion_service.dart';
import '../services/seguridad_service.dart';
import '../services/voice_service.dart';

class AsistenteChatScreen extends StatefulWidget {
  const AsistenteChatScreen({super.key});

  @override
  State<AsistenteChatScreen> createState() => _AsistenteChatScreenState();
}

class _AsistenteChatScreenState extends State<AsistenteChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatHistory = [];
  
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isListening = false;
  bool _isMuted = false;
  final String _usuarioId = 'usuario_demo'; // En produccion obtener del auth
  
  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    VoiceService().init();
    _inicializarConversacion();
    _iniciarMonitoreoSeguridad();
  }

  @override
  void dispose() {
    VoiceService().stop();
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
      VoiceService().speak(response.mensaje);
    } catch (e) {
      _addMessageToChat('asistente', '¡Hola! Soy el Asistente El Guia YA. ¿En que puedo ayudarte hoy?');
      VoiceService().speak('¡Hola! Soy el Asistente El Guia YA. ¿En qué puedo ayudarte hoy?');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _iniciarMonitoreoSeguridad() {
    // Iniciar monitoreo de seguridad en segundo plano
    ModeracionService.iniciarMonitoreo();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Limpiar campo de texto
    _messageController.clear();

    // Agregar mensaje del usuario al chat
    _addMessageToChat('usuario', message);

    // Mostrar indicador de escritura
    setState(() {
      _isTyping = true;
    });

    try {
      // Escanear mensaje en busca de fraude
      final deteccion = await GeminiAIService.escanearFraudeChat(
        chatId: 'chat_$_usuarioId',
        usuarioId: _usuarioId,
        mensaje: message,
      );

      if (deteccion != null) {
        // Generar reporte y mostrar advertencia
        final reporte = await GeminiAIService.generarReporteSeguridad(deteccion);
        
        // Mostrar advertencia al usuario
        _addMessageToChat('asistente', 
          '⚠️ He detectado actividad sospechosa en tu mensaje. Por tu seguridad y la de los guias, te recomiendo mantener todas las transacciones dentro de la plataforma El Guia YA. Esto te protege contra fraudes y garantiza un servicio de calidad.');
        VoiceService().speak('He detectado actividad sospechosa. Por tu seguridad, mantén las transacciones en la plataforma.');
        
        // Agregar reporte al sistema de moderacion
        _registrarDeteccionFraude(deteccion);
        
        // Si es severidad alta, mostrar advertencia adicional
        if (deteccion.severidad > 0.7) {
          _addMessageToChat('asistente',
            '🚨 **ADVERTENCIA IMPORTANTE**: He detectado un patron que podria violar nuestros terminos de servicio. Las transacciones fuera de la plataforma pueden resultar en perdida de proteccion, garantias y asistencia. Por favor, utiliza los canales oficiales de El Guia YA.');
          VoiceService().speak('Advertencia importante. Estás violando los términos de servicio. Por favor usa los canales oficiales.');
        }
      } else {
        // Chat normal con el Asistente El Guia YA
        final response = await GeminiAIService.chatGeneral(
          usuarioId: _usuarioId,
          mensaje: message,
          contextoChat: _chatHistory,
        );

        _addMessageToChat('asistente', response.mensaje);
        if (!_isMuted) VoiceService().speak(response.mensaje);

        // Si es sobre guias, ofrecer recomendacion activa
        if (_messageContieneConsultaSobreGuias(message)) {
          _ofrecerRecomendacionActiva();
        }
      }
    } catch (e) {
      _addMessageToChat('asistente', 
        'Disculpa, he tenido un problema. Soy el Asistente El Guia YA y estoy aqui para ayudarte. ¿Podrias reformular tu pregunta?');
      if (!_isMuted) VoiceService().speak('Disculpa, he tenido un problema. ¿Podrías reformular tu pregunta?');
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
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
      VoiceService().speak(response.mensaje);
    } catch (e) {
      // Si falla, no mostrar error para no interrumpir experiencia
    }
  }

  void _registrarDeteccionFraude(DeteccionFraude deteccion) {
    // El sistema de moderacion ya registra automaticamente
    // Solo mostramos feedback en consola para desarrollo
    print('Deteccion de fraude registrada: ${deteccion.tipoViolacion} (Severidad: ${deteccion.severidad})');
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
                  // Detectar y formatear mensajes con markdown
                  _buildFormattedMessage(message['message']),
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

  Widget _buildFormattedMessage(String message) {
    // Formateo simple de markdown
    final formattedText = message
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('⚠️', '⚠️ ')
        .replaceAll('🚨', '🚨 ');

    return Text(
      formattedText,
      style: TextStyle(
        color: _blancoPuro.withOpacity(0.9),
        fontSize: 14,
        height: 1.4,
      ),
    );
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
              _buildQuickActionChip('Seguridad', Icons.security),
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

  Widget _buildSecurityBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _verdeBrillante.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdeBrillante.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: _verdeBrillante, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este chat esta protegido por IA para prevenir fraudes y evasion de comisiones.',
              style: TextStyle(
                color: _verdeBrillante.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
                  '🛡️ Chat Seguro',
                  style: TextStyle(
                    color: _verdeBrillante,
                    fontSize: 10,
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
              setState(() {
                _isMuted = !_isMuted;
              });
              if (_isMuted) VoiceService().stop();
            },
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _blancoPuro),
          ),
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
          IconButton(
            onPressed: () {
              // Mostrar informacion de seguridad
              _showSecurityInfo();
            },
            icon: Icon(Icons.info, color: _verdeBrillante),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de seguridad
          _buildSecurityBanner(),
          
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: Implementar envio de foto a Gemini Vision para el Truco
                    },
                    icon: Icon(Icons.camera_alt, color: _blancoPuro),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: _blancoPuro),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje seguro...',
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
                      suffixIcon: Icon(
                        Icons.security,
                        color: _verdeBrillante,
                        size: 20,
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
                    color: _isListening ? Colors.red : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      if (_isListening) {
                        await VoiceService().stopListening();
                        setState(() { _isListening = false; });
                      } else {
                        setState(() { _isListening = true; });
                        await VoiceService().startListening((text, isFinal) {
                          setState(() {
                            _messageController.text = text;
                          });
                        });
                      }
                    },
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: _blancoPuro),
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

  void _showSecurityInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: _verdeBrillante),
            const SizedBox(width: 8),
            Text('Proteccion Activa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🛡️ Este chat esta protegido por:'),
            const SizedBox(height: 8),
            _buildSecurityItem('✅ Escaneo de fraude en tiempo real'),
            _buildSecurityItem('✅ Deteccion de evasion de comisiones'),
            _buildSecurityItem('✅ Alertas automaticas al administrador'),
            _buildSecurityItem('✅ Monitoreo 24/7 con IA'),
            const SizedBox(height: 12),
            Text('⚠️ No compartas informacion personal o realices pagos fuera de la plataforma.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          color: _blancoPuro.withOpacity(0.8),
          fontSize: 12,
        ),
      ),
    );
  }
}
