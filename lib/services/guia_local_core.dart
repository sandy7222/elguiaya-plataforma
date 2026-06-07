import 'dart:math';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:capitanya_master/models/pique_pulse.dart';

// ─────────────────────────────────────────────
//  MODELO: Acción offline pendiente de sincronizar
// ─────────────────────────────────────────────
part 'guia_local_core.g.dart';

@HiveType(typeId: 0)
class AccionOffline extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String tipo; // 'disputa', 'calificacion', 'reporte', etc.

  @HiveField(2)
  final Map<String, dynamic> payload;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  bool sincronizada;

  AccionOffline({
    required this.id,
    required this.tipo,
    required this.payload,
    required this.timestamp,
    this.sincronizada = false,
  });
}

// ─────────────────────────────────────────────
//  MODELO: Estado del personaje Gu-IA
// ─────────────────────────────────────────────
@HiveType(typeId: 1)
class EstadoGuia extends HiveObject {
  @HiveField(0)
  String estadoAnimo; // 'bostezando' | 'pescando' | 'durmiendo' | 'alerta' | 'modo_trinchera' | 'modo_conectado'

  @HiveField(1)
  DateTime ultimoParpadeo;

  @HiveField(2)
  DateTime ultimaActividad;

  @HiveField(3)
  bool conectado;

  EstadoGuia({
    this.estadoAnimo = 'pescando',
    DateTime? ultimoParpadeo,
    DateTime? ultimaActividad,
    this.conectado = true,
  })  : ultimoParpadeo = ultimoParpadeo ?? DateTime.now(),
        ultimaActividad = ultimaActividad ?? DateTime.now();
}

// ─────────────────────────────────────────────
//  SERVICIO PRINCIPAL: GuiaLocalCore
// ─────────────────────────────────────────────
class GuiaLocalCore {
  static const String _boxEstado = 'guia_estado';
  static const String _boxAcciones = 'guia_acciones_offline';
  static const String _keyEstado = 'estado_principal';

  static Box<EstadoGuia>? _estadoBox;
  static Box<AccionOffline>? _accionesBox;

  static Timer? _timerParpadeo;
  static Timer? _timerBostezo;

  // StreamController para que la UI escuche cambios en tiempo real
  static final StreamController<EstadoGuia> _estadoStream =
      StreamController<EstadoGuia>.broadcast();

  static Stream<EstadoGuia> get estadoStream => _estadoStream.stream;

  // ── INICIALIZACIÓN ──────────────────────────────────────────────
  static Future<void> inicializar() async {
    await Hive.initFlutter();

    // Registrar adaptadores (generados por hive_generator)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AccionOfflineAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EstadoGuiaAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PiquePulseAdapter());
    }

    _estadoBox = await Hive.openBox<EstadoGuia>(_boxEstado);
    _accionesBox = await Hive.openBox<AccionOffline>(_boxAcciones);

    // Crear estado inicial si no existe
    if (_estadoBox!.get(_keyEstado) == null) {
      await _estadoBox!.put(_keyEstado, EstadoGuia());
    }

    _iniciarTriggerVisuales();
  }

  // ── ESTADO ACTUAL ───────────────────────────────────────────────
  static EstadoGuia get estado =>
      _estadoBox?.get(_keyEstado) ?? EstadoGuia();

  static Future<void> actualizarEstado({
    String? estadoAnimo,
    bool? conectado,
  }) async {
    final actual = estado;
    if (estadoAnimo != null) actual.estadoAnimo = estadoAnimo;
    if (conectado != null) actual.conectado = conectado;
    await actual.save();
    _estadoStream.add(actual);
  }

  // ── REGISTRO DE ACTIVIDAD DEL USUARIO ──────────────────────────
  static Future<void> registrarActividad() async {
    final actual = estado;
    actual.ultimaActividad = DateTime.now();
    // Si estaba bostezando/durmiendo, volvemos a pescando
    if (actual.estadoAnimo == 'bostezando' || actual.estadoAnimo == 'durmiendo') {
      actual.estadoAnimo = 'pescando';
    }
    await actual.save();
    _estadoStream.add(actual);
  }

  // ─────────────────────────────────────────────────────────────────
  //  TRIGGERS VISUALES: Random math para animaciones orgánicas
  // ─────────────────────────────────────────────────────────────────
  static void _iniciarTriggerVisuales() {
    _programarProximoParpadeo();
    _programarProximoBostezo();
  }

  /// Parpadeo orgánico: cada 3 a 5 segundos (aleatorio)
  static void _programarProximoParpadeo() {
    _timerParpadeo?.cancel();
    final int segundos = 3 + Random().nextInt(3); // 3, 4 o 5 segundos
    _timerParpadeo = Timer(Duration(seconds: segundos), () async {
      final actual = estado;
      // Solo parpadea si no está en un estado de emoción especial
      if (!['durmiendo', 'modo_trinchera'].contains(actual.estadoAnimo)) {
        actual.ultimoParpadeo = DateTime.now();
        await actual.save();
        _estadoStream.add(actual);
      }
      _programarProximoParpadeo(); // Re-programa el siguiente ciclo
    });
  }

  /// Bostezo por inactividad: si el usuario no toca nada en 60-120 segundos
  static void _programarProximoBostezo() {
    _timerBostezo?.cancel();
    final int segundosEspera = 60 + Random().nextInt(61); // entre 60s y 120s
    _timerBostezo = Timer(Duration(seconds: segundosEspera), () async {
      final actual = estado;
      final inactivoDesde = DateTime.now().difference(actual.ultimaActividad).inSeconds;

      if (inactivoDesde >= 60 && actual.estadoAnimo == 'pescando') {
        // Primero bostezo, luego si sigue inactivo, duerme
        if (inactivoDesde < 120) {
          await actualizarEstado(estadoAnimo: 'bostezando');
        } else {
          await actualizarEstado(estadoAnimo: 'durmiendo');
        }
      }
      _programarProximoBostezo(); // Re-programa el ciclo
    });
  }

  static void detenerTriggers() {
    _timerParpadeo?.cancel();
    _timerBostezo?.cancel();
  }

  // ─────────────────────────────────────────────────────────────────
  //  BUZÓN DE ACCIONES OFFLINE
  // ─────────────────────────────────────────────────────────────────

  /// Encola una acción para sincronizar cuando haya señal
  static Future<void> encolarAccionOffline({
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    final accion = AccionOffline(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: tipo,
      payload: payload,
      timestamp: DateTime.now(),
    );
    await _accionesBox?.add(accion);
  }

  /// Lista de acciones pendientes de sincronización
  static List<AccionOffline> get accionesPendientes =>
      _accionesBox?.values.where((a) => !a.sincronizada).toList() ?? [];

  /// Marca una acción como sincronizada (la elimina del buzón activo)
  static Future<void> marcarSincronizada(AccionOffline accion) async {
    accion.sincronizada = true;
    await accion.save();
    await accion.delete(); // Limpia el registro local una vez confirmado
  }

  /// Cantidad de acciones pendientes (para badge en UI)
  static int get cantidadPendientes => accionesPendientes.length;

  // ── LIMPIEZA ────────────────────────────────────────────────────
  static Future<void> cerrar() async {
    detenerTriggers();
    await _estadoBox?.close();
    await _accionesBox?.close();
    await _estadoStream.close();
  }
}
