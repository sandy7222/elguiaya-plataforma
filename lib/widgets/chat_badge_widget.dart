

import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatBadgeWidget extends StatefulWidget {
  final String reservaId;
  final Widget child;

  const ChatBadgeWidget({
    super.key,
    required this.reservaId,
    required this.child,
  });

  @override
  State<ChatBadgeWidget> createState() => _ChatBadgeWidgetState();
}

class _ChatBadgeWidgetState extends State<ChatBadgeWidget> {
  int _mensajesNoLeidos = 0;

  @override
  void initState() {
    super.initState();
    _escucharMensajesNoLeidos();
  }

  void _escucharMensajesNoLeidos() {
    ChatService.getMensajesNoLeidosStream().listen((conteo) {
      if (mounted) {
        setState(() {
          _mensajesNoLeidos = conteo;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_mensajesNoLeidos > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _mensajesNoLeidos > 99 ? '99+' : _mensajesNoLeidos.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
