import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:capitanya_master/services/email_verification_policy.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/screens/bienvenida_definitiva_screen.dart';

class VerificarEmailScreen extends StatefulWidget {
  final String email;

  const VerificarEmailScreen({super.key, required this.email});

  @override
  State<VerificarEmailScreen> createState() => _VerificarEmailScreenState();
}

class _VerificarEmailScreenState extends State<VerificarEmailScreen> {
  static const Color _fondo = Color(0xFF001A33);
  static const Color _verde = Color(0xFF00E676);

  bool _isResending = false;
  bool _isChecking = false;
  String? _statusMessage;

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });
    try {
      await SupabaseService.resendSignupConfirmation(widget.email);
      if (mounted) {
        setState(() {
          _statusMessage =
              'Te reenviamos el correo. Revisá bandeja de entrada y spam.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No pudimos reenviar el correo. Intentá más tarde.';
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });
    try {
      final user = await SupabaseService.refreshAuthUser();
      if (!mounted) return;

      if (user != null && !EmailVerificationPolicy.requiresEmailVerification(user)) {
        return;
      }

      setState(() {
        _statusMessage =
            'Tu correo aún no está confirmado. Abrí el enlace del email y volvé a intentar.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No pudimos verificar el estado. Intentá de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BienvenidaDefinitivaScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.mark_email_unread_outlined, color: _verde, size: 72),
              const SizedBox(height: 24),
              const Text(
                'Confirmá tu correo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enviamos un enlace de verificación a:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _verde,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Abrí el correo en este dispositivo y tocá el enlace para activar tu cuenta. '
                'Es el mismo estándar de seguridad que exigen las apps de la Play Store.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'YA CONFIRMÉ MI CORREO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _resendEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('REENVIAR CORREO'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _signOut,
                child: const Text(
                  'Usar otra cuenta',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
