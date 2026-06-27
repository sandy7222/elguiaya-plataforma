import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pescador_viaje_snapshot.dart';
import '../services/supabase_service.dart';

class FichaPescadorScreen extends StatefulWidget {
  final String pedidoId;

  const FichaPescadorScreen({super.key, required this.pedidoId});

  @override
  State<FichaPescadorScreen> createState() => _FichaPescadorScreenState();
}

class _FichaPescadorScreenState extends State<FichaPescadorScreen> {
  bool _loading = true;
  String? _error;
  FichaPescadorData? _ficha;

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
      final raw = await SupabaseService.obtenerFichaPescador(widget.pedidoId);
      if (raw == null) {
        throw Exception('No se pudo cargar la planilla del pescador.');
      }
      if (mounted) {
        setState(() {
          _ficha = FichaPescadorData.fromRpc(raw);
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

  void _compartir() {
    final f = _ficha!;
    final s = f.snapshot;
    final buffer = StringBuffer()
      ..writeln('PLANILLA DEL PESCADOR — EL GUIA YA')
      ..writeln('Código viaje: ${s.txtCodigo("codigo_viaje")}')
      ..writeln('Pedido: ${s.txtCodigo("pedido_id_corto")}')
      ..writeln('Estado: ${f.estado}')
      ..writeln('')
      ..writeln('TITULAR: ${s.txtTitular("nombre_completo")}')
      ..writeln('DNI: ${s.txtTitular("dni")}')
      ..writeln('Teléfono: ${s.txtTitular("telefono")}')
      ..writeln('')
      ..writeln('ACOMPAÑANTES:');
    if (s.acompanantes.isEmpty) {
      buffer.writeln('• Sin acompañantes declarados');
    } else {
      for (final a in s.acompanantes) {
        buffer.writeln(
          '• ${a["nombre_completo"] ?? "${a["nombre"] ?? ""} ${a["apellido"] ?? ""}".trim()}'
          ' — DNI ${a["dni"] ?? "—"} — Tel ${a["telefono"] ?? "—"}',
        );
      }
    }
    buffer
      ..writeln('')
      ..writeln('CONTACTO DE CONTINGENCIA:')
      ..writeln('Nombre: ${s.txtContingencia("nombre")}')
      ..writeln('Teléfono: ${s.txtContingencia("telefono")}')
      ..writeln('')
      ..writeln('Datos declarados al momento de la reserva. No incluye documentación adjunta.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Planilla copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          'Planilla del Pescador',
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
    final avatarUrl = s.titular['avatar_url']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(f),
          const SizedBox(height: 12),
          _sectionCard(
            'Códigos del viaje',
            Icons.qr_code_2_rounded,
            [
              _row('Código viaje', s.txtCodigo('codigo_viaje')),
              _row('Pedido', '#${s.txtCodigo('pedido_id_corto')}'),
              _row('ID reserva', s.txtCodigo('pedido_id', '—')),
              if (s.codigos['cotizacion_id'] != null)
                _row('Cotización', s.txtCodigo('cotizacion_id', '—')),
              if (s.codigos['presupuesto_id'] != null)
                _row('Presupuesto', s.txtCodigo('presupuesto_id', '—')),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            'Pescador titular',
            Icons.person,
            [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _azul.withOpacity(0.1),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: _azul, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.txtTitular('nombre_completo'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _azul,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DNI ${s.txtTitular("dni")}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          s.txtTitular('telefono'),
                          style: const TextStyle(
                            color: _verde,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            'Acompañantes declarados',
            Icons.groups_outlined,
            s.acompanantes.isEmpty
                ? [
                    const Text(
                      'Sin acompañantes adicionales declarados.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ]
                : s.acompanantes
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['nombre_completo']?.toString().trim().isNotEmpty == true
                                  ? a['nombre_completo'].toString()
                                  : '${a['nombre'] ?? ''} ${a['apellido'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'DNI: ${a['dni'] ?? '—'}  •  Tel: ${a['telefono'] ?? '—'}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            'Contacto de contingencia',
            Icons.emergency_share_outlined,
            [
              _row('Nombre y apellido', s.txtContingencia('nombre')),
              _row('Teléfono', s.txtContingencia('telefono')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              'Estos datos corresponden a la declaración del pescador al momento de la reserva. '
              'No se muestran fotos de documentos.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(FichaPescadorData f) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2847), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLANILLA DEL PESCADOR',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            f.snapshot.txtCodigo('codigo_viaje'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${f.estado.toUpperCase()}',
            style: GoogleFonts.inter(color: _verde, fontWeight: FontWeight.bold),
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
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _azul,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
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
}
