import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/contrato_viaje_snapshot.dart';
import '../services/supabase_service.dart';
import '../widgets/safe_button.dart';
import 'capitan_vidriera_public_screen.dart';
import 'chat_screen.dart';

class FichaContractualScreen extends StatefulWidget {
  final String pedidoId;

  const FichaContractualScreen({super.key, required this.pedidoId});

  @override
  State<FichaContractualScreen> createState() => _FichaContractualScreenState();
}

class _FichaContractualScreenState extends State<FichaContractualScreen> {
  bool _loading = true;
  String? _error;
  FichaContractualData? _ficha;

  static const _azul = Color(0xFF0D2847);
  static const _verde = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await SupabaseService.obtenerFichaContractual(widget.pedidoId);
      if (raw == null) {
        throw Exception('No se pudo cargar la ficha contractual.');
      }
      if (mounted) {
        setState(() {
          _ficha = FichaContractualData.fromRpc(raw);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _fmtFecha(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  String _fmtVencimiento(String? raw) {
    if (raw == null || raw.isEmpty) return 'No informado';
    return _fmtFecha(raw);
  }

  Widget _badgeVencimiento(String? raw) {
    if (raw == null || raw.isEmpty) {
      return _chip('Sin fecha', Colors.grey);
    }
    final fecha = DateTime.tryParse(raw);
    if (fecha == null) return _chip('Sin fecha', Colors.grey);
    final dias = fecha.difference(DateTime.now()).inDays;
    if (dias < 0) return _chip('Vencido', Colors.redAccent);
    if (dias <= 30) return _chip('Por vencer', Colors.orange);
    return _chip('Vigente', _verde);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<String> _serviciosIncluidos(ContratoViajeSnapshot s) {
    final list = <String>[];
    final carnada = s.txt('servicios', 'carnada', '');
    if (carnada.isNotEmpty && carnada.toLowerCase() != 'no') {
      list.add('Carnada: $carnada');
    }
    if (s.servicios['lenia']?.toString() == 'true') list.add('Leña incluida');
    if (s.servicios['almacen']?.toString() == 'true') list.add('Almacén / depósito');
    if (s.servicios['cabania']?.toString() == 'true') list.add('Cabaña');
    if (s.servicios['banio']?.toString() == 'true') list.add('Baño');
    if (s.servicios['parrilla']?.toString() == 'true') list.add('Parrilla');
    if (list.isEmpty) list.add('Consultar detalle con el capitán');
    return list;
  }

  void _compartir() {
    final f = _ficha!;
    final s = f.snapshot;
    final buffer = StringBuffer()
      ..writeln('FICHA CONTRACTUAL DE VIAJE — EL GUIA YA')
      ..writeln('Pedido: ${f.pedidoId}')
      ..writeln('Estado: ${f.estado}')
      ..writeln('')
      ..writeln('CAPITÁN: ${s.txt("capitan", "nombre")}')
      ..writeln('Legajo: ${s.txt("capitan", "expediente")}')
      ..writeln('Carnet timonel N°: ${s.txt("capitan", "numero_carnet")}')
      ..writeln('Venc. carnet: ${_fmtVencimiento(s.capitan["vencimiento_carnet"]?.toString())}')
      ..writeln('Aseguradora: ${s.txt("capitan", "aseguradora")}')
      ..writeln('Tipo seguro: ${s.txt("capitan", "tipo_seguro")}')
      ..writeln('Venc. seguro: ${_fmtVencimiento(s.capitan["vencimiento_seguro"]?.toString())}')
      ..writeln('')
      ..writeln('EMBARCACIÓN: ${s.txt("embarcacion", "barco_nombre")}')
      ..writeln('')
      ..writeln('VIAJE: ${s.txt("viaje", "descripcion")}')
      ..writeln('Fecha: ${_fmtFecha(s.viaje["fecha_ida"]?.toString())}')
      ..writeln('Hora encuentro: ${s.txt("viaje", "hora_encuentro", "—")}')
      ..writeln('Lugar: ${s.txt("viaje", "lugar_encuentro", "A convenir")}')
      ..writeln('Pasajeros: ${s.txt("viaje", "cantidad_personas", "—")}')
      ..writeln('')
      ..writeln('MONTO ACORDADO: \$${(f.montoTotal ?? (s.oferta["monto"] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}')
      ..writeln('Detalle oferta: ${s.txt("oferta", "detalles", "—")}')
      ..writeln('')
      ..writeln('Servicios incluidos al momento del acuerdo:')
      ..writeln(_serviciosIncluidos(s).map((e) => '• $e').join('\n'));

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ficha copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          'Ficha Contractual',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        actions: [
          if (_ficha != null)
            IconButton(
              onPressed: _compartir,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _azul))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final f = _ficha!;
    final s = f.snapshot;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerCard(f),
                const SizedBox(height: 12),
                _sectionCard(
                  'Capitán y habilitaciones',
                  Icons.sailing,
                  [
                    _row('Nombre', s.txt('capitan', 'nombre')),
                    _row('Teléfono', s.txt('capitan', 'telefono')),
                    _row('Legajo plataforma', s.txt('capitan', 'expediente')),
                    _row('Carnet timonel N°', s.txt('capitan', 'numero_carnet')),
                    _rowWithBadge(
                      'Vencimiento carnet',
                      _fmtVencimiento(s.capitan['vencimiento_carnet']?.toString()),
                      _badgeVencimiento(s.capitan['vencimiento_carnet']?.toString()),
                    ),
                    const Divider(height: 20),
                    _row('Aseguradora', s.txt('capitan', 'aseguradora')),
                    _row('Tipo de seguro', s.txt('capitan', 'tipo_seguro')),
                    _row('N° póliza', s.txt('capitan', 'numero_poliza')),
                    _rowWithBadge(
                      'Vencimiento seguro',
                      _fmtVencimiento(s.capitan['vencimiento_seguro']?.toString()),
                      _badgeVencimiento(s.capitan['vencimiento_seguro']?.toString()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Embarcación',
                  Icons.directions_boat,
                  [
                    _row('Nombre', s.txt('embarcacion', 'barco_nombre')),
                    _row(
                      'Capacidad',
                      '${s.txt("embarcacion", "capacidad_personas", "—")} pers. / '
                          '${s.txt("embarcacion", "capacidad_kilos", "—")} kg',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Detalle del viaje',
                  Icons.event,
                  [
                    _row('Actividad', s.txt('viaje', 'descripcion')),
                    _row('Fecha', _fmtFecha(s.viaje['fecha_ida']?.toString())),
                    _row('Hora encuentro', s.txt('viaje', 'hora_encuentro', '—')),
                    _row('Punto de encuentro', s.txt('viaje', 'lugar_encuentro', 'A convenir')),
                    _row('Pasajeros', s.txt('viaje', 'cantidad_personas', '—')),
                    _row('Distancia', '${s.txt("viaje", "distancia_km", "—")} km'),
                    _row(
                      'Monto acordado',
                      '\$${(f.montoTotal ?? (s.oferta["monto"] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    ),
                    _row('Detalle oferta', s.txt('oferta', 'detalles', '—')),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Servicios incluidos (acuerdo)',
                  Icons.check_circle_outline,
                  _serviciosIncluidos(s)
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check, color: _verde, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(t)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade100),
                  ),
                  child: Text(
                    'Los servicios listados corresponden al acuerdo registrado al momento de la reserva. '
                    'Para mercadería adicional del capitán, consultá su Vidriera.',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.blueGrey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
        _bottomActions(f),
      ],
    );
  }

  Widget _headerCard(FichaContractualData f) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azul, Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FICHA CONTRACTUAL DE VIAJE',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pedido ${f.pedidoId.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _verde.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              f.estado.toUpperCase(),
              style: const TextStyle(
                color: _verde,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _azul, size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _azul,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithBadge(String label, String value, Widget badge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                badge,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions(FichaContractualData f) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeOutlinedButton(
            onPressed: f.capitanId == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CapitanVidrieraPublicScreen(
                          capitanId: f.capitanId!,
                          pedidoId: f.pedidoId,
                          nombreCapitan: f.snapshot.txt('capitan', 'nombre'),
                          fechaViaje: f.snapshot.viaje['fecha_ida']?.toString(),
                        ),
                      ),
                    );
                  },
            icon: Icons.storefront_outlined,
            label: 'Ver Vidriera del capitán',
          ),
          const SizedBox(height: 8),
          SafeElevatedButton(
            onPressed: f.puedeVerContacto
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          reservaId: f.pedidoId,
                          nombreServicio: f.snapshot.txt('viaje', 'descripcion', 'Viaje'),
                          nombreCliente: f.snapshot.txt('capitan', 'nombre'),
                        ),
                      ),
                    );
                  }
                : null,
            icon: Icons.message_outlined,
            label: 'Chatear con el capitán',
            style: ElevatedButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            iconColor: Colors.white,
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
