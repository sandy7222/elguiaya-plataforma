import 'package:supabase_flutter/supabase_flutter.dart';

/// Política de verificación de email al estilo Play Store.
///
/// Usuarios registrados antes de [policyStartUtc] quedan exentos (grandfather).
/// Los nuevos registros deben confirmar su correo antes de acceder a la app.
class EmailVerificationPolicy {
  EmailVerificationPolicy._();

  /// Fecha UTC desde la cual exigimos confirmación de email en nuevos registros.
  static final DateTime policyStartUtc = DateTime.utc(2026, 7, 6);

  /// Redirect para el enlace de confirmación en Android/iOS.
  static const String authRedirectUrl = 'capitanya://auth/callback';

  static bool isEmailVerified(User user) => user.emailConfirmedAt != null;

  static DateTime? _parseCreatedAt(User user) {
    final raw = user.createdAt;
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Usuario de prueba/producción anterior a la política: no bloquear.
  static bool isGrandfathered(User user) {
    final createdAt = _parseCreatedAt(user);
    if (createdAt == null) return false;
    return createdAt.isBefore(policyStartUtc);
  }

  static bool isAdminBypass(User user) {
    final email = user.email?.toLowerCase().trim() ?? '';
    if (email == 'admin@capitanya.com' || email == 'admin@elguiaya.com') {
      return true;
    }
    final rol = user.userMetadata?['rol']?.toString().toLowerCase();
    return rol == 'admin';
  }

  /// ¿Debe ver la pantalla de verificación y quedar fuera del portal?
  static bool requiresEmailVerification(User user) {
    if (isAdminBypass(user)) return false;
    if (isEmailVerified(user)) return false;
    if (isGrandfathered(user)) return false;
    return true;
  }
}
