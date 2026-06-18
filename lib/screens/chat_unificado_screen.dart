import 'package:flutter/material.dart';
import '../services/baqueano_ia_service.dart';
import '../services/voice_service.dart';
import '../services/connectivity_bridge.dart';
import '../services/ia_router_state.dart';
import '../widgets/guia_overlay.dart';

/// Chat unificado con El Guía — único punto de entrada para el usuario.
///
/// No depende de `reservaId` ni de Supabase. Es una conversación efímera
/// en memoria con el bot, donde [BaqueanoIAService] enruta automáticamente
/// al motor de IA disponible (Cloud → Local → Offline).
class ChatUnificadoScreen extends StatefulWidget {
  const ChatUnificadoScreen({super.key});

  @override
  State<ChatUnificadoScreen> createState() => _ChatUnificadoScreenState();
}

class _ChatUnificadoScreenState extends State<ChatUnificadoScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];

  bool _isSending = false;
  bool _isListening = false;

  // Animación del mic
  late AnimationController _micPulseController;
  late Animation<double> _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _micPulse = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );

    // Saludo inicial
    _messages.add(_ChatMsg(
      text: '¡Hola chamigo! Soy El Guía 🎣 Preguntame lo que quieras sobre pesca, viajes, la tienda o lo que necesites.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    if (_isListening) {
      VoiceService().stopListening();
    }
    super.dispose();
  }

  void _scrollToBottom() {
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

  Future<void> _enviarMensaje([String? textoOverride]) async {
    final texto = (textoOverride ?? _inputController.text).trim();
    if (texto.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMsg(text: texto, isUser: true, timestamp: DateTime.now()));
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    // Detener escucha si estaba activa
    if (_isListening) {
      await VoiceService().stopListening();
      setState(() => _isListening = false);
    }

    try {
      final respuesta = await BaqueanoIAService.responder(texto);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            text: respuesta.texto,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();

        // Voz (si no está silenciado)
        if (!GuiaOverlayController.silenciado.value) {
          VoiceService().speak(respuesta.texto);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            text: 'Uh, se me trabó el motor. ¿Me repetís la pregunta?',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _toggleMic() async {
    final micActivo = GuiaOverlayController.micActivo.value;
    if (!micActivo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🤖 Chamigo, tenés que activar los Comandos por Voz en tus Ajustes de Perfil.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            backgroundColor: Color(0xFF001F3F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_isListening) {
      await VoiceService().stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await VoiceService().startListening((recognizedText, isFinal) {
        if (!mounted) return;
        setState(() => _inputController.text = recognizedText);
        if (isFinal && recognizedText.trim().isNotEmpty) {
          _enviarMensaje(recognizedText);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF001529), Color(0xFF001F3F)],
        ),
      ),
      child: Column(
        children: [
          // ── Header del chat ─────────────────────────────────
          _buildChatHeader(),

          // ── Mensajes ────────────────────────────────────────
          Expanded(child: _buildMessageList()),

          // ── Indicador de pensando ───────────────────────────
          if (_isSending) _buildThinkingIndicator(),

          // ── Barra de input ──────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00E676).withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar del guía
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El Guía',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                ValueListenableBuilder<IAEstado>(
                  valueListenable: IARouterState.estado,
                  builder: (_, estado, __) {
                    final label = switch (estado) {
                      IAEstado.accionDirecta => '⚡ Acción directa',
                      IAEstado.navegacion => '🗺️ Navegación asistida',
                      IAEstado.cloud => '🟢 Groq Cloud activo',
                      IAEstado.offline => '🟡 Modo offline',
                      IAEstado.contingencia => '🔴 Modo contingencia',
                    };
                    return Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Botón de silenciar voz
          ValueListenableBuilder<bool>(
            valueListenable: GuiaOverlayController.silenciado,
            builder: (_, muted, __) {
              return IconButton(
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: muted ? Colors.white38 : const Color(0xFF00E676),
                  size: 20,
                ),
                tooltip: muted ? 'Activar voz' : 'Silenciar',
                onPressed: () => GuiaOverlayController.setSilenciado(!muted),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Iniciá una conversación con El Guía',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildBubble(msg);
      },
    );
  }

  Widget _buildBubble(_ChatMsg msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF0066FF).withOpacity(0.85)
              : const Color(0xFF0D1B3E).withOpacity(0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  width: 0.8,
                ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? const Color(0xFF0066FF) : const Color(0xFF00E676))
                  .withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF00E676).withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'El Guía está pensando...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding > 0 ? bottomPadding + 8 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF001529).withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botón de micrófono
            AnimatedBuilder(
              animation: _micPulse,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _micPulse.value : 1.0,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _toggleMic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.redAccent.withOpacity(0.2)
                        : const Color(0xFF00E676).withOpacity(0.1),
                    border: Border.all(
                      color: _isListening
                          ? Colors.redAccent
                          : const Color(0xFF00E676).withOpacity(0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isListening ? Colors.redAccent : const Color(0xFF00E676),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _isListening ? 'Escuchando...' : 'Preguntale al Guía...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón enviar
            _isSending
                ? Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF00E676).withOpacity(0.7),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _enviarMensaje(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Modelo interno para un mensaje del chat.
class _ChatMsg {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMsg({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
