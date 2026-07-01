import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';
import '../services/intent_service.dart'; // El cable para las intenciones de navegación por voz/texto
import '../services/voz_service.dart'; // ?? IMPORTAMOS EL NUEVO SERVICIO DE VOZ

class ChatScreenSimple extends StatefulWidget {
  final String reservaId;
  final String? nombreServicio;
  final String? nombreCliente;

  const ChatScreenSimple({
    super.key,
    required this.reservaId,
    this.nombreServicio,
    this.nombreCliente,
  });

  @override
  State<ChatScreenSimple> createState() => _ChatScreenSimpleState();
}

class _ChatScreenSimpleState extends State<ChatScreenSimple> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final bool _isLoading = false;
  bool _isSending = false;
  Map<String, dynamic>? _reservaInfo;
  String _tipoEmisorActual = 'pescador';

  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _grisMedio = Color(0xFF666666);

  // Lista local simulada para que puedas testear la voz y el chat sin Supabase
  final List<Mensaje> _mensajesSimulados = [
    Mensaje(
      id: '1',
      reservaId: 'test',
      emisorId: 'el_guia_bot',
      texto:
          '¡Hola chamigo! Soy El GuIA, tu robot baqueano. ¿En qué te puedo ayudar hoy en el río?',
      tipoEmisor: 'capitan',
      creadoAt: DateTime.now().subtract(const Duration(minutes: 5)),
      leido: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Forzamos valores fijos para que no rompa si el servicio intenta buscar credenciales
    _tipoEmisorActual = 'pescador';

    // ?? CALENTAMOS LOS MOTORES DE AUDIO DE EL GuIA
    VozService.inicializar();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    VozService.detener(); // ?? Frenamos la voz si el usuario sale del chat
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty) return;

    // =========================================================
    // ?? INTERCEPTOR DE COMANDOS CRUCIAL (Navegación al Instante)
    // =========================================================
    final textoLimpio = texto.toLowerCase().trim();

    // ??? 1. MAPA SATELITAL
    if (textoLimpio == 'mapa' ||
        textoLimpio.contains('ver mapa') ||
        textoLimpio == 'ver mapa') {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/mapa');
      return;
    }

    // ?? 2. PORTADA DE LA TIENDA
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

    // ?? 3. FORMULARIO DE COTIZACIÓN DE VIAJE
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

    // ?? 4. BANDEJA DE NOTIFICACIONES
    if (textoLimpio == 'notificaciones' ||
        textoLimpio.contains('ver notificaciones') ||
        textoLimpio.contains('bandeja de notificaciones')) {
      _messageController.clear();
      _focusNode.unfocus();
      Navigator.pushNamed(context, '/notificaciones');
      return;
    }

    // ?? 5. HISTORIAL DE COTIZACIONES Y PRESUPUESTOS
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

    setState(() {
      _isSending = true;
      // Insertamos tu mensaje de forma local e instantánea para verlo en pantalla
      _mensajesSimulados.insert(
        0,
        Mensaje(
          id: DateTime.now().toString(),
          reservaId: widget.reservaId,
          emisorId: 'usuario_pescador_prueba',
          texto: texto,
          tipoEmisor: 'pescador',
          creadoAt: DateTime.now(),
          leido: true,
        ),
      );
    });

    // Simulamos respuesta automática de El GuIA para probar la voz al toque
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          String respuestaBot =
              "Copiado, chamigo. Analizando tus coordenadas en el Paraná.";

          if (textoLimpio.contains('pesca') || textoLimpio.contains('dorado')) {
            respuestaBot =
                "Para el dorado en la corredera, metele señuelo de paleta larga y tiralo donde el agua remansa, chamigo.";
          } else if (textoLimpio.contains('raya') ||
              textoLimpio.contains('picadura')) {
            respuestaBot =
                "Alerta: Introduce el pie herido en agua caliente para neutralizar el veneno de la raya. No cortes la herida.";
          }

          _mensajesSimulados.insert(
            0,
            Mensaje(
              id: DateTime.now().toString(),
              reservaId: widget.reservaId,
              emisorId: 'el_guia_bot',
              texto: respuestaBot,
              tipoEmisor: 'capitan',
              creadoAt: DateTime.now(),
              leido: false,
            ),
          );
        });
      }
    });

    _messageController.clear();
    _focusNode.unfocus();

    setState(() {
      _isSending = false;
    });
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

  Widget _buildMessageBubble(Mensaje mensaje) {
    final esMio = mensaje.emisorId == 'usuario_pescador_prueba';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: esMio
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              crossAxisAlignment: esMio
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
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
                    mensaje.texto,
                    style: const TextStyle(color: _blancoPuro, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(mensaje.creadoAt),
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
            backgroundColor: _azulVibrante,
            child: const Icon(Icons.sailing, color: _blancoPuro, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El GuIA Pro',
                  style: TextStyle(
                    color: _blancoPuro,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Modo Sandbox de Voz',
                  style: TextStyle(color: _verdeBrillante, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
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
    // Captura del post-frame local para la voz automatizada sin depender de streams de red
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mensajesSimulados.isNotEmpty) {
        final ultimo = _mensajesSimulados.first;
        if (ultimo.emisorId == 'el_guia_bot' && !ultimo.leido) {
          ultimo.leido = true; // Lo marcamos como hablado
          VozService.hablar(ultimo.texto); // ??? ¡Habla!
        }
      }
    });

    return Scaffold(
      backgroundColor: _fondoOscuro,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              reverse:
                  true, // Cambiamos a reverse para manejar la inserción desde el índice 0 cómodamente
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _mensajesSimulados.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_mensajesSimulados[index]);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

// ?? Clase auxiliar local obligatoria para mapear los objetos sin depender del modelo externo
class Mensaje {
  final String id;
  final String reservaId;
  final String emisorId;
  final String texto;
  final String tipoEmisor;
  final DateTime creadoAt;
  bool leido;

  Mensaje({
    required this.id,
    required this.reservaId,
    required this.emisorId,
    required this.texto,
    required this.tipoEmisor,
    required this.creadoAt,
    required this.leido,
  });
}
