import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Diálogo compartido al descartar una oferta/presupuesto de capitán.
class ConfirmDescartarPresupuestoDialog extends StatelessWidget {
  final String capitanNombre;
  final double monto;

  const ConfirmDescartarPresupuestoDialog({
    super.key,
    required this.capitanNombre,
    required this.monto,
  });

  static Future<bool> show(
    BuildContext context, {
    required String capitanNombre,
    required double monto,
  }) {
    return showDialog<bool>(
          context: context,
          barrierColor: Colors.black87,
          builder: (_) => ConfirmDescartarPresupuestoDialog(
            capitanNombre: capitanNombre,
            monto: monto,
          ),
        ).then((v) => v == true);
  }

  @override
  Widget build(BuildContext context) {
    const card = Color(0xFF0D2847);
    const cardBorder = Color(0xFF1A3A5C);
    const rojo = Color(0xFFEF4444);
    const verde = Color(0xFF00C853);
    const blanco = Colors.white;
    const grisTexto = Color(0xFF8BA4BC);

    final montoFmt = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    ).format(monto);

    return Dialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rojo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: rojo, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Descartás esta cotización?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: blanco,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(color: grisTexto, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'Vas a eliminar la propuesta de '),
                  TextSpan(
                    text: capitanNombre,
                    style: const TextStyle(color: blanco, fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' por '),
                  TextSpan(
                    text: montoFmt,
                    style: const TextStyle(color: verde, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        '.\n\nSolo se borra este ticket. Tu solicitud de viaje seguirá activa.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: grisTexto, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: rojo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Sí, descartar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
