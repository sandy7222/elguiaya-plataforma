import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../widgets/confirm_descartar_presupuesto_dialog.dart';

/// Acciones compartidas sobre presupuestos recibidos por el pescador.
class PresupuestoPescadorActions {
  PresupuestoPescadorActions._();

  static String idDe(Map<String, dynamic> presupuesto) =>
      presupuesto['id']?.toString() ?? '';

  static String capitanNombreDe(Map<String, dynamic> presupuesto) =>
      presupuesto['profiles']?['nombre']?.toString() ??
      presupuesto['capitan_nombre']?.toString() ??
      'el capitán';

  static double montoDe(Map<String, dynamic> presupuesto) =>
      (presupuesto['monto_total'] as num?)?.toDouble() ??
      (presupuesto['monto'] as num?)?.toDouble() ??
      (presupuesto['total'] as num?)?.toDouble() ??
      0.0;

  /// Pide confirmación y marca el presupuesto como `descartado` en Supabase.
  /// `null` = canceló el diálogo; `true` = ok; `false` = error al guardar.
  static Future<bool?> descartarConConfirmacion(
    BuildContext context,
    Map<String, dynamic> presupuesto,
  ) async {
    final pid = idDe(presupuesto);
    if (pid.isEmpty) return false;

    final confirmado = await ConfirmDescartarPresupuestoDialog.show(
      context,
      capitanNombre: capitanNombreDe(presupuesto),
      monto: montoDe(presupuesto),
    );
    if (!confirmado) return null;

    return SupabaseService.descartarPresupuestoPescador(pid);
  }

  static void mostrarSnackDescartado(
    BuildContext context,
    Map<String, dynamic> presupuesto,
  ) {
    final nombre = capitanNombreDe(presupuesto);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🗑️ Presupuesto de $nombre descartado'),
        backgroundColor: const Color(0xFF0A1F35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  static void mostrarSnackError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo descartar el presupuesto. Intentá de nuevo.'),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
