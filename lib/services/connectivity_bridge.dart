import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'guia_local_core.dart';
import 'audio_service.dart';
import 'guia_knowledge_sync_service.dart';

// ─────────────────────────────────────────────────────────────────
//  Respuestas pre-grabadas de Gu-IA para Modo Trinchera (sin señal)
// ─────────────────────────────────────────────────────────────────
const List<String> _respuestasTrinchera = [
  '🎣 Sin señal en el río, pero acá estoy. Guardé todo lo que hiciste, lo subo cuando volvamos a zona.',
  '📡 El río se tragó la señal. No te preocupes, tus acciones están en mi buzón seguro.',
  '🌊 Estamos en modo explorador. Funciono sin internet, cuando aparezca la señal sincronizo todo.',
  '⚓ Capitán, navego offline. Tus reportes y calificaciones los tengo guardados, no se pierde nada.',
  '🐟 Sin conexión, pero operativo. Cuando haya señal, vacío el buzón directo a Supabase.',
  '🛶 Modo río: sin Wi-Fi ni datos. Tus movimientos están anotados en mi bitácora local.',
];

// Respuestas para cuando vuelve la señal
const List<String> _respuestasReconexion = [
  '✅ ¡Señal recuperada! Sincronizando tu buzón de acciones pendientes...',
  '🚀 ¡Volvemos a estar conectados! Enviando tus datos pendientes a la nube.',
  '📶 Conexión restablecida. Subiendo todo lo que guardé mientras estabas offline.',
];

// ─────────────────────────────────────────────────────────────────
//  CENTINELA DE CONECTIVIDAD HÍBRIDA
// ─────────────────────────────────────────────────────────────────
class ConnectivityBridge {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Stream público para que la UI escuche el estado de conexión
  static final StreamController<bool> _conexionStream =
      StreamController<bool>.broadcast();
  static Stream<bool> get conexionStream => _conexionStream.stream;

  static bool _conectado = true;
  static bool get estaConectado => _conectado;

  // ── INICIALIZACIÓN DEL CENTINELA ────────────────────────────────
  static Future<void> inicializar() async {
    // Estado inicial al arrancar
    final resultados = await _connectivity.checkConnectivity();
    await _evaluarConectividad(resultados);

    // Escuchar cambios en tiempo real
    _subscription = _connectivity.onConnectivityChanged.listen(
      (resultados) async {
        await _evaluarConectividad(resultados);
      },
    );
  }

  // ── EVALUACIÓN DEL ESTADO DE RED ────────────────────────────────
  static Future<void> _evaluarConectividad(List<ConnectivityResult> resultados) async {
    final bool haySenal = resultados.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (haySenal == _conectado) return; // Sin cambio, no hacer nada

    _conectado = haySenal;
    _conexionStream.add(_conectado);

    if (!_conectado) {
      await _activarModoTrinchera();
    } else {
      await _activarModoConectado();
    }
  }

  // ── MODO TRINCHERA (SIN SEÑAL) ──────────────────────────────────
  static Future<void> _activarModoTrinchera() async {
    await GuiaLocalCore.actualizarEstado(
      estadoAnimo: 'modo_trinchera',
      conectado: false,
    );
    // Pre-cargar respuestas ingeniosas sobre el río
    _cachearRespuestasTrinchera();
  }

  static void _cachearRespuestasTrinchera() {
    // Las respuestas ya están en memoria como const, listas para ser
    // servidas sin necesidad de red.
    // En una expansión futura se podrían persistir en Hive también.
  }

  /// Devuelve una respuesta aleatoria pre-grabada para modo offline
  static String obtenerRespuestaTrinchera() {
    final index = DateTime.now().millisecondsSinceEpoch % _respuestasTrinchera.length;
    return _respuestasTrinchera[index];
  }

  /// Devuelve mensaje de reconexión
  static String obtenerMensajeReconexion() {
    final index = DateTime.now().millisecondsSinceEpoch % _respuestasReconexion.length;
    return _respuestasReconexion[index];
  }

  // ── MODO CONECTADO (HAY SEÑAL) ──────────────────────────────────
  static Future<void> _activarModoConectado() async {
    await GuiaLocalCore.actualizarEstado(
      estadoAnimo: 'modo_conectado',
      conectado: true,
    );

    // Notificación de voz sobre la recuperación de señal
    AudioService().speak('Chamigo, recuperamos señal — vuelvo a estar con todo el motor online.');

    // Vaciar buzón offline en segundo plano
    await _sincronizarBuzonOffline();

    // Sincronizar conocimiento El Guía al reconectarse
    GuiaKnowledgeSyncService.verificarYEjecutarSincronizaciones();
  }

  // ─────────────────────────────────────────────────────────────────
  //  GOTEO DE DATOS INTELIGENTE — Throttling por lotes de 3 acciones
  // ─────────────────────────────────────────────────────────────────
  static const int _tamanoLote = 3;
  static const Duration _pausaEntreLotes = Duration(milliseconds: 500);

  static Future<void> _sincronizarBuzonOffline() async {
    final pendientes = GuiaLocalCore.accionesPendientes;
    if (pendientes.isEmpty) {
      await GuiaLocalCore.actualizarEstado(estadoAnimo: 'pescando');
      return;
    }

    final supabase = Supabase.instance.client;

    // ── Partir la lista en lotes de máximo 3 elementos ──────────────
    final lotes = <List<AccionOffline>>[];
    for (int i = 0; i < pendientes.length; i += _tamanoLote) {
      lotes.add(
        pendientes.sublist(
          i,
          (i + _tamanoLote).clamp(0, pendientes.length),
        ),
      );
    }

    // ── Procesar lote por lote ──────────────────────────────────────
    for (int indexLote = 0; indexLote < lotes.length; indexLote++) {
      // CORTE INMEDIATO: verificar señal antes de cada lote
      if (!_conectado) {
        await GuiaLocalCore.actualizarEstado(estadoAnimo: 'modo_trinchera_alerta');
        // ignore: avoid_print
        print('🔴 [ConnectivityBridge] Señal perdida en lote $indexLote — bucle interrumpido. '
            '${pendientes.length - (indexLote * _tamanoLote)} acción(es) permanecen en Hive.');
        return;
      }

      final lote = lotes[indexLote];
      // ignore: avoid_print
      print('📦 [ConnectivityBridge] Procesando lote ${indexLote + 1}/${lotes.length} '
          '(${lote.length} acción/es)...');

      // ── Procesar cada acción del lote con confirmación transaccional
      for (final accion in lote) {
        // MICRO-CORTE: verificar señal acción por acción dentro del lote
        if (!_conectado) {
          await GuiaLocalCore.actualizarEstado(estadoAnimo: 'modo_trinchera_alerta');
          return;
        }

        try {
          await _impactarEnSupabase(supabase, accion);

          // Confirmación exitosa → eliminación definitiva del box Hive
          await GuiaLocalCore.marcarSincronizada(accion);
          // ignore: avoid_print
          print('✅ [ConnectivityBridge] Acción "${accion.tipo}" (id:${accion.id}) sincronizada y eliminada del buzón.');

        } on TimeoutException catch (e) {
          // Timeout de red → corte inmediato, registros intactos en Hive
          await GuiaLocalCore.actualizarEstado(estadoAnimo: 'modo_trinchera_alerta');
          // ignore: avoid_print
          print('⏱️ [ConnectivityBridge] Timeout en lote $indexLote: $e — interrumpiendo sincronización.');
          return;

        } catch (e) {
          // Error puntual de servidor → acción permanece en Hive para próximo intento
          // ignore: avoid_print
          print('⚠️ [ConnectivityBridge] Fallo en acción "${accion.tipo}": $e — conservada en buzón.');
          // No hacemos return: seguimos con el resto del lote
        }
      }

      // ── Pausa de seguridad entre lotes para no ahogar la red celular
      final esUltimoLote = indexLote == lotes.length - 1;
      if (!esUltimoLote) {
        // ignore: avoid_print
        print('⏳ [ConnectivityBridge] Pausa $_pausaEntreLotes entre lotes...');
        await Future.delayed(_pausaEntreLotes);
      }
    }

    // ── Todos los lotes procesados exitosamente ─────────────────────
    final restantes = GuiaLocalCore.cantidadPendientes;
    if (restantes == 0) {
      // ignore: avoid_print
      print('🎉 [ConnectivityBridge] Buzón offline vaciado completamente.');
      await GuiaLocalCore.actualizarEstado(estadoAnimo: 'pescando');
    } else {
      // Algunos fallaron puntualmente, pero no hubo corte de red
      // ignore: avoid_print
      print('⚠️ [ConnectivityBridge] Sincronización completada con $restantes acción(es) pendiente(s) por reintentar.');
      await GuiaLocalCore.actualizarEstado(estadoAnimo: 'alerta');
    }
  }

  // ── ROUTER DE IMPACTO EN SUPABASE (con Timeout individual de 10s) ─
  static Future<void> _impactarEnSupabase(
    SupabaseClient supabase,
    AccionOffline accion,
  ) async {
    const timeoutPorAccion = Duration(seconds: 10);

    Future<void> operacion() async {
      switch (accion.tipo) {
        case 'disputa':
          await supabase.from('disputas').insert(accion.payload);
          break;
        case 'calificacion':
          await supabase.from('calificaciones').insert(accion.payload);
          break;
        case 'reporte':
          await supabase.from('reportes_usuario').insert(accion.payload);
          break;
        case 'badge_afip':
          await supabase
              .from('facturas_afip')
              .update(accion.payload)
              .eq('id', accion.payload['id'] as String);
          break;
        default:
          // Tabla dinámica basada en el tipo de la acción
          await supabase.from(accion.tipo).insert(accion.payload);
          break;
      }
    }

    // Envuelto en timeout individual para detección de corte silencioso
    await operacion().timeout(timeoutPorAccion);
  }

  // ── ENCOLAR ACCIONES DESDE LA UI ───────────────────────────────
  /// Punto de entrada único para registrar acciones del usuario.
  /// Si hay señal → ejecuta directo en Supabase.
  /// Si no hay señal → encola en el buzón local de Hive.
  static Future<void> ejecutarOEncolar({
    required String tipo,
    required Map<String, dynamic> payload,
    Future<void> Function()? accionOnline,
  }) async {
    if (_conectado && accionOnline != null) {
      try {
        await accionOnline();
        return;
      } catch (_) {
        // Si falla online, cae al offline como fallback
      }
    }

    // Sin señal o con fallo: guardar en buzón local
    await GuiaLocalCore.encolarAccionOffline(tipo: tipo, payload: payload);
  }

  // ── LIMPIEZA ────────────────────────────────────────────────────
  static Future<void> cerrar() async {
    await _subscription?.cancel();
    await _conexionStream.close();
  }
}
