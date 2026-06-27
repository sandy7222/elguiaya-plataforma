import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ficha_contractual_screen.dart';
import 'ficha_pescador_screen.dart';
import 'capitan_vidriera_public_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TICKET DE EMBARQUE — Vista del PESCADOR (cliente)
// Se abre desde "Próximos viajes" una vez que el viaje está confirmado/pagado.
// Muestra: datos públicos del capitán, embarcación, servicios prometidos,
// teléfono (desbloqueado tras el pago), pasajeros declarados y punto de encuentro.
// ══════════════════════════════════════════════════════════════════════════════

class TicketEmbarqueScreen extends StatefulWidget {
  final String pedidoId;

  const TicketEmbarqueScreen({super.key, required this.pedidoId});

  @override
  State<TicketEmbarqueScreen> createState() => _TicketEmbarqueScreenState();
}

class _TicketEmbarqueScreenState extends State<TicketEmbarqueScreen> {
  final _supabase = Supabase.instance.client;

  // ─── Estado ───────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _pedido;
  Map<String, dynamic>? _cotizacion;
  Map<String, dynamic>? _presupuesto;
  Map<String, dynamic>? _capitan;      // perfil público del capitán
  Map<String, dynamic>? _guiaData;    // datos extra de la tabla guias
  List<Map<String, dynamic>> _pasajeros = [];

  // ─── Paleta ───────────────────────────────────────────────────────────────
  static const _azul      = Color(0xFF0D2847);
  static const _azulBrillo= Color(0xFF1E88E5);
  static const _verde     = Color(0xFF00C853);
  static const _naranja   = Color(0xFFF59E0B);
  static const _rojo      = Color(0xFFEF4444);
  static const _gris      = Color(0xFF8BA4BC);
  static const _card      = Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CARGA DE DATOS REALES
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Pedido
      final pedido = await _supabase
          .from('pedidos')
          .select('*')
          .eq('id', widget.pedidoId)
          .single();

      final capitanId   = pedido['capitan_id']?.toString() ?? '';
      final cotizacionId = pedido['cotizacion_id']?.toString() ?? '';
      final pedidoId     = pedido['id']?.toString() ?? '';

      // 2. Cotización (datos del viaje)
      Map<String, dynamic>? cotizacion;
      if (cotizacionId.isNotEmpty) {
        cotizacion = await _supabase
            .from('cotizaciones')
            .select('*')
            .eq('id', cotizacionId)
            .maybeSingle();
      }

      // 3. Presupuesto aceptado
      Map<String, dynamic>? presupuesto;
      if (cotizacionId.isNotEmpty) {
        final pres = await _supabase
            .from('presupuestos')
            .select('*')
            .eq('cotizacion_id', cotizacionId)
            .inFilter('estado', ['aceptado', 'pagado'])
            .order('created_at', ascending: false)
            .limit(1);
        if (pres is List && pres.isNotEmpty) presupuesto = pres.first;
      }

      // 4. Perfil público del capitán
      Map<String, dynamic> capitan = {};
      if (capitanId.isNotEmpty) {
        final cap = await _supabase
            .from('profiles')
            .select('nombre, telefono, avatar_url, embarcacion_url, '
                    'servicio_carnada, servicio_lenia, servicio_almacen, '
                    'bio_pescador, capacidad_personas, capacidad_kilos, '
                    'verificado, es_capitan, localidad, provincia, '
                    'horario_rango, zona_lat, zona_lng')
            .eq('user_id', capitanId)
            .maybeSingle();
        if (cap != null) capitan = Map<String, dynamic>.from(cap);

        // Enriquecer con tabla guias
        final guia = await _supabase
            .from('guias')
            .select('*')
            .eq('id', capitanId)
            .maybeSingle();
        if (guia != null) {
          guia.forEach((k, v) {
            if (v != null && (capitan[k] == null || capitan[k] == '')) {
              capitan[k] = v;
            }
          });
          _guiaData = Map<String, dynamic>.from(guia);
        }
      }

      // 5. Pasajeros declarados (viajes_invitados)
      List<Map<String, dynamic>> pasajeros = [];
      try {
        final rows = await _supabase
            .from('viajes_invitados')
            .select('*')
            .eq('pedido_id', pedidoId);
        pasajeros = List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        // tabla puede no existir o pedido_id no aplica
      }

      // Si no hay pasajeros, agregar al titular como pasajero
      if (pasajeros.isEmpty) {
        final pescadorId = pedido['pescador_id']?.toString() ?? '';
        if (pescadorId.isNotEmpty) {
          final titular = await _supabase
              .from('profiles')
              .select('nombre, dni, telefono, avatar_url')
              .eq('user_id', pescadorId)
              .maybeSingle();
          if (titular != null) {
            pasajeros = [{'nombre_completo': titular['nombre'], 'dni': titular['dni'], 'es_titular': true}];
          }
        }
      }

      if (mounted) {
        setState(() {
          _pedido       = pedido;
          _cotizacion   = cotizacion;
          _presupuesto  = presupuesto;
          _capitan      = capitan;
          _pasajeros    = pasajeros;
          _isLoading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  bool get _pagado {
    final estado = _pedido?['estado']?.toString() ?? '';
    return ['pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'].contains(estado);
  }

  String get _estadoBadge {
    switch (_pedido?['estado']?.toString() ?? '') {
      case 'programado':      return '⏳ Programado';
      case 'confirmado':
      case 'pagado':          return '✅ Confirmado';
      case 'en_curso':        return '🚢 En Curso';
      case 'listo_para_confirmar': return '🏁 Finalizando';
      case 'cerrado':         return '🎉 Completado';
      default:                return '📋 Reservado';
    }
  }

  Color get _estadoColor {
    switch (_pedido?['estado']?.toString() ?? '') {
      case 'en_curso':        return Colors.blue;
      case 'confirmado':
      case 'pagado':          return _verde;
      case 'cerrado':         return Colors.purple;
      default:                return _naranja;
    }
  }

  String _fechaLeg(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      const dias  = ['lun','mar','mié','jue','vie','sáb','dom'];
      return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]} ${d.year}';
    } catch (_) { return iso.split('T').first; }
  }

  List<String> _serviciosPrometidos() {
    final lista = <String>[];
    if (_capitan == null) return lista;
    final carnada = _capitan!['servicio_carnada']?.toString() ?? 'No';
    if (carnada != 'No' && carnada.isNotEmpty) lista.add('🐟 Carnada: $carnada');
    if (_capitan!['servicio_lenia'] == true)   lista.add('🔥 Leña incluida');
    if (_capitan!['servicio_almacen'] == true) lista.add('🏪 Almacén a bordo');

    // bio_pescador puede tener JSON con cabania, banio, parrilla
    final bio = _capitan!['bio_pescador'];
    Map<String, dynamic>? bioMap;
    if (bio is Map) {
      bioMap = Map<String, dynamic>.from(bio);
    } else if (bio is String && bio.startsWith('{')) {
      try { bioMap = jsonDecode(bio); } catch (_) {}
    }
    if (bioMap != null) {
      if (bioMap['cabania'] == true)  lista.add('🏠 Cabaña disponible');
      if (bioMap['banio'] == true)    lista.add('🚿 Baño en el predio');
      if (bioMap['parrilla'] == true) lista.add('🥩 Parrilla incluida');
    }
    return lista;
  }

  Future<void> _llamar(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final num = tel.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$num');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _compartirTicket() {
    final cap   = _capitan?['nombre'] ?? 'el capitán';
    final fecha = _fechaLeg(_presupuesto?['fecha_hora_viaje'] ?? _cotizacion?['fecha_ida']);
    final lugar = _cotizacion?['lugar_encuentro'] ?? _cotizacion?['localidad_partida'] ?? '—';
    final hora  = _cotizacion?['hora_encuentro'] ?? '—';
    final texto = '⛵ Ticket El Guia YA\n\n'
        'Capitán: $cap\n'
        'Fecha: $fecha\n'
        'Lugar: $lugar\n'
        'Hora: $hora\n'
        'Pedido: ${widget.pedidoId.substring(0, 8).toUpperCase()}\n\n'
        'Guardá este ticket para el día del embarque.';
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Ticket copiado al portapapeles'),
        backgroundColor: _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Ticket de Embarque',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading && _pedido != null)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Compartir / Imprimir',
              onPressed: _compartirTicket,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _pedido == null
                  ? _buildVacio()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildCapitanCard(),
                            const SizedBox(height: 12),
                            _buildEmbarcacionCard(),
                            const SizedBox(height: 12),
                            _buildEncuentroCard(),
                            const SizedBox(height: 12),
                            _buildServiciosCard(),
                            const SizedBox(height: 12),
                            _buildPasajerosCard(),
                            const SizedBox(height: 12),
                            _buildContactoCard(),
                            if (_pagado) ...[
                              const SizedBox(height: 12),
                              _buildFichaContractualCard(),
                              const SizedBox(height: 12),
                              _buildPlanillaPescadorCard(),
                            ],
                            const SizedBox(height: 20),
                            _buildFooterAviso(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final idCorto = widget.pedidoId.length > 8
        ? widget.pedidoId.substring(0, 8).toUpperCase()
        : widget.pedidoId.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2847), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text('TICKET DE EMBARQUE',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 11, letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _estadoColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _estadoColor.withOpacity(0.6))),
                child: Text(_estadoBadge,
                    style: GoogleFonts.inter(
                        color: _estadoColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _cotizacion?['descripcion']?.toString() ?? 'Viaje de pesca',
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Pedido #$idCorto',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Card: Capitán ────────────────────────────────────────────────────────
  Widget _buildCapitanCard() {
    final nombre   = _capitan?['nombre']?.toString() ?? 'Capitán';
    final avatarUrl= _capitan?['avatar_url']?.toString() ?? '';
    final verificado = _capitan?['verificado'] == true || _capitan?['es_capitan_verificado'] == true;
    final localidad= _capitan?['localidad']?.toString() ?? '';
    final provincia= _capitan?['provincia']?.toString() ?? '';
    final horario  = _capitan?['horario_rango']?.toString() ?? '';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.person_rounded, label: 'Tu Capitán'),
          const SizedBox(height: 14),
          Row(
            children: [
              // Foto del capitán
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _azulBrillo, width: 2.5),
                  color: _azulBrillo.withOpacity(0.1),
                ),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(avatarUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 36, color: _azulBrillo))
                      : const Icon(Icons.person, size: 36, color: _azulBrillo),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(nombre,
                              style: GoogleFonts.inter(
                                  fontSize: 17, fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D2847))),
                        ),
                        if (verificado) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: _verde.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _verde.withOpacity(0.4))),
                            child: Text('✓ VERIFICADO',
                                style: GoogleFonts.inter(
                                    color: _verde, fontSize: 9, fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ],
                    ),
                    if (localidad.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('📍 $localidad${provincia.isNotEmpty ? ", $provincia" : ""}',
                          style: GoogleFonts.inter(color: _gris, fontSize: 12)),
                    ],
                    if (horario.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('🕐 $horario',
                          style: GoogleFonts.inter(color: _gris, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Card: Embarcación ────────────────────────────────────────────────────
  Widget _buildEmbarcacionCard() {
    final embarcacionUrl = _capitan?['embarcacion_url']?.toString() ?? '';
    final capacPers  = _capitan?['capacidad_personas'] ?? 0;
    final capacKilos = _capitan?['capacidad_kilos'] ?? 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.directions_boat_rounded, label: 'La Embarcación'),
          const SizedBox(height: 12),
          if (embarcacionUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                embarcacionUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: _azulBrillo.withOpacity(0.08),
                  child: const Center(child: Icon(Icons.directions_boat_rounded,
                      color: _azulBrillo, size: 48)),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: _azulBrillo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Icon(Icons.directions_boat_rounded,
                  color: _azulBrillo, size: 48)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoBadge(label: '👥 Hasta $capacPers personas', color: _azulBrillo),
              const SizedBox(width: 8),
              if (capacKilos > 0)
                _InfoBadge(label: '⚖️ $capacKilos kg cap.', color: _naranja),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Card: Punto de encuentro ─────────────────────────────────────────────
  Widget _buildEncuentroCard() {
    final fechaStr  = _presupuesto?['fecha_hora_viaje'] ?? _cotizacion?['fecha_ida'];
    final hora      = _cotizacion?['hora_encuentro']?.toString() ?? '—';
    final lugar     = _cotizacion?['lugar_encuentro']?.toString()
                    ?? _cotizacion?['localidad_partida']?.toString()
                    ?? '—';
    final personas  = _cotizacion?['cantidad_personas'] ?? 1;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.event_rounded, label: 'Punto de Encuentro'),
          const SizedBox(height: 14),
          _DataRow(icon: Icons.calendar_today_rounded, label: 'Fecha',
              value: _fechaLeg(fechaStr?.toString()), color: _azulBrillo),
          const SizedBox(height: 8),
          _DataRow(icon: Icons.access_time_rounded, label: 'Hora de salida',
              value: hora, color: _naranja),
          const SizedBox(height: 8),
          _DataRow(icon: Icons.location_on_rounded, label: 'Lugar',
              value: lugar, color: _rojo),
          const SizedBox(height: 8),
          _DataRow(icon: Icons.people_rounded, label: 'Pasajeros',
              value: '$personas ${personas == 1 ? "persona" : "personas"}', color: _verde),
        ],
      ),
    );
  }

  // ─── Card: Servicios prometidos ───────────────────────────────────────────
  Widget _buildServiciosCard() {
    final servicios = _serviciosPrometidos();
    if (servicios.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.checklist_rounded, label: 'Servicios Incluidos'),
          const SizedBox(height: 12),
          ...servicios.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: _verde, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(s, style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF2D3748))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Card: Pasajeros declarados ───────────────────────────────────────────
  Widget _buildPasajerosCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.group_rounded, label: 'Pasajeros Declarados'),
          const SizedBox(height: 12),
          if (_pasajeros.isEmpty)
            Text('Sin pasajeros adicionales declarados.',
                style: GoogleFonts.inter(color: _gris, fontSize: 13))
          else
            ...List.generate(_pasajeros.length, (i) {
              final p = _pasajeros[i];
              final nombre = p['nombre_completo']?.toString()
                          ?? '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}'.trim();
              final dni    = p['dni_pasajero']?.toString() ?? p['dni']?.toString() ?? '—';
              final esTitular = p['es_titular'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: esTitular ? _azulBrillo.withOpacity(0.06) : _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: esTitular ? _azulBrillo.withOpacity(0.3) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: esTitular ? _azulBrillo : _gris.withOpacity(0.3),
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text('${i + 1}',
                            style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(nombre.isNotEmpty ? nombre : 'Pasajero',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: const Color(0xFF1A202C))),
                              if (esTitular) ...[
                                const SizedBox(width: 6),
                                Text('TITULAR',
                                    style: GoogleFonts.inter(
                                        color: _azulBrillo, fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5)),
                              ],
                            ],
                          ),
                          Text('DNI: $dni',
                              style: GoogleFonts.inter(color: _gris, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Card: Contacto (desbloqueado tras el pago) ───────────────────────────
  Widget _buildContactoCard() {
    final tel = _capitan?['telefono']?.toString() ?? '';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.phone_rounded, label: 'Contacto del Capitán'),
          const SizedBox(height: 12),
          if (!_pagado)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _naranja.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _naranja.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: _naranja, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El teléfono del capitán se revela una vez confirmado el pago.',
                      style: GoogleFonts.inter(
                          color: _naranja, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else if (tel.isEmpty)
            Text('Teléfono no disponible.',
                style: GoogleFonts.inter(color: _gris, fontSize: 13))
          else
            Column(
              children: [
                // Número visible
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _verde.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _verde.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_rounded, color: _verde, size: 18),
                      const SizedBox(width: 10),
                      Text(tel,
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _llamar(tel),
                        icon: const Icon(Icons.call_rounded, size: 16),
                        label: Text('Llamar',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _azulBrillo,
                          side: BorderSide(color: _azulBrillo.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _whatsapp(tel),
                        icon: const Icon(Icons.message_rounded, size: 16),
                        label: Text('WhatsApp',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFichaContractualCard() {
    final capitanId = _pedido?['capitan_id']?.toString() ?? '';
    final nombre = _capitan?['nombre']?.toString() ?? 'Capitán';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _azulBrillo.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DOCUMENTACIÓN DEL ACUERDO',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: _azul,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Consultá la ficha contractual con carnet, seguro, servicios incluidos y acceso a la Vidriera del capitán.',
            style: GoogleFonts.inter(color: _gris, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FichaContractualScreen(pedidoId: widget.pedidoId),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Ver ficha contractual completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (capitanId.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CapitanVidrieraPublicScreen(
                      capitanId: capitanId,
                      pedidoId: widget.pedidoId,
                      nombreCapitan: nombre,
                      fechaViaje: _cotizacion?['fecha_ida']?.toString(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Vidriera del capitán'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanillaPescadorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _verde.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TU PLANILLA DE EMBARQUE',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: _azul,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Datos declarados del titular, acompañantes y contacto de contingencia. '
            'Incluye los códigos del viaje.',
            style: GoogleFonts.inter(color: _gris, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FichaPescadorScreen(pedidoId: widget.pedidoId),
                ),
              );
            },
            icon: const Icon(Icons.assignment_ind_outlined, size: 18),
            label: const Text('Ver planilla del pescador'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────
  Widget _buildFooterAviso() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text('⚓ El Guia YA',
              style: GoogleFonts.inter(
                  color: _azulBrillo, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Guardá este ticket. Presentalo al capitán el día del embarque. '
            'Ante cualquier problema, contactá a soporte desde la app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _gris, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: _rojo, size: 48),
          const SizedBox(height: 16),
          Text('No se pudo cargar el ticket',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _gris, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: _azulBrillo),
          ),
        ],
      ),
    ),
  );

  Widget _buildVacio() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.confirmation_number_outlined, color: _gris, size: 56),
        const SizedBox(height: 16),
        Text('Ticket no encontrado',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        Text('Verificá que el viaje esté confirmado.',
            style: GoogleFonts.inter(color: _gris, fontSize: 13)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES REUTILIZABLES
// ══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E88E5), size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
                color: const Color(0xFF0D2847),
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DataRow({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.inter(
                color: const Color(0xFF8BA4BC), fontSize: 12)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: const Color(0xFF1A202C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
