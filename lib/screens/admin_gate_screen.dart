import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Estado del candado del panel de administración.
///
/// El desbloqueo se guarda SOLO en memoria (no en localStorage ni disco): al
/// cerrar o recargar la ventana/pestaña se pierde y se vuelve a pedir la
/// contraseña. Esto es intencional para que el panel admin nunca quede
/// accesible con solo tener una sesión de Supabase persistida.
class AdminSessionLock {
  AdminSessionLock._();

  static bool _desbloqueado = false;

  static bool get desbloqueado => _desbloqueado;

  static void desbloquear() => _desbloqueado = true;

  /// Se llama al cerrar sesión para volver a bloquear.
  static void bloquear() => _desbloqueado = false;
}

/// Envuelve una pantalla de administración exigiendo re-autenticación con
/// contraseña, incluso si ya existe una sesión de Supabase activa.
class AdminGate extends StatefulWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final TextEditingController _passCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _verificando = false;
  bool _obscure = true;
  String? _error;

  static const Color _azul = Color(0xFF001F3F);
  static const Color _verde = Color(0xFF00E676);

  @override
  void dispose() {
    _passCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final pass = _passCtrl.text;

    if (email == null || email.isEmpty) {
      setState(() => _error = 'No hay una sesión activa. Iniciá sesión de nuevo.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña.');
      return;
    }

    setState(() {
      _verificando = true;
      _error = null;
    });

    try {
      // Verifica la contraseña re-autenticando al mismo usuario admin.
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      AdminSessionLock.desbloquear();
      if (mounted) {
        setState(() => _verificando = false);
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _verificando = false;
          _error = 'Contraseña incorrecta.';
          _passCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verificando = false;
          _error = 'No se pudo verificar. Revisá tu conexión e intentá de nuevo.';
        });
      }
    }
  }

  Future<void> _salir() async {
    AdminSessionLock.bloquear();
    await SupabaseService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (AdminSessionLock.desbloqueado) {
      return widget.child;
    }

    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF00122B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: _verde),
                const SizedBox(height: 16),
                const Text(
                  'Panel de Administración',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Por seguridad, confirmá tu contraseña para entrar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _passCtrl,
                  focusNode: _focus,
                  autofocus: true,
                  obscureText: _obscure,
                  enabled: !_verificando,
                  onSubmitted: (_) => _verificar(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _verde),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _verificando ? null : _verificar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: _azul,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _verificando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _azul,
                            ),
                          )
                        : const Text(
                            'ENTRAR AL PANEL',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _verificando ? null : _salir,
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
