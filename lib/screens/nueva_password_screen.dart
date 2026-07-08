import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/cya_styles.dart';

/// Pantalla tras abrir el enlace de recuperación desde el email.
class NuevaPasswordScreen extends StatefulWidget {
  final VoidCallback? onCompletado;

  const NuevaPasswordScreen({super.key, this.onCompletado});

  @override
  State<NuevaPasswordScreen> createState() => _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends State<NuevaPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _visible = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (pass != confirm) {
      _mostrarError('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.updatePassword(pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      widget.onCompletado?.call();
    } on AuthException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      _mostrarError('No pudimos guardar la contraseña. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A33),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.password_rounded, color: CYAStyles.accentGreen, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Nueva contraseña',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elegí una contraseña segura para tu cuenta de El Guía YA.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _passwordController,
                obscureText: !_visible,
                style: const TextStyle(color: Colors.white),
                decoration: CYAStyles.inputDecoration(
                  label: 'Nueva contraseña',
                  icon: Icons.lock_outline,
                  accentColor: CYAStyles.accentGreen,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _visible = !_visible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: !_visible,
                style: const TextStyle(color: Colors.white),
                decoration: CYAStyles.inputDecoration(
                  label: 'Confirmar contraseña',
                  icon: Icons.lock_outline,
                  accentColor: CYAStyles.accentGreen,
                ),
              ),
              const SizedBox(height: 28),
              CYAStyles.primaryButton(
                label: 'GUARDAR CONTRASEÑA',
                onPressed: _guardar,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
