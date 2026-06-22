import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/voice_service.dart';
import '../services/baqueano_ia_service.dart'; // ✅ CORRECCIÓN: reemplaza MaestroPescadorSkill
 
class ChatAsistidoScreen extends StatefulWidget {
  final String reservaId;
  const ChatAsistidoScreen({super.key, required this.reservaId});
 
  @override
  State<ChatAsistidoScreen> createState() => _ChatAsistidoScreenState();
}
 
class _ChatAsistidoScreenState extends State<ChatAsistidoScreen> {
  final TextEditingController _messageController = TextEditingController();
  // ✅ CORRECCIÓN: eliminada instancia de MaestroPescadorSkill
  // BaqueanoIAService usa método estático, no necesita instancia

  // ✅ Estabilización de Identidad: Filtro de tiempo de sesión para empezar limpio
  final DateTime _sessionStartTime = DateTime.now().toUtc();

  bool _isSending = false;
  bool _estaHablando = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    VoiceService().init();
    _limpiarHistorialBaseDatos();
    VoiceService().isListeningNotifier.addListener(_onVoiceListeningChanged);
  }

  Future<void> _limpiarHistorialBaseDatos() async {
    try {
      // Intentar borrar el historial de la reserva en base de datos para empezar limpio
      await Supabase.instance.client
          .from('mensajes')
          .delete()
          .eq('reserva_id', widget.reservaId);
      debugPrint('[ChatAsistidoScreen] Historial borrado con éxito de Supabase.');
    } catch (e) {
      // Capturamos cualquier restricción de RLS de manera silenciosa
      debugPrint('[ChatAsistidoScreen] No se pudo borrar el historial físico (RLS): $e');
    }
  }
 
  @override
  void dispose() {
    _messageController.dispose();
    VoiceService().isListeningNotifier.removeListener(_onVoiceListeningChanged);
    VoiceService().stop();
    VoiceService().stopListening();
    super.dispose();
  }

  void _onVoiceListeningChanged() {
    if (mounted) {
      setState(() {
        _isListening = VoiceService().isListeningNotifier.value;
      });
    }
  }
 
  Future<void> _enviarMensaje() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty || _isSending) return;
 
    if (_isListening) {
      await VoiceService().stopListening();
    }

    setState(() => _isSending = true);
    final miId =
        Supabase.instance.client.auth.currentUser?.id ?? 'usuario_desconocido';
 
    try {
      // 1. Guardar mensaje del pescador
      await Supabase.instance.client.from('mensajes').insert({
        'reserva_id': widget.reservaId,
        'emisor_id': miId,
        'texto': texto,
        'tipo_emisor': 'pescador',
        'leido': true,
      });
 
      // ✅ CORRECCIÓN CENTRAL: usar BaqueanoIAService en lugar de MaestroPescadorSkill
      // Esto activa el enrutador híbrido:
      //   1° intenta Groq en la nube (online)
      //   2° si falla o no hay conexión, cae a ElGuiaEngine (offline)
      final respuestaBotObj = await BaqueanoIAService.responder(texto);
      final respuestaBot = respuestaBotObj.texto; // ✅ extrae el String del objeto
 
      // 2. Guardar respuesta del bot
      await Supabase.instance.client.from('mensajes').insert({
        'reserva_id': widget.reservaId,
        'emisor_id': 'el_guia_bot',
        'texto': respuestaBot,
        'tipo_emisor': 'capitan',
        'leido': false,
      });
 
      _messageController.clear();
    } catch (e) {
      debugPrint('[ChatAsistidoScreen] ❌ Error al enviar mensaje: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 20.0;
 
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('mensajes')
                  .stream(primaryKey: ['id'])
                  .eq('reserva_id', widget.reservaId)
                  .order('creado_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
 
                // ✅ Estabilización de Identidad: Filtramos mensajes antiguos de otras sesiones
                final mensajesDb = snapshot.data!.where((msg) {
                  final creadoAtStr = msg['creado_at'];
                  if (creadoAtStr == null) return false;
                  final creadoAt = DateTime.parse(creadoAtStr).toUtc();
                  return creadoAt.isAfter(_sessionStartTime.subtract(const Duration(seconds: 5)));
                }).toList();

                // Motor de voz activado por stream
                if (mensajesDb.isNotEmpty) {
                  final ultimo = mensajesDb.first;
                  if (ultimo['emisor_id'] == 'el_guia_bot' &&
                      ultimo['leido'] == false &&
                      !_estaHablando) {
                    _ejecutarVoz(ultimo['id'], ultimo['texto']);
                  }
                }
 
                return ListView.builder(
                  reverse: true,
                  itemCount: mensajesDb.length,
                  itemBuilder: (context, index) {
                    final msg = mensajesDb[index];
                    return _bubble(
                      msg['texto'],
                      msg['emisor_id'] != 'el_guia_bot',
                    );
                  },
                );
              },
            ),
          ),
 
          // Área de entrada
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Consultar...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      // ✅ Permite enviar con Enter en Web/Desktop
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.blue,
                    ),
                    onPressed: () async {
                      if (_isListening) {
                        await VoiceService().stopListening();
                      } else {
                        final success = await VoiceService().startListening((t, isFinal) {
                          if (isFinal) {
                            _messageController.text = t;
                            _enviarMensaje();
                          }
                        });
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ El servicio de reconocimiento de voz no está disponible en este celular. Asegúrate de tener activada la búsqueda por voz de Google.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  // ✅ Indicador visual de procesando
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _enviarMensaje,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  Future<void> _ejecutarVoz(dynamic id, String texto) async {
    setState(() => _estaHablando = true);
    await Supabase.instance.client
        .from('mensajes')
        .update({'leido': true})
        .eq('id', id);
    await VoiceService().speak(texto);
    if (mounted) setState(() => _estaHablando = false);
  }
 
  Widget _bubble(String texto, bool esMio) => Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: esMio ? Colors.blue : Colors.grey[700],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(texto, style: const TextStyle(color: Colors.white)),
        ),
      );
}
