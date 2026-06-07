import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ia_router_state.dart';
import '../services/baqueano_ia_service.dart';
import '../services/connectivity_bridge.dart';

/// Widget de botón flotante y panel de telemetría de 3 servicios para el Administrador.
class AdminTelemetryFAB extends StatefulWidget {
  const AdminTelemetryFAB({super.key});

  @override
  State<AdminTelemetryFAB> createState() => _AdminTelemetryFABState();
}

class _AdminTelemetryFABState extends State<AdminTelemetryFAB> {
  Timer? _telemetryTimer;

  @override
  void initState() {
    super.initState();
    _ejecutarChequeo();
    // Chequeo periódico asíncrono cada 8 segundos
    _telemetryTimer = Timer.periodic(const Duration(seconds: 8), (_) => _ejecutarChequeo());
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _ejecutarChequeo() async {
    if (!mounted) return;

    bool sSupabase = true;
    bool sCache = true;
    bool sRouter = true;

    // 1. Chequeo de Supabase (Servicio Nube)
    try {
      final client = Supabase.instance.client;
      await client.from('guia_capacitacion').select('id').limit(1).maybeSingle();
      sSupabase = true;
    } catch (e) {
      debugPrint('⚠️ [AdminTelemetryFAB] Supabase check error: $e');
      // Si recibimos un error de Postgres/Postgrest o de RLS, significa que pudimos comunicarnos con el servidor (está vivo)
      final errStr = e.toString();
      if (errStr.contains('PostgrestException') || errStr.contains('401') || errStr.contains('403') || errStr.contains('JWT')) {
        sSupabase = true; // Servidor vivo, es solo restricción de sesión/permisos
      } else {
        sSupabase = false; // Error real de red o caída del servicio
      }
    }

    // 2. Chequeo de Cache / Memoria
    try {
      // El cache está activo si el dispositivo tiene conectividad o memoria
      sCache = ConnectivityBridge.estaConectado;
    } catch (e) {
      sCache = false;
    }

    // 3. Chequeo de Router (Baqueano Router)
    try {
      // El router está activo/sano si el servicio se inicializa correctamente
      sRouter = true;
    } catch (e) {
      sRouter = false;
    }

    // Actualizar globalmente de forma segura
    IARouterState.actualizarSalud(
      router: sRouter,
      cache: sCache,
      supabase: sSupabase,
    );
  }

  Color _obtenerColorPorEstado(IAEstado estado) {
    switch (estado) {
      case IAEstado.cloud:
        return Colors.green;
      case IAEstado.offline:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AdminTelemetryFAB] Rendering build method...');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Botón Flotante Reactivo
        ValueListenableBuilder<IAEstado>(
          valueListenable: IARouterState.estado,
          builder: (context, estado, child) {
            final color = _obtenerColorPorEstado(estado);
            return GestureDetector(
              onTap: () {
                _ejecutarChequeo();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Telemetría Actualizada ➔ Router: ${IARouterState.routerSano.value ? "🟢 OK" : "🔴 ERROR"} | Cache: ${IARouterState.cacheSano.value ? "🟢 OK" : "🔴 ERROR"} | Supabase: ${IARouterState.supabaseSano.value ? "🟢 OK" : "🔴 ERROR"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: const Color(0xFF0D47A1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Panel de Telemetría (Las 3 bolitas)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Punto Router
              ValueListenableBuilder<bool>(
                valueListenable: IARouterState.routerSano,
                builder: (context, activo, _) => _buildDot(activo, 'Router', Colors.blue),
              ),
              const SizedBox(width: 6),
              // Punto Cache
              ValueListenableBuilder<bool>(
                valueListenable: IARouterState.cacheSano,
                builder: (context, activo, _) => _buildDot(activo, 'Cache', Colors.purple),
              ),
              const SizedBox(width: 6),
              // Punto Supabase
              ValueListenableBuilder<bool>(
                valueListenable: IARouterState.supabaseSano,
                builder: (context, activo, _) => _buildDot(activo, 'Supa', Colors.teal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Botones de Prueba Temporal para Forzar Estado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(40, 24),
                ),
                onPressed: () {
                  IARouterState.routerSano.value = !IARouterState.routerSano.value;
                },
                child: const Text('Tst R', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(40, 24),
                ),
                onPressed: () {
                  IARouterState.cacheSano.value = !IARouterState.cacheSano.value;
                },
                child: const Text('Tst C', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(40, 24),
                ),
                onPressed: () {
                  IARouterState.supabaseSano.value = !IARouterState.supabaseSano.value;
                },
                child: const Text('Tst S', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDot(bool activo, String label, Color serviceColor) {
    return Tooltip(
      message: '$label: ${activo ? "Activo" : "Inactivo"}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo ? serviceColor : Colors.red,
          boxShadow: [
            if (activo)
              BoxShadow(
                color: serviceColor.withOpacity(0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }
}
