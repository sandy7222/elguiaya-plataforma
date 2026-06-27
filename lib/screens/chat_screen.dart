import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';
import '../services/voice_service.dart'; // 🔊 IMPORTAMOS EL NUEVO SERVICIO DE VOZ
import '../services/viaje_lifecycle_service.dart';
import 'confirmar_finalizacion_screen.dart';

class ChatScreen extends StatefulWidget {
  final String reservaId;
  final String? nombreServicio;
  final String? nombreCliente;
  final String? mensajeInicial;

  const ChatScreen({
    super.key,
    required this.reservaId,
    this.nombreServicio,
    this.nombreCliente,
    this.mensajeInicial,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  String _tipoEmisorActual = 'pescador';

  // Real database connection states
  Map<String, dynamic>? _viajeInfo;
  bool _loadingViaje = true;
  bool _hasPassed = false;
  bool _isPaid = false;

  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _grisMedio = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    if (widget.mensajeInicial != null && widget.mensajeInicial!.trim().isNotEmpty) {
      _messageController.text = widget.mensajeInicial!.trim();
    }
    VoiceService().init();
    _cargarInfoViaje();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    VoiceService().stop(); // 🛑 Frenamos la voz si el usuario sale del chat
    super.dispose();
  }

  Future<void> _cargarInfoViaje() async {
    try {
      final response = await Supabase.instance.client
          .from('pedidos')
          .select('*, budgets:presupuestos(*)')
          .eq('id', widget.reservaId)
          .maybeSingle();

      if (response != null && mounted) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final pescadorId = response['pescador_id'];
        final capitanId = response['capitan_id'];

        String tipo = 'pescador';
        if (currentUserId == capitanId) {
          tipo = 'capitan';
        } else if (currentUserId == pescadorId) {
          tipo = 'pescador';
        } else {
          tipo = 'admin';
        }

        final String fechaServicioStr = response['fecha_servicio']?.toString() ?? '';
        bool passed = false;
        if (fechaServicioStr.isNotEmpty) {
          final DateTime dateServicio = DateTime.parse(fechaServicioStr);
          final DateTime endOfServiceDay = DateTime(dateServicio.year, dateServicio.month, dateServicio.day).add(const Duration(days: 1));
          passed = DateTime.now().isAfter(endOfServiceDay);
        }

        setState(() {
          _viajeInfo = response;
          _tipoEmisorActual = tipo;
          _isPaid =
              ViajeLifecycleService.esEstadoPagado(response['estado']?.toString());
          _hasPassed = passed;
          _loadingViaje = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _loadingViaje = false;
          });
        }
      }
    } catch (e) {
      print('Error al cargar info de viaje: $e');
      if (mounted) {
        setState(() {
          _loadingViaje = false;
        });
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _getMensajesStream() {
    return Supabase.instance.client
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('reserva_id', widget.reservaId)
        .order('creado_at', ascending: false);
  }

  Future<void> _enviarMensaje() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty) return;

    // =========================================================
    // 📡 INTERCEPTOR DE COMANDOS CRUCIAL (Navegación al Instante)
    // =========================================================
    final textoLimpio = texto.toLowerCase().trim();

    // 🗺️ 1. MAPA SATELITAL
    if (textoLimpio == 'mapa' ||
        textoLimpio.contains('ver mapa') ||
        textoLimpio == 'ver mapa') {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/mapa');
      return;
    }

    // 🛒 2. PORTADA DE LA TIENDA
    if (textoLimpio == 'tienda' ||
        textoLimpio.contains('ir a la tienda') ||
        textoLimpio == 'tienda oficial' ||
        textoLimpio.contains('dirígeme a la tienda') ||
        textoLimpio.contains('dirigeme a la tienda')) {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/tienda');
      return;
    }

    // 📋 3. FORMULARIO DE COTIZACIÓN DE VIAJE
    if (textoLimpio == 'cotización de viaje' ||
        textoLimpio == 'cotizacion de viaje' ||
        textoLimpio.contains('pedir viaje') ||
        textoLimpio.contains('formulario de cotización') ||
        textoLimpio.contains('formulario de cotizacion')) {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/cotizacion_formulario');
      return;
    }

    // 📥 4. BANDEJA DE NOTIFICACIONES
    if (textoLimpio == 'notificaciones' ||
        textoLimpio.contains('ver notificaciones') ||
        textoLimpio.contains('bandeja de notificaciones')) {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/notificaciones');
      return;
    }

    // 💵 5. HISTORIAL DE COTIZACIONES Y PRESUPUESTOS
    if (textoLimpio == 'cotizaciones' ||
        textoLimpio.contains('ver cotizaciones') ||
        textoLimpio.contains('mis cotizaciones') ||
        textoLimpio == 'presupuesto' ||
        textoLimpio.contains('ver presupuesto')) {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/cotizaciones');
      return;
    }
    // =========================================================

    final String emisorId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (emisorId.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await Supabase.instance.client.from('mensajes').insert({
        'reserva_id': widget.reservaId,
        'emisor_id': emisorId,
        'texto': texto,
        'tipo_emisor': _tipoEmisorActual,
        'leido': false,
      });
      _messageController.clear();
      _focusNode.unfocus();
    } catch (e) {
      print('Error al enviar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar mensaje: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  Widget _buildMessageBubbleReal(String texto, bool esMio, DateTime creadoAt) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _grisMedio,
              child: const Icon(Icons.sailing, color: _blancoPuro, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: esMio ? _azulVibrante : _grisMedio,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    texto,
                    style: const TextStyle(color: _blancoPuro, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(creadoAt),
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (esMio) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _azulVibrante,
              child: const Icon(Icons.person, color: _blancoPuro, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.nombreCliente ?? 'Tripulación';
    final subtitle = _hasPassed 
        ? '${widget.nombreServicio ?? 'Chat de Viaje'} - CHAT CERRADO'
        : widget.nombreServicio ?? 'Chat de Viaje';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        border: Border(bottom: BorderSide(color: _blancoPuro.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: _blancoPuro),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _hasPassed ? _grisMedio : _azulVibrante,
            child: Icon(
              _hasPassed ? Icons.lock : Icons.sailing, 
              color: _blancoPuro, 
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _blancoPuro,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _hasPassed ? Colors.redAccent : _verdeBrillante,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    if (!_isPaid) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          border: Border(top: BorderSide(color: _blancoPuro.withOpacity(0.2))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'El chat está bloqueado hasta que se confirme el pago.',
                style: TextStyle(
                  color: _blancoPuro.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasPassed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          border: Border(top: BorderSide(color: _blancoPuro.withOpacity(0.2))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El chat de este viaje ha finalizado.',
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_tipoEmisorActual == 'pescador') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConfirmarFinalizacionScreen(),
                      ),
                    ).then((_) => _cargarInfoViaje());
                  },
                  icon: const Icon(Icons.star_rate_rounded, color: Colors.black87),
                  label: const Text(
                    'CALIFICAR EXPERIENCIA',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        border: Border(top: BorderSide(color: _blancoPuro.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              style: const TextStyle(color: _blancoPuro),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: TextStyle(color: _blancoPuro.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: _azulVibrante,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _enviarMensaje,
              icon: const Icon(Icons.send, color: _blancoPuro),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingViaje) {
      return const Scaffold(
        backgroundColor: _fondoOscuro,
        body: Center(
          child: CircularProgressIndicator(color: _azulVibrante),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fondoOscuro,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMensajesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _azulVibrante));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar mensajes: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final mensajes = snapshot.data ?? [];

                if (mensajes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: _blancoPuro.withOpacity(0.3), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No hay mensajes aún.\n¡Inicia la conversación!',
                          style: TextStyle(color: _blancoPuro.withOpacity(0.5)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final String emisorId = msg['emisor_id']?.toString() ?? '';
                    final String texto = msg['texto']?.toString() ?? '';
                    final DateTime creadoAt = msg['creado_at'] != null 
                        ? DateTime.parse(msg['creado_at'].toString()) 
                        : DateTime.now();

                    final bool esMio = emisorId == Supabase.instance.client.auth.currentUser?.id;

                    return _buildMessageBubbleReal(texto, esMio, creadoAt);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
