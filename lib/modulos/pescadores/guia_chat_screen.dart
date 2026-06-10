import 'dart:async';
import 'package:flutter/material.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';

/// ════════════════════════════════════════════════════════════════════
///  GuiaChatScreen — El GuIA Pro
///  Chat que usa BaqueanoIAService (Groq → ElGuiaEngine) como motor.
///  El único systemPrompt válido es el de groq_service.dart.
/// ════════════════════════════════════════════════════════════════════
class GuiaChatScreen extends StatefulWidget {
  const GuiaChatScreen({super.key});

  @override
  State<GuiaChatScreen> createState() => _GuiaChatScreenState();
}

class _GuiaChatScreenState extends State<GuiaChatScreen>
    with TickerProviderStateMixin {
  // ── Paleta El Guia YA ──────────────────────────────────────────────
  static const Color _fondoOscuro    = Color(0xFF1A1A1A);
  static const Color _blancoPuro     = Color(0xFFFFFFFF);
  static const Color _azulVibrante   = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _naranjaIntenso = Color(0xFFFF6600);

  // ── Estado ────────────────────────────────────────────────────────
  final TextEditingController _inputCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  final List<_Mensaje> _mensajes = [];
  bool   _generando    = false;
  bool   _motorOnline  = true; // true = Groq, false = motor offline

  // ── Animación del cursor de typing ───────────────────────────────
  late AnimationController _cursorCtrl;
  late Animation<double>    _cursorAnim;

  // ── Quick chips del río ───────────────────────────────────────────
  static const List<_QuickChip> _chips = [
    _QuickChip('🎣', '¿Qué se pesca hoy?'),
    _QuickChip('🌊', '¿Cómo está el río?'),
    _QuickChip('🪱', '¿Qué carnada uso?'),
    _QuickChip('🎿', '¿Cómo hago el nudo?'),
    _QuickChip('⛅', 'Consejo para hoy'),
    _QuickChip('🆘', 'Zona de emergencia'),
  ];

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _cursorAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_cursorCtrl);

    // Inicializar BaqueanoIAService y mostrar saludo
    BaqueanoIAService.inicializar().then((_) => _saludar());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  // ── SALUDO INICIAL ────────────────────────────────────────────────
  Future<void> _saludar() async {
    const saludo = '¡Buenas, pescador! Soy El GuIA, '
        'tu viejo baqueano del Paraná. '
        'Preguntame lo que quieras: carnadas, nudos, estado del río, '
        'técnicas, zonas... o simplemente charlamos un rato. '
        '¡Estoy acá!';

    if (!mounted) return;
    setState(() {
      _mensajes.add(_Mensaje(rol: _Rol.asistente, texto: saludo));
    });
    _scrollAlFinal();
  }

  // ── ENVIAR MENSAJE ────────────────────────────────────────────────
  Future<void> _enviar([String? textoForzado]) async {
    final texto = (textoForzado ?? _inputCtrl.text).trim();
    if (texto.isEmpty || _generando) return;

    _inputCtrl.clear();
    setState(() {
      _mensajes.add(_Mensaje(rol: _Rol.usuario, texto: texto));
      _generando = true;
      // Agrego mensaje vacío del asistente que se irá llenando
      _mensajes.add(_Mensaje(rol: _Rol.asistente, texto: '', generando: true));
    });
    _scrollAlFinal();

    await _obtenerRespuesta(texto);
  }

  // ── OBTENER RESPUESTA VIA BaqueanoIAService ───────────────────────
  Future<void> _obtenerRespuesta(String pregunta) async {
    try {
      final respuesta = await BaqueanoIAService.responder(pregunta);

      if (mounted) {
        setState(() {
          _mensajes.last.texto    = respuesta.texto;
          _mensajes.last.generando = false;
          _generando  = true; // mantenemos en true mientras hacemos la animación de typing
          _motorOnline = respuesta.exito;
        });

        // Simular efecto typing: mostrar texto progresivamente
        await _mostrarTextoProgresivo(respuesta.texto);

        if (mounted) {
          setState(() {
            _generando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajes.last.texto    = '⚠️ No pude conectarme con el motor. Intentá de nuevo.';
          _mensajes.last.generando = false;
          _generando  = false;
          _motorOnline = false;
        });
      }
    }

    _scrollAlFinal();
  }

  // ── EFECTO TYPING PROGRESIVO ──────────────────────────────────────
  Future<void> _mostrarTextoProgresivo(String textoFinal) async {
    if (!mounted) return;
    // Mostramos el texto de a palabras para simular typing
    final palabras = textoFinal.split(' ');
    final buffer = StringBuffer();
    for (int i = 0; i < palabras.length; i++) {
      buffer.write(palabras[i]);
      if (i < palabras.length - 1) buffer.write(' ');
      if (mounted) {
        setState(() {
          _mensajes.last.texto    = buffer.toString();
          _mensajes.last.generando = true;
        });
        _scrollAlFinal();
      }
      // Velocidad de typing proporcional a longitud del texto
      final delay = textoFinal.length > 200 ? 18 : 28;
      await Future.delayed(Duration(milliseconds: delay));
    }
    if (mounted) {
      setState(() {
        _mensajes.last.generando = false;
      });
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD PRINCIPAL ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_motorOnline) _buildBannerOffline(),
          _buildBannerPro(),
          Expanded(child: _buildListaMensajes()),
          _buildChipsRapidos(),
          _buildAreaEntrada(),
        ],
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _fondoOscuro,
      foregroundColor: _blancoPuro,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_azulVibrante, _naranjaIntenso],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.psychology, color: _blancoPuro, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El GuIA Pro',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _motorOnline ? _verdeBrillante : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _motorOnline ? 'Groq · Llama 3.3' : 'Motor offline',
                    style: TextStyle(
                      color: _motorOnline
                          ? _verdeBrillante.withOpacity(0.85)
                          : Colors.orange.withOpacity(0.85),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _limpiarChat,
          icon: const Icon(Icons.delete_sweep_outlined, color: _blancoPuro),
          tooltip: 'Limpiar conversación',
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: _blancoPuro),
        ),
      ],
    );
  }

  void _limpiarChat() {
    setState(() {
      _mensajes.clear();
    });
    _saludar();
  }

  // ── BANNER PRO ────────────────────────────────────────────────────
  Widget _buildBannerPro() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _naranjaIntenso.withOpacity(0.12),
            _azulVibrante.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranjaIntenso.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined, color: _naranjaIntenso, size: 16),
          const SizedBox(width: 8),
          Text(
            'Groq Llama 3.3 · Respaldado offline automático',
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── BANNER OFFLINE ────────────────────────────────────────────────
  Widget _buildBannerOffline() {
    return Container(
      color: Colors.orange.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sin conexión — respondiendo en modo offline.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _motorOnline = true),
            child: const Text('Reintentar',
                style: TextStyle(color: _azulVibrante, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── LISTA DE MENSAJES ─────────────────────────────────────────────
  Widget _buildListaMensajes() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _mensajes.length,
      itemBuilder: (_, i) => _buildBurbuja(_mensajes[i]),
    );
  }

  Widget _buildBurbuja(_Mensaje msg) {
    final esUsuario = msg.rol == _Rol.usuario;

    return Container(
      margin: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: esUsuario ? 60 : 16,
        right: esUsuario ? 16 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[
            _avatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: esUsuario
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!esUsuario)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      'El GuIA Pro',
                      style: TextStyle(
                        color: _naranjaIntenso.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: esUsuario
                        ? _azulVibrante
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(esUsuario ? 16 : 4),
                      topRight: Radius.circular(esUsuario ? 4 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: esUsuario
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          msg.texto.isEmpty && msg.generando
                              ? '...'
                              : msg.texto,
                          style: TextStyle(
                            color: _blancoPuro.withOpacity(0.92),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ),
                      // Cursor parpadeante mientras genera
                      if (msg.generando && msg.texto.isNotEmpty)
                        AnimatedBuilder(
                          animation: _cursorAnim,
                          builder: (_, __) => Opacity(
                            opacity: _cursorAnim.value,
                            child: Container(
                              margin: const EdgeInsets.only(left: 2, bottom: 1),
                              width: 2,
                              height: 14,
                              color: _blancoPuro,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatHora(DateTime.now()),
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (esUsuario) ...[
            const SizedBox(width: 8),
            _avatarUsuario(),
          ],
        ],
      ),
    );
  }

  Widget _avatar() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_azulVibrante, _naranjaIntenso],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.psychology, color: _blancoPuro, size: 16),
      );

  Widget _avatarUsuario() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _naranjaIntenso,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.person, color: _blancoPuro, size: 16),
      );

  // ── CHIPS RÁPIDOS ─────────────────────────────────────────────────
  Widget _buildChipsRapidos() {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = _chips[i];
          return ActionChip(
            avatar: Text(chip.emoji, style: const TextStyle(fontSize: 14)),
            label: Text(
              chip.label,
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
            backgroundColor: _azulVibrante.withOpacity(0.15),
            side: BorderSide(color: _azulVibrante.withOpacity(0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: _generando ? null : () => _enviar(chip.label),
          );
        },
      ),
    );
  }

  // ── ÁREA DE ENTRADA ───────────────────────────────────────────────
  Widget _buildAreaEntrada() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !_generando,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              style: const TextStyle(color: _blancoPuro, fontSize: 14),
              decoration: InputDecoration(
                hintText: _generando
                    ? 'El GuIA está respondiendo...'
                    : 'Preguntale al baqueano...',
                hintStyle: TextStyle(
                  color: _blancoPuro.withOpacity(0.4),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: _azulVibrante, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _generando
                  ? Colors.white.withOpacity(0.1)
                  : _azulVibrante,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _generando ? null : () => _enviar(),
              icon: _generando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                                _blancoPuro.withOpacity(0.5)),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: _blancoPuro, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── MODELOS LOCALES ───────────────────────────────────────────────────
enum _Rol { usuario, asistente }

class _Mensaje {
  _Rol   rol;
  String texto;
  bool   generando;

  _Mensaje({required this.rol, required this.texto, this.generando = false});
}

class _QuickChip {
  final String emoji;
  final String label;
  const _QuickChip(this.emoji, this.label);
}
