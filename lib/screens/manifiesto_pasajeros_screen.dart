import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/safe_button.dart';
import '../utils/fecha_nacimiento_utils.dart';
import '../widgets/descargar_despacho_pna_button.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MANIFIESTO DE EMBARQUE — Vista del CAPITÁN
// Lista oficial de pasajeros para presentar a Prefectura Naval si se requiere.
// Muestra: foto + teléfono del pescador titular para reconocerlo,
// nombre + apellido + DNI de cada pasajero y sus fotos de DNI.
// ══════════════════════════════════════════════════════════════════════════════

class ManifiestoPasajerosScreen extends StatefulWidget {
  final String pedidoId;

  const ManifiestoPasajerosScreen({super.key, required this.pedidoId});

  @override
  State<ManifiestoPasajerosScreen> createState() => _ManifiestoPasajerosScreenState();
}

class _ManifiestoPasajerosScreenState extends State<ManifiestoPasajerosScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _pedido;
  Map<String, dynamic>? _cotizacion;
  Map<String, dynamic>? _titular;       // perfil del pescador principal
  List<Map<String, dynamic>> _pasajeros = [];  // invitados adicionales

  // Paleta oscura para uso exterior (alta legibilidad bajo el sol)
  static const _bg       = Color(0xFF0D2847);
  static const _surface  = Color(0xFF1A3A5C);
  static const _card     = Color(0xFF163258);
  static const _verde    = Color(0xFF00C853);
  static const _naranja  = Color(0xFFF59E0B);
  static const _rojo     = Color(0xFFEF4444);
  static const _blanco   = Colors.white;
  static const _gris     = Color(0xFF8BA4BC);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // 1. Pedido
      final pedido = await _supabase
          .from('pedidos')
          .select('*')
          .eq('id', widget.pedidoId)
          .single();

      final pescadorId   = pedido['pescador_id']?.toString() ?? '';
      final cotizacionId = pedido['cotizacion_id']?.toString() ?? '';

      // 2. Cotización
      Map<String, dynamic>? cot;
      if (cotizacionId.isNotEmpty) {
        cot = await _supabase
            .from('cotizaciones')
            .select('descripcion, hora_encuentro, lugar_encuentro, '
                    'localidad_partida, fecha_ida, cantidad_personas')
            .eq('id', cotizacionId)
            .maybeSingle();
      }

      // 3. Perfil del pescador TITULAR (foto de cara + teléfono)
      Map<String, dynamic> titular = {};
      if (pescadorId.isNotEmpty) {
        final t = await _supabase
            .from('profiles')
            .select('nombre, dni, telefono, avatar_url, email, localidad, provincia')
            .eq('user_id', pescadorId)
            .maybeSingle();
        if (t != null) titular = Map<String, dynamic>.from(t);
      }

      // 4. Pasajeros/invitados del pedido
      List<Map<String, dynamic>> pasajeros = [];
      try {
        final rows = await _supabase
            .from('viajes_invitados')
            .select('*')
            .eq('pedido_id', widget.pedidoId);
        pasajeros = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _pedido    = pedido;
          _cotizacion = cot;
          _titular   = titular;
          _pasajeros = pasajeros;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _fechaLeg(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      const dias  = ['lun','mar','mié','jue','vie','sáb','dom'];
      return '${dias[d.weekday-1]} ${d.day} ${meses[d.month-1]} ${d.year}';
    } catch (_) { return iso.split('T').first; }
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

  void _copiarManifiesto() {
    final titular  = _titular?['nombre'] ?? '—';
    final dni      = _titular?['dni'] ?? '—';
    final tel      = _titular?['telefono'] ?? '—';
    final fecha    = _fechaLeg(_cotizacion?['fecha_ida']);
    final lugar    = _cotizacion?['lugar_encuentro'] ?? _cotizacion?['localidad_partida'] ?? '—';
    final hora     = _cotizacion?['hora_encuentro'] ?? '—';
    final idCorto  = widget.pedidoId.length > 8
        ? widget.pedidoId.substring(0, 8).toUpperCase() : widget.pedidoId.toUpperCase();

    final sb = StringBuffer();
    sb.writeln('🚢 MANIFIESTO DE EMBARQUE — El Guia YA');
    sb.writeln('Pedido: $idCorto');
    sb.writeln('Fecha: $fecha | Hora: $hora');
    sb.writeln('Lugar: $lugar');
    sb.writeln('');
    sb.writeln('TITULAR');
    sb.writeln('Nombre: $titular');
    sb.writeln('DNI: $dni');
    sb.writeln('Tel: $tel');
    if (_pasajeros.isNotEmpty) {
      sb.writeln('');
      sb.writeln('PASAJEROS ADICIONALES');
      for (int i = 0; i < _pasajeros.length; i++) {
        final p = _pasajeros[i];
        final n = '${p['nombre_pasajero'] ?? p['nombre'] ?? ''} ${p['apellido_pasajero'] ?? p['apellido'] ?? ''}'.trim();
        final d = p['dni_pasajero']?.toString() ?? p['dni']?.toString() ?? '—';
        final t = p['telefono']?.toString() ?? '—';
        sb.writeln('${i+1}. $n — DNI: $d — Tel: $t');
      }
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Manifiesto copiado al portapapeles'),
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
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Manifiesto de Embarque',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _blanco)),
        backgroundColor: _surface,
        foregroundColor: _blanco,
        elevation: 0,
        actions: [
          if (!_isLoading && _pedido != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copiar para compartir',
              onPressed: _copiarManifiesto,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _verde))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  color: _verde,
                  backgroundColor: _surface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildTitularCard(),
                        const SizedBox(height: 12),
                        _buildPasajerosSection(),
                        const SizedBox(height: 12),
                        DescargarDespachoPnaButton(pedidoId: widget.pedidoId),
                        const SizedBox(height: 12),
                        _buildPrefecturaAviso(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final fecha    = _fechaLeg(_cotizacion?['fecha_ida']);
    final hora     = _cotizacion?['hora_encuentro']?.toString() ?? '—';
    final lugar    = _cotizacion?['lugar_encuentro']?.toString()
                   ?? _cotizacion?['localidad_partida']?.toString() ?? '—';
    final personas = _cotizacion?['cantidad_personas'] ?? 1;
    final idCorto  = widget.pedidoId.length > 8
        ? widget.pedidoId.substring(0, 8).toUpperCase() : widget.pedidoId.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_rounded, color: _gris, size: 16),
              const SizedBox(width: 8),
              Text('MANIFIESTO OFICIAL', style: GoogleFonts.inter(
                  color: _gris, fontSize: 10, letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('# $idCorto', style: GoogleFonts.inter(
                  color: _gris, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_cotizacion?['descripcion']?.toString() ?? 'Viaje confirmado',
              style: GoogleFonts.inter(
                  color: _blanco, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _ManifiestoRow(icon: Icons.calendar_today_rounded,
              label: '$fecha — $hora', color: _naranja),
          const SizedBox(height: 6),
          _ManifiestoRow(icon: Icons.location_on_rounded,
              label: lugar, color: _rojo),
          const SizedBox(height: 6),
          _ManifiestoRow(icon: Icons.people_rounded,
              label: '$personas ${personas == 1 ? "persona a bordo" : "personas a bordo"}',
              color: _verde),
        ],
      ),
    );
  }

  // ─── Card titular ─────────────────────────────────────────────────────────
  Widget _buildTitularCard() {
    final nombre    = _titular?['nombre']?.toString() ?? 'Pescador';
    final dni       = _titular?['dni']?.toString() ?? '—';
    final titularInvitado = _pasajeros.cast<Map<String, dynamic>>().where(
      (p) => p['es_titular'] == true,
    ).firstOrNull ?? (_pasajeros.isNotEmpty ? _pasajeros.first : null);
    final fechaNac = FechaNacimientoUtils.formatearLegible(
      titularInvitado?['fecha_nacimiento'],
    );
    final tel       = _titular?['telefono']?.toString() ?? '';
    final avatarUrl = _titular?['avatar_url']?.toString() ?? '';
    final localidad = _titular?['localidad']?.toString() ?? '';
    final provincia = _titular?['provincia']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _verde.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header titular
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _verde.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: _verde.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: _verde, size: 16),
                const SizedBox(width: 8),
                Text('TITULAR — Reconocelo al llegar',
                    style: GoogleFonts.inter(
                        color: _verde, fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Foto de cara del titular
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _verde, width: 2.5),
                    color: _verde.withOpacity(0.1),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? Image.network(avatarUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person, size: 40, color: _verde))
                        : const Icon(Icons.person, size: 40, color: _verde),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: GoogleFonts.inter(
                              color: _blanco, fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded, color: _gris, size: 14),
                          const SizedBox(width: 4),
                          Text('DNI: $dni',
                              style: GoogleFonts.inter(
                                  color: _blanco, fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Nac.: $fechaNac',
                          style: GoogleFonts.inter(
                              color: _gris, fontSize: 12)),
                      if (localidad.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('📍 $localidad${provincia.isNotEmpty ? ", $provincia" : ""}',
                            style: GoogleFonts.inter(color: _gris, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Botones de contacto
          if (tel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SafeOutlinedIconButton(
  onPressed: () => _llamar(tel),
  icon: Icons.call_rounded,
  iconSize: 15,
  label: tel,
  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600,
                              fontSize: 12),
  style: OutlinedButton.styleFrom(
                        foregroundColor: _blanco,
                        side: BorderSide(color: _blanco.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _whatsapp(tel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.message_rounded, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Sección pasajeros adicionales ───────────────────────────────────────
  Widget _buildPasajerosSection() {
    final totalPasajeros = _pasajeros.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.group_rounded, color: _gris, size: 16),
              const SizedBox(width: 8),
              Text('PASAJEROS ADICIONALES',
                  style: GoogleFonts.inter(
                      color: _gris, fontSize: 11, letterSpacing: 1.2,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (totalPasajeros > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _naranja.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$totalPasajeros',
                      style: GoogleFonts.inter(
                          color: _naranja, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        if (_pasajeros.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _gris, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El titular viaja sin acompañantes adicionales declarados.',
                    style: GoogleFonts.inter(color: _gris, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_pasajeros.length, (i) {
            final p = _pasajeros[i];
            final nombre    = '${p['nombre_pasajero'] ?? p['nombre'] ?? ''} '
                              '${p['apellido_pasajero'] ?? p['apellido'] ?? ''}'.trim();
            final dni       = p['dni_pasajero']?.toString() ?? p['dni']?.toString() ?? '—';
            final fechaNac  = FechaNacimientoUtils.formatearLegible(p['fecha_nacimiento']);
            final tel       = p['telefono']?.toString() ?? '';
            final fotoDniUrl= p['foto_dni_url']?.toString() ?? '';
            final validado  = p['datos_validados'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: validado
                        ? _verde.withOpacity(0.25)
                        : Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Número de pasajero
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: _naranja.withOpacity(0.2), shape: BoxShape.circle),
                        child: Center(
                          child: Text('${i + 2}',  // +2 porque 1 es el titular
                              style: GoogleFonts.inter(
                                  color: _naranja, fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre.isNotEmpty ? nombre : 'Pasajero ${i + 2}',
                                style: GoogleFonts.inter(
                                    color: _blanco, fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            Row(
                              children: [
                                Text('DNI: ',
                                    style: GoogleFonts.inter(
                                        color: _gris, fontSize: 12)),
                                Text(dni,
                                    style: GoogleFonts.inter(
                                        color: _blanco,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 1.0)),
                              ],
                            ),
                            Text('Nac.: $fechaNac',
                                style: GoogleFonts.inter(
                                    color: _gris, fontSize: 11)),
                          ],
                        ),
                      ),
                      // Badge validado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: validado
                              ? _verde.withOpacity(0.12)
                              : _naranja.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(validado ? '✓ Validado' : '⏳ Pendiente',
                            style: GoogleFonts.inter(
                                color: validado ? _verde : _naranja,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  // Foto del DNI si existe
                  if (fotoDniUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, color: _gris, size: 14),
                        const SizedBox(width: 6),
                        Text('Foto DNI:', style: GoogleFonts.inter(color: _gris, fontSize: 11)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _verFotoDni(context, fotoDniUrl, nombre),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _azulBrillo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Ver foto',
                                style: GoogleFonts.inter(
                                    color: const Color(0xFF1E88E5),
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Teléfono del pasajero
                  if (tel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, color: _gris, size: 14),
                        const SizedBox(width: 6),
                        Text(tel,
                            style: GoogleFonts.inter(
                                color: _blanco, fontSize: 12)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _whatsapp(tel),
                          child: const Icon(Icons.message_rounded,
                              color: Color(0xFF25D366), size: 18),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  void _verFotoDni(BuildContext ctx, String url, String nombre) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('DNI — $nombre',
                  style: GoogleFonts.inter(fontSize: 14)),
              centerTitle: true,
            ),
            Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                )),
          ],
        ),
      ),
    );
  }

  // ─── Aviso Prefectura ─────────────────────────────────────────────────────
  Widget _buildPrefecturaAviso() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _naranja.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranja.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: _naranja, size: 16),
              const SizedBox(width: 8),
              Text('DECLARACIÓN PREFECTURA NAVAL',
                  style: GoogleFonts.inter(
                      color: _naranja, fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Este manifiesto contiene los datos de todos los pasajeros '
            'declarados para este viaje. Podés copiarlo y presentarlo '
            'ante las autoridades navales si es requerido. '
            'Los datos de DNI son responsabilidad del pescador titular.',
            style: GoogleFonts.inter(
                color: _naranja.withOpacity(0.85), fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SafeOutlinedIconButton(
  onPressed: _copiarManifiesto,
  icon: Icons.copy_rounded,
  iconSize: 15,
  label: 'Copiar manifiesto completo',
  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
  style: OutlinedButton.styleFrom(
                foregroundColor: _naranja,
                side: BorderSide(color: _naranja.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
),
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
          Text('No se pudo cargar el manifiesto',
              style: GoogleFonts.inter(
                  color: _blanco, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _gris, fontSize: 12)),
          const SizedBox(height: 20),
          SafeElevatedIconButton(
  onPressed: _cargar,
  icon: Icons.refresh_rounded,
  label: 'Reintentar',
  style: ElevatedButton.styleFrom(backgroundColor: _verde),
),
        ],
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────────────────────────────────────
const _azulBrillo = Color(0xFF1E88E5);

class _ManifiestoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ManifiestoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }
}
