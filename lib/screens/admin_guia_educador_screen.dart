import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/gemini_config.dart';
import '../services/gemini_learner.dart';
import '../services/gemini_service.dart';
import '../services/capacitacion_service.dart';
import '../widgets/guia_overlay.dart';
import '../config/groq_config.dart';
import '../services/groq_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/safe_button.dart';


/// Panel de control del Educador Gemini.
/// Permite al admin: activar/desactivar Gemini, ingresar la API key,
/// configurar el límite diario y ver estadísticas de aprendizaje.
class AdminGuiaEducadorScreen extends StatefulWidget {
  const AdminGuiaEducadorScreen({super.key});

  @override
  State<AdminGuiaEducadorScreen> createState() => _AdminGuiaEducadorScreenState();
}

class _AdminGuiaEducadorScreenState extends State<AdminGuiaEducadorScreen> {
  final _apiKeyController         = TextEditingController();
  final _groqApiKeyController      = TextEditingController(); // El Guía
  final _groqCentralitaController  = TextEditingController(); // Centralita
  final _limitController           = TextEditingController();

  bool _cargandoStats       = true;
  bool _guardandoKey        = false;
  bool _mostrarKey          = false;
  bool _mostrarGroqKey      = false;
  bool _mostrarCentralitaKey = false;
  bool _probandoGroq        = false;
  bool _robotActivo         = false;
  String? _resultadoGroqPrueba;
  bool _groqPruebaExitosa = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingIntents = [];
  List<Map<String, dynamic>> _carencias = [];
  bool _loadingPending = true;
  bool _loadingCarencias = true;
  String _selectedCategoryTab = 'tecnico';

  static const String _defaultPromptSistema = '''
Analizá el documento provisto y extraé la información en forma de intenciones para el asistente "El Guía".
Debés generar un JSON estructurado con una lista de intenciones de aprendizaje.
Cada intención debe seguir estrictamente la nomenclatura del "triple filtro" (tipo_accion_objetivo):
- tipo: "como" | "que" | "donde" | "cuando"
- accion: "se_prepara" | "se_hace" | "hago" | "sirve" | "se_come"
- objetivo: sustantivo clave en singular, snake_case (ej: "nudo_palomar", "boyas", "picadura_raya")

El JSON resultante debe ser una lista con este formato:
{
  "aprendizajes": [
    {
      "intencion": "tipo_accion_objetivo",
      "activadores": ["frase 1", "frase 2", "frase 3"],
      "respuesta_limpia": "Explicación breve de 3 líneas máximo en tono ribereño argentino.",
      "gif": "hablaConMate|exito|piensaLeve|piensaProfundo|saludo|duda",
      "puntaje": 9
    }
  ]
}
''';

  @override
  void initState() {
    super.initState();
    CapacitacionService.invalidarCache(); // Fuerza recarga de instrucciones actualizadas
    _cargarDatos();
    _loadPendingIntents();
    _loadCarencias();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _groqApiKeyController.dispose();
    _groqCentralitaController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await GeminiConfig.cargar();
    await GroqConfig.cargar();
    final stats = await GeminiLearner.estadisticas();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _stats             = stats;
        _cargandoStats     = false;
        _robotActivo       = prefs.getBool('guia_activo') ?? false;
        _apiKeyController.text = GeminiConfig.tieneApiKey
            ? '••••••••••••••••••••'
            : '';
        _groqApiKeyController.text = GroqConfig.tieneApiKey
            ? '••••••••••••••••••••'
            : '';
        _groqCentralitaController.text = GroqConfig.tieneApiKeyCentralita
            ? '••••••••••••••••••••'
            : '';
        _limitController.text  = GeminiConfig.limiteDiario.toString();
      });
    }
  }

  Future<void> _guardarApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty || key.startsWith('•')) return;
    setState(() => _guardandoKey = true);
    await GeminiConfig.setApiKey(key);
    setState(() {
      _guardandoKey = false;
      _apiKeyController.text = '••••••••••••••••••••';
      _mostrarKey = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ API Key guardada correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _guardarGroqApiKey() async {
    final key = _groqApiKeyController.text.trim();
    if (key.isEmpty || key.startsWith('•')) return;
    setState(() => _guardandoKey = true);
    await GroqConfig.setApiKeyGuia(key);
    setState(() {
      _guardandoKey = false;
      _groqApiKeyController.text = '••••••••••••••••••••';
      _mostrarGroqKey = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clave El Guía (Groq) guardada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _guardarGroqCentralitaKey() async {
    final key = _groqCentralitaController.text.trim();
    if (key.isEmpty || key.startsWith('•')) return;
    setState(() => _guardandoKey = true);
    await GroqConfig.setApiKeyCentralita(key);
    setState(() {
      _guardandoKey = false;
      _groqCentralitaController.text = '••••••••••••••••••••';
      _mostrarCentralitaKey = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clave Centralita (Groq) guardada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _probarConexionGroq() async {
    setState(() {
      _probandoGroq = true;
      _resultadoGroqPrueba = null;
    });
    try {
      final key = _groqApiKeyController.text.trim();
      final testKey = (key.isEmpty || key.startsWith('•')) ? GroqConfig.apiKey : key;

      if (testKey.isEmpty) {
        throw Exception('Clave vacía. Por favor, ingresá una clave de Groq válida.');
      }

      final svc = GroqService();
      // CORRECCIÓN: timeout agregado para evitar spinner infinito en redes lentas
      final respuesta = await svc.probarConexion(testKey)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Groq no respondió en 10 segundos. Verificá tu conexión.'),
          );

      setState(() {
        _groqPruebaExitosa = true;
        _resultadoGroqPrueba = '✅ Groq conectado correctamente: "$respuesta"';
        _probandoGroq = false;
      });
    } on TimeoutException catch (e) {
      setState(() {
        _groqPruebaExitosa = false;
        _resultadoGroqPrueba = '⏱️ Timeout: ${e.message}';
        _probandoGroq = false;
      });
    } catch (e) {
      setState(() {
        _groqPruebaExitosa = false;
        _resultadoGroqPrueba = '❌ Error al probar Groq: $e';
        _probandoGroq = false;
      });
    }
  }


  Future<void> _guardarLimite() async {
    final limite = int.tryParse(_limitController.text.trim()) ?? GeminiConfig.limiteDiarioDefault;
    await GeminiConfig.setLimiteDiario(limite);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Límite actualizado: $limite consultas/día'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (_stats['total'] as int?) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildRobotSwitch(),
          const SizedBox(height: 20),
          _buildNivelCard(total),
          const SizedBox(height: 20),
          _buildToggleCard(),
          const SizedBox(height: 20),
          _buildApiKeyCard(),
          const SizedBox(height: 20),
          _buildGroqApiKeyCard(),
          const SizedBox(height: 20),
          _buildLimiteCard(),
          const SizedBox(height: 20),
          _buildEstadisticasCard(),
          const SizedBox(height: 20),
          _buildConocimientoPendienteCard(),
          const SizedBox(height: 20),
          _buildCarenciasCard(),
          const SizedBox(height: 20),
          if (!_cargandoStats) _buildUltimasAprendidas(),
        ],
      ),
    );
  }

  // ── Interruptor principal del robot ─────────────────────────────────────────────

  Widget _buildRobotSwitch() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _robotActivo
                  ? [const Color(0xFF00E676).withOpacity(0.18), const Color(0xFF00E676).withOpacity(0.05)]
                  : [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _robotActivo
                  ? const Color(0xFF00E676).withOpacity(0.5)
                  : Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icóno animado del robot
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _robotActivo
                      ? const Color(0xFF00E676).withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color: _robotActivo
                        ? const Color(0xFF00E676)
                        : Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _robotActivo ? '🤖' : '💤',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _robotActivo ? 'El Guía está ENCENDIDO' : 'El Guía está APAGADO',
                        key: ValueKey(_robotActivo),
                        style: TextStyle(
                          color: _robotActivo ? const Color(0xFF00E676) : Colors.white54,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _robotActivo
                          ? 'Visible para todos los pescadores'
                          : 'Oculto — los pescadores no lo ven',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Switch grande
              Transform.scale(
                scale: 1.3,
                child: Switch.adaptive(
                  value: _robotActivo,
                  activeColor: const Color(0xFF00E676),
                  activeTrackColor: const Color(0xFF00E676).withOpacity(0.35),
                  inactiveThumbColor: Colors.white30,
                  inactiveTrackColor: Colors.white10,
                  onChanged: (valor) async {
                    // setActivo actualiza el ValueNotifier (overlay aparece al instante)
                    // Y guarda en SharedPreferences simultáneamente
                    await GuiaOverlayController.setActivo(valor);
                    setState(() => _robotActivo = valor);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            valor
                                ? '🤖 El Guía fue encendido — ya aparece en pantalla'
                                : '💤 El Guía fue apagado',
                          ),
                          backgroundColor: valor ? const Color(0xFF00E676) : Colors.grey[700],
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Medidor de Nivel ─────────────────────────────────────────────────────

  static const List<_NivelInfo> _niveles = [
    _NivelInfo(nombre: 'Novato del Río',    emoji: '🌊', min: 0,   max: 10,  color: Color(0xFF607D8B)),
    _NivelInfo(nombre: 'Aprendiz',           emoji: '🎣', min: 11,  max: 25,  color: Color(0xFF4CAF50)),
    _NivelInfo(nombre: 'Pescador',           emoji: '🐟', min: 26,  max: 50,  color: Color(0xFF2196F3)),
    _NivelInfo(nombre: 'Baqueaño',          emoji: '⚓',   min: 51,  max: 80,  color: Color(0xFF9C27B0)),
    _NivelInfo(nombre: 'Experto del Paraná', emoji: '🏆', min: 81,  max: 120, color: Color(0xFFFF9800)),
    _NivelInfo(nombre: 'Maestro del Río',   emoji: '👑', min: 121, max: 999, color: Color(0xFFFFD700)),
  ];

  _NivelInfo _nivelActual(int total) {
    for (final n in _niveles.reversed) {
      if (total >= n.min) return n;
    }
    return _niveles.first;
  }

  Widget _buildNivelCard(int total) {
    final nivel    = _nivelActual(total);
    final idx      = _niveles.indexOf(nivel);
    final esUltimo = idx == _niveles.length - 1;
    final siguiente = esUltimo ? null : _niveles[idx + 1];

    // XP dentro del nivel actual
    final xpInicio  = nivel.min;
    final xpFin     = esUltimo ? total + 1 : siguiente!.min;
    final xpActual  = (total - xpInicio).clamp(0, xpFin - xpInicio);
    final xpTotal   = (xpFin - xpInicio).toDouble();
    final progreso  = esUltimo ? 1.0 : (xpActual / xpTotal).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                nivel.color.withOpacity(0.18),
                nivel.color.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: nivel.color.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila: emoji + nombre + anclas
              Row(
                children: [
                  // Circulo nivel
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: nivel.color.withOpacity(0.2),
                      border: Border.all(color: nivel.color, width: 2),
                    ),
                    child: Center(
                      child: Text(nivel.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NIVEL ${idx + 1}',
                          style: TextStyle(
                            color: nivel.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          nivel.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$total intenciones aprendidas',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Anclas decorativas
                  Column(
                    children: List.generate(6, (i) {
                      return Text(
                        '⚓',
                        style: TextStyle(
                          fontSize: 14,
                          color: i < (idx + 1)
                              ? nivel.color
                              : Colors.white.withOpacity(0.15),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Barra XP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esUltimo ? 'Máximo alcanzado 👑' : 'Progreso al siguiente nivel',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                  ),
                  if (!esUltimo)
                    Text(
                      '$xpActual / ${xpTotal.toInt()} XP',
                      style: TextStyle(
                        color: nivel.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progreso),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(nivel.color),
                    minHeight: 12,
                  ),
                ),
              ),
              if (!esUltimo) ...[
                const SizedBox(height: 8),
                Text(
                  'Siguiente: ${siguiente!.emoji} ${siguiente.nombre} (${siguiente.min} intenciones)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Hitos (milestone timeline)
              Row(
                children: _niveles.asMap().entries.map((e) {
                  final i = e.key;
                  final n = e.value;
                  final alcanzado = total >= n.min;
                  final esCurrent = i == idx;
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: alcanzado
                                ? n.color.withOpacity(0.25)
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: esCurrent
                                  ? nivel.color
                                  : alcanzado
                                      ? n.color.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.1),
                              width: esCurrent ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              n.emoji,
                              style: TextStyle(
                                fontSize: 13,
                                color: alcanzado ? null : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${n.min}',
                          style: TextStyle(
                            color: alcanzado
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white.withOpacity(0.2),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.purpleAccent, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El Guía — Modo Educador',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                GeminiConfig.estadoDescripcion,
                style: TextStyle(
                  color: GeminiConfig.puedeConsultar
                      ? const Color(0xFF00E676)
                      : Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Toggle ON/OFF ─────────────────────────────────────────────────────────

  Widget _buildToggleCard() {
    final activo = GeminiConfig.educadorActivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activo ? Colors.purpleAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activo ? Icons.psychology_rounded : Icons.psychology_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activo ? 'Educador ACTIVO' : 'Educador APAGADO (Plan B)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          activo
                              ? 'Gemini responde cuando hay señal'
                              : 'Solo motor local — costo API: \$0',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: activo,
                    activeColor: Colors.purpleAccent,
                    activeTrackColor: Colors.purpleAccent.withOpacity(0.4),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    onChanged: (valor) async {
                      // Guardar automáticamente la clave si el usuario la editó
                      final key = _apiKeyController.text.trim();
                      if (key.isNotEmpty && !key.startsWith('•')) {
                        await GeminiConfig.setApiKey(key);
                        _apiKeyController.text = '••••••••••••••••••••';
                      }
                      await GeminiConfig.setEducadorActivo(valor);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hace falta borrar la API Key para apagar Gemini. Simplemente desactivá este interruptor. Tu clave quedará guardada de forma segura para cuando decidas reactivarlo.',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Botón Limpiar Pausa (solo cuando la API está pausada) ────────────
        if (activo) ...[
          if (GeminiConfig.estadoDescripcion.contains('pausada')) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SafeElevatedIconButton(
  onPressed: () async {
                  await GeminiConfig.limpiarPausa();
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Pausa limpiada. Gemini vuelve a estar disponible.'),
                        backgroundColor: Color(0xFF00E676),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
  icon: Icons.lock_open_rounded,
  iconSize: 16,
  iconColor: Colors.black,
  label: 'Limpiar Pausa y Reactivar Gemini',
  textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
),
            ),
          ],
        ],
      ],
    );
  }




  // ── API Key ───────────────────────────────────────────────────────────────

  Widget _buildApiKeyCard() {
    return _glassCard(
      label: 'API KEY DE GEMINI',
      labelColor: Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conseguila gratis en aistudio.google.com',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: !_mostrarKey,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (val) {
              final trimmed = val.trim();
              if (trimmed.isNotEmpty && !trimmed.startsWith('•')) {
                GeminiConfig.setApiKey(trimmed);
              }
            },
            onTap: () {
              if (_apiKeyController.text.startsWith('•')) {
                _apiKeyController.clear();
              }
            },
            decoration: InputDecoration(
              hintText: 'AIzaSy...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.purpleAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _mostrarKey = !_mostrarKey),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purpleAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardandoKey ? null : _guardarApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: SafeButtonLoadingContent(
                loading: _guardandoKey,
                icon: Icons.save_rounded,
                idleLabel: 'Guardar API Key',
                loadingLabel: 'Guardando...',
                textStyle: const TextStyle(color: Colors.white),
                spinnerColor: Colors.white,
              ),
            ),
          ),
          if (GeminiConfig.tieneApiKey) ...[
            const SizedBox(height: 8),
            SafeTextIconButton(
  onPressed: () async {
                await GeminiConfig.setApiKey('');
                setState(() => _apiKeyController.clear());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔒 API Key eliminada de la memoria local'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
  icon: Icons.delete_outline_rounded,
  iconSize: 18,
  iconColor: Colors.redAccent,
  label: 'Borrar API Key de la memoria local',
  textStyle: TextStyle(color: Colors.redAccent, fontSize: 12),
),
          ],
        ],
      ),
    );
  }

  Widget _buildGroqApiKeyCard() {
    return _glassCard(
      label: 'CLAVES GROQ — EL GUÍA Y CENTRALITA',
      labelColor: Colors.cyanAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creá una clave por servicio en console.groq.com → API Keys → Create API Key. Así si cambiás una no rompés la otra.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // ── CLAVE EL GUÍA ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.cyanAccent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'El Guía (robot asistente)',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _groqApiKeyController,
            obscureText: !_mostrarGroqKey,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onTap: () {
              if (_groqApiKeyController.text.startsWith('•')) {
                _groqApiKeyController.clear();
              }
            },
            decoration: InputDecoration(
              hintText: 'gsk_... (clave de El Guía)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.cyanAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarGroqKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _mostrarGroqKey = !_mostrarGroqKey),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SafeElevatedIconButton(
  onPressed: _guardandoKey ? null : _guardarGroqApiKey,
  icon: Icons.save_rounded,
  iconSize: 16,
  label: 'Guardar Guía',
  textStyle: TextStyle(fontSize: 12),
  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _probandoGroq ? null : _probarConexionGroq,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: SafeButtonLoadingContent(
                    loading: _probandoGroq,
                    icon: Icons.wifi_tethering_rounded,
                    iconSize: 16,
                    iconColor: Colors.cyanAccent,
                    idleLabel: 'Probar',
                    loadingLabel: 'Probando...',
                    textStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    spinnerColor: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          if (_resultadoGroqPrueba != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _groqPruebaExitosa
                    ? const Color(0xFF00E676).withOpacity(0.1)
                    : Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _groqPruebaExitosa
                      ? const Color(0xFF00E676).withOpacity(0.4)
                      : Colors.redAccent.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _groqPruebaExitosa ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _groqPruebaExitosa ? const Color(0xFF00E676) : Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resultadoGroqPrueba!,
                      style: TextStyle(
                        color: _groqPruebaExitosa ? const Color(0xFF00E676) : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (GroqConfig.tieneApiKey) ...[
            const SizedBox(height: 4),
            SafeTextIconButton(
  onPressed: () async {
                await GroqConfig.setApiKeyGuia('');
                setState(() => _groqApiKeyController.clear());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔒 Clave El Guía eliminada'), backgroundColor: Colors.orange),
                  );
                }
              },
  icon: Icons.delete_outline_rounded,
  iconSize: 16,
  iconColor: Colors.redAccent,
  label: 'Borrar clave Guía',
  textStyle: TextStyle(color: Colors.redAccent, fontSize: 11),
),
          ],

          const Divider(color: Colors.white12, height: 32),

          // ── CLAVE CENTRALITA ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.orangeAccent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Centralita (panel admin)',
                style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _groqCentralitaController,
            obscureText: !_mostrarCentralitaKey,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onTap: () {
              if (_groqCentralitaController.text.startsWith('•')) {
                _groqCentralitaController.clear();
              }
            },
            decoration: InputDecoration(
              hintText: 'gsk_... (clave de la Centralita)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.orangeAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarCentralitaKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _mostrarCentralitaKey = !_mostrarCentralitaKey),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SafeElevatedIconButton(
  onPressed: _guardandoKey ? null : _guardarGroqCentralitaKey,
  icon: Icons.save_rounded,
  iconSize: 16,
  label: 'Guardar Centralita',
  textStyle: TextStyle(fontSize: 12),
  style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
),
          ),
          if (GroqConfig.tieneApiKeyCentralita) ...[
            const SizedBox(height: 4),
            SafeTextIconButton(
  onPressed: () async {
                await GroqConfig.setApiKeyCentralita('');
                setState(() => _groqCentralitaController.clear());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔒 Clave Centralita eliminada'), backgroundColor: Colors.orange),
                  );
                }
              },
  icon: Icons.delete_outline_rounded,
  iconSize: 16,
  iconColor: Colors.redAccent,
  label: 'Borrar clave Centralita',
  textStyle: TextStyle(color: Colors.redAccent, fontSize: 11),
),
          ],
        ],
      ),
    );
  }



  // ── Límite diario ─────────────────────────────────────────────────────────


  Widget _buildLimiteCard() {
    return _glassCard(
      label: 'CONTROL DE CUOTA DIARIA',
      labelColor: Colors.orangeAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultas hoy: ${GeminiConfig.consultasHoy} / ${GeminiConfig.limiteDiario}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: GeminiConfig.limiteDiario > 0
                            ? (GeminiConfig.consultasHoy / GeminiConfig.limiteDiario).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          GeminiConfig.consultasHoy >= GeminiConfig.limiteDiario
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Límite diario',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orangeAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _guardarLimite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                child: const Text('Aplicar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Se resetea automáticamente a medianoche.',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Estadísticas ──────────────────────────────────────────────────────────

  Widget _buildEstadisticasCard() {
    if (_cargandoStats) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }
    final consolidadas = _stats['consolidadas'] ?? 0;
    final cobertura    = _stats['cobertura_pct'] ?? 60;

    return _glassCard(
      label: 'ESTADO DEL APRENDIZAJE',
      labelColor: const Color(0xFF00E676),
      child: Column(
        children: [
          Row(
            children: [
              _statBox('Intenciones\nconsolidadas', '$consolidadas', const Color(0xFF00E676)),
              const SizedBox(width: 12),
              _statBox('Cobertura\noffline real', '$cobertura%', Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox('Incubando\n(Pendientes)', '${_stats['pendientes'] ?? 0}', Colors.cyan),
              const SizedBox(width: 12),
              _statBox('Cementerio\n(Descartados)', '${_stats['descartados'] ?? 0}', Colors.redAccent),
              const SizedBox(width: 12),
              _statBox('Activadores\naprendidos', '${_stats['total_activadores'] ?? 0}', Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBox('Total preguntas\n(Locales / IA)', '${GeminiConfig.totalConsultasTotal} (${GeminiConfig.totalPreguntas} IA)', Colors.blueAccent),
              const SizedBox(width: 12),
              _statBox('Última\nactividad', GeminiConfig.ultimaActividad, Colors.white54),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de cobertura
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cobertura offline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$cobertura%', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (cobertura / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                  minHeight: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botón: recargar capacitación
          SizedBox(
            width: double.infinity,
            child: SafeOutlinedIconButton(
  onPressed: () {
                CapacitacionService.invalidarCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 Capacitación recargada desde Supabase'),
                    backgroundColor: Colors.blueAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
  icon: Icons.refresh_rounded,
  iconColor: Colors.white60,
  label: 'Recargar base de conocimiento',
  textStyle: TextStyle(color: Colors.white60, fontSize: 12),
  style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
),
          ),
        ],
      ),
    );
  }

  // ── Últimas aprendidas ────────────────────────────────────────────────────

  Widget _buildUltimasAprendidas() {
    final ultimas = (_stats['ultimas'] as List<dynamic>? ?? []);
    if (ultimas.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      label: 'ÚLTIMAS INTENCIONES APRENDIDAS',
      labelColor: Colors.white54,
      child: Column(
        children: ultimas.map((item) {
          final map          = item as Map<String, dynamic>;
          final intencion    = map['intencion']?.toString() ?? '';
          final puntaje      = (map['puntaje'] as num?)?.toDouble() ?? 0;
          final veces        = map['veces'] ?? 1;
          final consolidada  = map['consolidada'] == true;
          final ejemplo      = map['ejemplo']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consolidada ? '🌟' : '✅',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              intencion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          _puntajeBadge(puntaje),
                          const SizedBox(width: 6),
                          Text(
                            '$veces× uso',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                          ),
                        ],
                      ),
                      if (ejemplo.isNotEmpty)
                        Text(
                          '"$ejemplo"',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, String? label, Color? labelColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor ?? Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _puntajeBadge(double puntaje) {
    final color = puntaje >= 8
        ? const Color(0xFF00E676)
        : puntaje >= 6
            ? Colors.orangeAccent
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        'p:${puntaje.toInt()}',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }



  Future<void> _loadPendingIntents() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('guia_conocimiento_distribuido')
          .select('*')
          .eq('aprobado', false)
          .neq('fuente', 'carencia_groq'); // Excluir carencias — tienen su propia sección
      if (mounted) {
        setState(() {
          _pendingIntents = List<Map<String, dynamic>>.from(response as List? ?? []);
          _loadingPending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending intents: $e');
      if (mounted) {
        setState(() {
          _loadingPending = false;
        });
      }
    }
  }

  /// Carga las carencias detectadas por Groq (fuente = 'carencia_groq').
  /// Ordenadas por veces_preguntado DESC para mostrar primero las más urgentes.
  Future<void> _loadCarencias() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('guia_conocimiento_distribuido')
          .select('*')
          .eq('fuente', 'carencia_groq')
          .order('veces_preguntado', ascending: false);
      if (mounted) {
        setState(() {
          _carencias = List<Map<String, dynamic>>.from(response as List? ?? []);
          _loadingCarencias = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading carencias: $e');
      if (mounted) {
        setState(() {
          _loadingCarencias = false;
        });
      }
    }
  }

  Future<void> _aprobarIntencion(Map<String, dynamic> item) async {
    try {
      final client = Supabase.instance.client;
      await client
          .from('guia_conocimiento_distribuido')
          .update({
            'aprobado': true,
            'fecha_aprobacion': DateTime.now().toIso8601String().substring(0, 10),
          })
          .eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Intención aprobada con éxito. Se sincronizará con los pescadores.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadPendingIntents();
      await _cargarDatos();
      // Invalidar el caché del servicio para que Groq use este conocimiento
      // en la próxima conversación sin esperar el TTL de 30 minutos.
      CapacitacionService.invalidarCacheDistribuido();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al aprobar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _rechazarIntencion(Map<String, dynamic> item) async {
    try {
      final client = Supabase.instance.client;
      await client
          .from('guia_conocimiento_distribuido')
          .delete()
          .eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Intención rechazada y eliminada.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadPendingIntents();
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al rechazar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final intencionController = TextEditingController(text: item['intencion']?.toString() ?? '');
    final respuestaController = TextEditingController(text: item['respuesta_limpia']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF001A33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Editar Intención', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Intención (nombre único):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: intencionController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Respuesta sugerida (máx. 120 caracteres):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: respuestaController,
                  maxLines: 3,
                  maxLength: 120,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newIntencion = intencionController.text.trim();
                final newRespuesta = respuestaController.text.trim();
                if (newIntencion.isEmpty || newRespuesta.isEmpty) return;

                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  final client = Supabase.instance.client;
                  await client
                      .from('guia_conocimiento_distribuido')
                      .update({
                        'intencion': newIntencion,
                        'respuesta_limpia': newRespuesta,
                      })
                      .eq('id', item['id']);

                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('💾 Cambios guardados en Supabase.'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  await _loadPendingIntents();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al guardar: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConocimientoPendienteCard() {
    if (_loadingPending) {
      return _glassCard(
        label: 'CONOCIMIENTO PENDIENTE DE APROBACIÓN',
        labelColor: Colors.cyanAccent,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
        ),
      );
    }

    final filtered = _pendingIntents
        .where((item) => item['categoria'] == _selectedCategoryTab)
        .toList();

    return _glassCard(
      label: 'CONOCIMIENTO PENDIENTE DE APROBACIÓN',
      labelColor: Colors.cyanAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTabButton('tecnico', '🔧 Técnico'),
              const SizedBox(width: 8),
              _buildTabButton('lenguaje', '💬 Lenguaje'),
              const SizedBox(width: 8),
              _buildTabButton('emergencia', '🚨 Emergencia'),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay intenciones pendientes en esta categoría.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildPendingItemRow(item);
              },
            ),
        ],
      ),
    );
  }

  // ── SECCIÓN CARENCIAS ────────────────────────────────────────────────────────

  /// Tarjeta principal de carencias detectadas por Groq.
  Widget _buildCarenciasCard() {
    final count = _carencias.length;
    final label = count > 0
        ? 'CARENCIAS DETECTADAS POR GROQ  ($count sin resolver)'
        : 'CARENCIAS DETECTADAS POR GROQ';

    if (_loadingCarencias) {
      return _glassCard(
        label: label,
        labelColor: const Color(0xFFFF6600),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Color(0xFFFF6600)),
          ),
        ),
      );
    }

    return _glassCard(
      label: label,
      labelColor: const Color(0xFFFF6600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explicación
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6600).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF6600).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Text('🕳️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estas son preguntas que El Guía no supo responder. '
                    'Las más urgentes (más veces preguntadas) aparecen primero. '
                    'Podés convertirlas en conocimiento real usando el botón "Enseñar".',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_carencias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    const Text('🎓', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      '¡El Guía no tiene carencias registradas!\nEstá respondiendo todo correctamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _carencias.length,
              itemBuilder: (context, index) => _buildCarenciaRow(_carencias[index]),
            ),
        ],
      ),
    );
  }

  /// Fila individual de una carencia con sus metadatos y botón de acción.
  Widget _buildCarenciaRow(Map<String, dynamic> item) {
    final intencion = item['intencion']?.toString() ?? '';
    final veces = (item['veces_preguntado'] as num?)?.toInt() ?? 1;
    final fecha = item['fecha_consolidacion']?.toString() ?? '';
    List<String> activadores = [];
    if (item['activadores'] is List) {
      activadores = List<String>.from(item['activadores'] as List);
    }
    // La pregunta original está en activadores[0]
    final preguntaOriginal = activadores.isNotEmpty ? activadores.first : intencion;

    // Color de urgencia según cuántas veces se preguntó
    final Color urgenciaColor = veces >= 5
        ? Colors.redAccent
        : veces >= 3
            ? const Color(0xFFFF6600)
            : Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgenciaColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgenciaColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge de urgencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgenciaColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgenciaColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, color: urgenciaColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$veces ${veces == 1 ? "vez" : "veces"}',
                      style: TextStyle(
                        color: urgenciaColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (fecha.isNotEmpty)
                Text(
                  fecha,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              const Spacer(),
              // Botón eliminar (ya resuelta o descartada)
              IconButton(
                onPressed: () => _rechazarIntencion(item).then((_) => _loadCarencias()),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 18),
                tooltip: 'Descartar carencia',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Pregunta que El Guía no supo responder
          Text(
            '❓ $preguntaOriginal',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID interno: $intencion',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          // CTA: convertir en conocimiento
          SizedBox(
            width: double.infinity,
            child: SafeElevatedIconButton(
  onPressed: () => _convertirCarenciaAAprendizaje(item, preguntaOriginal),
  icon: Icons.school_rounded,
  iconSize: 16,
  label: 'Enseñarle esto al Guía',
  textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
  style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
),
          ),
        ],
      ),
    );
  }

  /// Abre el dialog de edición pre-cargado con la pregunta de la carencia
  /// para que el admin escriba la respuesta correcta y convierta la carencia
  /// en conocimiento aprobado.
  void _convertirCarenciaAAprendizaje(
    Map<String, dynamic> item,
    String preguntaOriginal,
  ) {
    final intencionController = TextEditingController(
      text: item['intencion']
          ?.toString()
          .replaceFirst('carencia_', '') ?? '',
    );
    // La respuesta empieza vacía para que el admin la escriba
    final respuestaController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF001A33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFF6600), width: 1.5),
          ),
          title: const Row(
            children: [
              Text('🎓 ', style: TextStyle(fontSize: 20)),
              Flexible(
                child: Text(
                  'Enseñarle esto al Guía',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contexto: qué preguntó el usuario
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6600).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF6600).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'El pescador preguntó:',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preguntaOriginal,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nueva intención (snake_case):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: intencionController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ej: como_se_pesca_dorado',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Respuesta del Guía (máx. 120 caracteres):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: respuestaController,
                  maxLines: 4,
                  maxLength: 120,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Escribí la respuesta que El Guía debería dar...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38)),
            ),
            SafeElevatedIconButton(
  onPressed: () async {
                final newIntencion = intencionController.text.trim();
                final newRespuesta = respuestaController.text.trim();
                if (newIntencion.isEmpty || newRespuesta.isEmpty) return;

                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  final client = Supabase.instance.client;
                  // Actualizar la fila existente convirtiéndola en conocimiento
                  await client
                      .from('guia_conocimiento_distribuido')
                      .update({
                        'intencion': newIntencion,
                        'respuesta_limpia': newRespuesta,
                        'categoria': 'tecnico',
                        'fuente': 'admin_manual',
                        'aprobado': true,
                        'fecha_aprobacion':
                            DateTime.now().toIso8601String().substring(0, 10),
                      })
                      .eq('id', item['id']);

                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            '✅ ¡Carencia convertida en conocimiento! El Guía ya lo sabe.'),
                        backgroundColor: Color(0xFFFF6600),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  await _loadCarencias();
                  await _cargarDatos();
                  // Invalidar el caché del servicio para que Groq use este conocimiento
                  // en la próxima conversación sin esperar el TTL de 30 minutos.
                  CapacitacionService.invalidarCacheDistribuido();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al guardar: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
  icon: Icons.school_rounded,
  iconSize: 16,
  label: 'Guardar y Aprobar',
  style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
              ),
),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    final active = _selectedCategoryTab == tabKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategoryTab = tabKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.cyanAccent : Colors.white60,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingItemRow(Map<String, dynamic> item) {
    final intencion = item['intencion']?.toString() ?? '';
    final respuestaLimpia = item['respuesta_limpia']?.toString() ?? '';
    final libreria = item['libreria']?.toString() ?? 'resto';
    final puntaje = (item['puntaje'] as num?)?.toDouble() ?? 0.0;

    List<String> activadores = [];
    if (item['activadores'] is List) {
      activadores = List<String>.from(item['activadores'] as List);
    } else if (item['activadores'] is String) {
      try {
        activadores = List<String>.from(json.decode(item['activadores'] as String) as List);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intencion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Librería: $libreria',
                      style: TextStyle(
                        color: Colors.cyanAccent.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _puntajeBadge(puntaje),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Activadores:',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: activadores.map((act) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(
                  act,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Respuesta sugerida:',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Text(
              respuestaLimpia,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SafeTextIconButton(
  onPressed: () => _showEditDialog(item),
  icon: Icons.edit_rounded,
  iconSize: 16,
  iconColor: Colors.white60,
  label: 'Editar',
  textStyle: TextStyle(color: Colors.white60, fontSize: 12),
),
              const SizedBox(width: 8),
              SafeTextIconButton(
  onPressed: () => _rechazarIntencion(item),
  icon: Icons.delete_outline_rounded,
  iconSize: 16,
  iconColor: Colors.redAccent,
  label: 'Rechazar',
  textStyle: TextStyle(color: Colors.redAccent, fontSize: 12),
),
              const SizedBox(width: 8),
              SafeElevatedIconButton(
  onPressed: () => _aprobarIntencion(item),
  icon: Icons.check_rounded,
  iconSize: 16,
  iconColor: Colors.black,
  label: 'Aprobar',
  textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
),
            ],
          ),
        ],
      ),
    );
  }



}

/// Datos de un nivel del robot.
class _NivelInfo {
  final String nombre;
  final String emoji;
  final int    min;
  final int    max;
  final Color  color;
  const _NivelInfo({
    required this.nombre,
    required this.emoji,
    required this.min,
    required this.max,
    required this.color,
  });
}
