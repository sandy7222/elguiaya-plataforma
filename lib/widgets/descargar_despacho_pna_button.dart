import 'package:flutter/material.dart';

import '../services/despacho_pna_service.dart';
import '../services/pdf_service.dart';
import '../widgets/safe_button.dart';

/// Botón para imprimir/compartir el despacho PNA precargado desde la reserva.
class DescargarDespachoPnaButton extends StatefulWidget {
  final String pedidoId;
  final bool compact;

  const DescargarDespachoPnaButton({
    super.key,
    required this.pedidoId,
    this.compact = false,
  });

  @override
  State<DescargarDespachoPnaButton> createState() =>
      _DescargarDespachoPnaButtonState();
}

class _DescargarDespachoPnaButtonState extends State<DescargarDespachoPnaButton> {
  bool _generando = false;
  bool _consultando = true;
  DespachoPnaElegibilidad? _elegibilidad;

  @override
  void initState() {
    super.initState();
    _refrescarEstado();
  }

  Future<void> _refrescarEstado() async {
    setState(() => _consultando = true);
    final resultado = await DespachoPnaService.consultarEstado(widget.pedidoId);
    if (!mounted) return;
    setState(() {
      _elegibilidad = resultado.elegibilidad;
      _consultando = false;
    });
  }

  Future<void> _onPressed() async {
    if (_generando) return;
    setState(() => _generando = true);

    try {
      final resultado = await DespachoPnaService.cargarParaPedido(widget.pedidoId);
      if (!mounted) return;

      if (!resultado.puedeGenerar || resultado.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado.mensaje),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _refrescarEstado();
        return;
      }

      final data = resultado.data!;
      final accion = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF001F3F),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Despacho PNA precargado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ya incluye capitán, embarcación, horarios de zarpa/regreso, '
                  'cliente y acompañantes. Solo imprimí, firmá y llevá a Prefectura.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                SafeElevatedIconButton(
                  onPressed: () => Navigator.pop(context, 'imprimir'),
                  icon: Icons.print_rounded,
                  label: 'Imprimir',
                ),
                const SizedBox(height: 10),
                SafeOutlinedIconButton(
                  onPressed: () => Navigator.pop(context, 'compartir'),
                  icon: Icons.share_rounded,
                  label: 'Guardar PDF / Compartir',
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E676),
                    side: const BorderSide(color: Color(0xFF00E676)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted || accion == null) return;

      if (accion == 'imprimir') {
        await PdfService.generarDespachoPna(data);
      } else if (accion == 'compartir') {
        await PdfService.compartirDespachoPna(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el despacho: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Widget _badgeEstado() {
    if (_consultando) {
      return Text(
        'Verificando datos precargados…',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
      );
    }

    if (_elegibilidad == DespachoPnaElegibilidad.listo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Precargado — listo para imprimir, firmar y presentar',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      _mensajePendiente(_elegibilidad),
      style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
    );
  }

  String _mensajePendiente(DespachoPnaElegibilidad? estado) {
    switch (estado) {
      case DespachoPnaElegibilidad.viajeNoConfirmado:
        return 'Disponible cuando el viaje esté confirmado y pagado.';
      case DespachoPnaElegibilidad.sinManifiesto:
        return 'Falta la declaración de pasajeros en el checkout.';
      case DespachoPnaElegibilidad.faltanFechasNacimiento:
        return 'Completá fecha de nacimiento de todos los pasajeros.';
      case DespachoPnaElegibilidad.pedidoNoEncontrado:
        return 'Pedido no encontrado.';
      default:
        return 'Completá los datos del viaje para precargar el despacho.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _badgeEstado(),
          const SizedBox(height: 8),
          SafeOutlinedIconButton(
            onPressed: (_generando || _elegibilidad != DespachoPnaElegibilidad.listo)
                ? null
                : _onPressed,
            icon: Icons.description_outlined,
            label: _generando ? 'Generando…' : 'Despacho PNA',
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFF1565C0)),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sailing_rounded, color: Color(0xFF1565C0), size: 20),
              SizedBox(width: 8),
              Text(
                'Despacho Prefectura Naval (precargado)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El sistema completa el formulario con los datos de la reserva. '
            'Vos solo imprimís, firmás y lo presentás.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _badgeEstado(),
          const SizedBox(height: 12),
          SafeElevatedIconButton(
            onPressed: (_generando || _elegibilidad != DespachoPnaElegibilidad.listo)
                ? null
                : _onPressed,
            icon: Icons.picture_as_pdf_rounded,
            label: _generando ? 'Generando PDF…' : 'Imprimir / Guardar despacho',
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
