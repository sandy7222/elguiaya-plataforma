import 'package:shared_preferences/shared_preferences.dart';

/// GeminiConfig — Interruptor maestro y control de cuota del modo educador.
///
/// Gestiona: API key, toggle on/off, contador diario, pausa por rate-limit.
/// Todo se persiste en SharedPreferences → configurable desde admin sin recompilar.
class GeminiConfig {
  // ── Claves SharedPreferences ──────────────────────────────────────────────
  static const String _keyEducadorActivo  = 'gemini_educador_activo';
  static const String _keyApiKey          = 'gemini_api_key';
  static const String _keyLimiteDiario    = 'gemini_limite_diario';
  static const String _keyConsultasHoy    = 'gemini_consultas_hoy';
  static const String _keyFechaContador   = 'gemini_fecha_contador';
  static const String _keyPausadaHasta    = 'gemini_pausada_hasta';
  static const String _keyTotalAprendidas = 'gemini_total_aprendidas';
  static const String _keyTotalPreguntas  = 'gemini_total_preguntas';
  static const String _keyUltimaActividad = 'gemini_ultima_actividad';

  // ── Constantes del modelo ──────────────────────────────────────────────────
  static const String modelo                  = 'gemini-2.5-flash';
  static const double umbralCalidad           = 6.0;
  static const int    maxCandidatos           = 200;
  static const int    minVecesConsolidar      = 3;
  static const int    limiteDiarioDefault     = 100;
  static const int    timeoutSegundos         = 8;
  static const int    pausaRateLimitMinutos   = 60;

  // ── Estado en memoria ─────────────────────────────────────────────────────
  static bool   _educadorActivo  = false;
  static String _apiKey          = '';
  static int    _limiteDiario    = limiteDiarioDefault;
  static int    _consultasHoy    = 0;
  static String _fechaContador   = '';
  static DateTime? _pausadaHasta;
  static int    _totalAprendidas = 0;
  static int    _totalPreguntas  = 0;
  static String _ultimaActividad = 'Sin actividad';
  static int    _totalConsultasTotal = 0;
  static String _motivoPausa = '';
  static int    _formatStrikes = 0;

  static int get formatStrikes => _formatStrikes;
  static String get motivoPausa => _motivoPausa;

  // ── Getters públicos ──────────────────────────────────────────────────────
  static bool   get educadorActivo  => _educadorActivo;
  static String get apiKey          => _apiKey;
  static int    get limiteDiario    => _limiteDiario;
  static int    get consultasHoy    => _consultasHoy;
  static int    get totalAprendidas => _totalAprendidas;
  static int    get totalPreguntas  => _totalPreguntas;
  static int    get totalConsultasTotal => _totalConsultasTotal;
  static String get ultimaActividad => _ultimaActividad;
  static bool   get tieneApiKey     => _apiKey.trim().isNotEmpty;

  /// true solo si puede hacer llamadas a Gemini ahora mismo.
  static bool get puedeConsultar {
    if (!_educadorActivo || !tieneApiKey) return false;
    if (_estaPausadaPorRateLimit()) return false;
    _verificarResetDiario();
    return _consultasHoy < _limiteDiario;
  }

  /// Razón por la que no puede consultar (para el panel admin).
  static String get estadoDescripcion {
    if (!_educadorActivo) return 'Educador apagado';
    if (!tieneApiKey)     return 'Sin API key';
    if (_estaPausadaPorRateLimit()) {
      final restante = _pausadaHasta!.difference(DateTime.now());
      final mins = restante.inMinutes + 1;
      final motivo = _motivoPausa == 'formato_invalido' ? 'formato inválido' : 'rate limit';
      return 'API pausada $mins min ($motivo)';
    }
    _verificarResetDiario();
    if (_consultasHoy >= _limiteDiario) {
      return 'Límite diario alcanzado ($_consultasHoy/$_limiteDiario)';
    }
    return 'Activo ($_consultasHoy/$_limiteDiario hoy)';
  }

  // ── Carga inicial ─────────────────────────────────────────────────────────

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _educadorActivo  = prefs.getBool(_keyEducadorActivo) ?? false;
    _apiKey          = prefs.getString(_keyApiKey) ?? '';
    _limiteDiario    = prefs.getInt(_keyLimiteDiario) ?? limiteDiarioDefault;
    _consultasHoy    = prefs.getInt(_keyConsultasHoy) ?? 0;
    _fechaContador   = prefs.getString(_keyFechaContador) ?? '';
    _totalAprendidas = prefs.getInt(_keyTotalAprendidas) ?? 0;
    _totalPreguntas  = prefs.getInt(_keyTotalPreguntas) ?? 0;
    _totalConsultasTotal = prefs.getInt('gemini_total_consultas_total') ?? 0;
    _ultimaActividad = prefs.getString(_keyUltimaActividad) ?? 'Sin actividad';

    final pausadaHastaMs = prefs.getInt(_keyPausadaHasta) ?? 0;
    if (pausadaHastaMs > 0) {
      _pausadaHasta = DateTime.fromMillisecondsSinceEpoch(pausadaHastaMs);
    }
    _motivoPausa = prefs.getString('gemini_motivo_pausa') ?? '';

    _verificarResetDiario();
  }

  // ── Setters del panel admin ───────────────────────────────────────────────

  static Future<void> setEducadorActivo(bool valor) async {
    _educadorActivo = valor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEducadorActivo, valor);
  }



  static Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, _apiKey);
  }

  static Future<void> setLimiteDiario(int limite) async {
    _limiteDiario = limite.clamp(10, 10000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLimiteDiario, _limiteDiario);
  }

  // ── Contadores de uso ─────────────────────────────────────────────────────

  static Future<void> registrarConsulta() async {
    _consultasHoy++;
    _totalPreguntas++;
    _ultimaActividad = _formatFecha(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConsultasHoy, _consultasHoy);
    await prefs.setInt(_keyTotalPreguntas, _totalPreguntas);
    await prefs.setString(_keyUltimaActividad, _ultimaActividad);
  }

  static Future<void> registrarConsultaTotal() async {
    _totalConsultasTotal++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gemini_total_consultas_total', _totalConsultasTotal);
  }

  static Future<void> incrementarAprendidas() async {
    _totalAprendidas++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalAprendidas, _totalAprendidas);
  }

  // ── Control de Rate Limit ─────────────────────────────────────────────────

  /// Activa la pausa de N minutos cuando Gemini devuelve 429.
  static Future<void> activarPausaRateLimit() async {
    _pausadaHasta = DateTime.now().add(
      const Duration(minutes: pausaRateLimitMinutos),
    );
    _motivoPausa = 'rate_limit';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPausadaHasta, _pausadaHasta!.millisecondsSinceEpoch);
    await prefs.setString('gemini_motivo_pausa', 'rate_limit');
  }

  static void resetStrikes() {
    _formatStrikes = 0;
  }

  /// Limpia manualmente la pausa activa (para el panel admin).
  static Future<void> limpiarPausa() async {
    _pausadaHasta = null;
    _motivoPausa  = '';
    _formatStrikes = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPausadaHasta, 0);
    await prefs.setString('gemini_motivo_pausa', '');
  }

  static Future<void> registrarStrike() async {
    _formatStrikes++;
    if (_formatStrikes >= 3) {
      _formatStrikes = 0;
      await activarPausaPorStrikes();
    }
  }

  static Future<void> activarPausaPorStrikes() async {
    _pausadaHasta = DateTime.now().add(const Duration(minutes: 30));
    _motivoPausa = 'formato_invalido';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPausadaHasta, _pausadaHasta!.millisecondsSinceEpoch);
    await prefs.setString('gemini_motivo_pausa', 'formato_invalido');
  }

  static bool _estaPausadaPorRateLimit() {
    if (_pausadaHasta == null) return false;
    if (DateTime.now().isAfter(_pausadaHasta!)) {
      _pausadaHasta = null;
      return false;
    }
    return true;
  }

  /// Resetea el contador si cambió el día.
  static void _verificarResetDiario() {
    final hoy = _fechaDeHoy();
    if (_fechaContador != hoy) {
      _fechaContador = hoy;
      _consultasHoy = 0;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_keyConsultasHoy, 0);
        prefs.setString(_keyFechaContador, hoy);
      });
    }
  }

  static String _fechaDeHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
