import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/safe_button.dart';
import 'admin_libro_transferencias_screen.dart';

class AdminLiquidacionScreen extends StatefulWidget {
  const AdminLiquidacionScreen({super.key});

  @override
  State<AdminLiquidacionScreen> createState() => _AdminLiquidacionScreenState();
}

class _AdminLiquidacionScreenState extends State<AdminLiquidacionScreen> {
  static const int _pageSize = 50;

  List<Map<String, dynamic>> _liquidaciones = [];
  List<Map<String, dynamic>> _comisionesLogs = [];
  bool _mostrarComisiones = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isAdmin = false;
  bool _hasMorePending = false;
  bool _loadingMorePending = false;
  int _pendingOffset = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollPendientes);
    _checkSecurity();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _mensajeErrorLiquidacion(Object e) {
    final msg = e.toString();
    if (msg.contains('StorageException') ||
        msg.contains('403') ||
        msg.contains('Unauthorized')) {
      return 'No se pudo guardar el ticket en Storage. Verificá que la migración '
          'libro_transferencias esté aplicada y que entraste como admin.';
    }
    if (msg.contains('completar_retiro_billetera') ||
        msg.contains('PGRST202') ||
        msg.contains('Could not find the function')) {
      return 'Falta actualizar Supabase: ejecutá la migración libro_transferencias '
          '(RPC completar_retiro_billetera con ticket).';
    }
    if (msg.contains('ambiguous') || msg.contains('42702')) {
      return 'Error SQL en Supabase (columna ambigua). Aplicá la migración '
          '20260630180000_fix_completar_retiro_output_columns.sql y reintentá.';
    }
    return 'Error al liquidar fondos: $e';
  }

  bool _esImagenTicket(String? nombre) {
    if (nombre == null) return false;
    final lower = nombre.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  Future<void> _mostrarDialogoConfirmarRetiro(Map<String, dynamic> liquidacion) async {
    final String liqId = liquidacion['id']?.toString() ?? '';
    final String capId =
        (liquidacion['capitan_id'] ?? liquidacion['usuario_id'])?.toString() ?? '';
    final String nombre = liquidacion['nombre']?.toString() ?? 'Capitán';
    final String cbu = liquidacion['cbu']?.toString() ?? '';
    final double monto = (liquidacion['monto'] as num?)?.toDouble() ?? 0.0;

    final comprobanteController = TextEditingController();
    bool confirmoMp = false;
    XFile? ticketFile;
    Uint8List? ticketPreview;
    String? ticketNombre;

    Future<void> adjuntarArchivoLocal(StateSetter setDialogState) async {
      try {
        final picked = await StorageService.pickComprobanteArchivoLocal();
        if (picked == null) return;
        Uint8List? bytes;
        if (_esImagenTicket(picked.name)) {
          bytes = await picked.readAsBytes();
        }
        setDialogState(() {
          ticketFile = picked;
          ticketPreview = bytes;
          ticketNombre = picked.name;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el archivo: $e')),
        );
      }
    }

    Future<void> adjuntarDesdeGaleria(StateSetter setDialogState) async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setDialogState(() {
        ticketFile = picked;
        ticketPreview = bytes;
        ticketNombre = picked.name;
      });
    }

    bool puedeConfirmar() =>
        confirmoMp &&
        comprobanteController.text.trim().isNotEmpty &&
        ticketFile != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF001A33).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.payment_rounded, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CONFIRMAR TRANSFERENCIA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro solo admin. El capitán $nombre recibirá la transferencia; '
                    'vos guardás Nº MP + ticket como prueba.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Capitán: $nombre',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('CBU / CVU destino:\n$cbu',
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35)),
                        const SizedBox(height: 8),
                        Text(
                          'Monto: \$${monto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: comprobanteController,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Nº comprobante Mercado Pago *',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => adjuntarArchivoLocal(setDialogState),
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: const Text('Buscar archivo en el dispositivo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: BorderSide(color: Colors.cyanAccent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => adjuntarDesdeGaleria(setDialogState),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Galería', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (ticketFile != null) ...[
                    if (ticketPreview != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          ticketPreview!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ticketNombre ?? 'Archivo adjunto',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      'Ticket listo para guardar en el libro de transferencias',
                      style: TextStyle(color: Color(0xFF00E676), fontSize: 11),
                    ),
                  ] else
                    Text(
                      'Adjuntá imagen o PDF del comprobante MP *',
                      style: TextStyle(
                        color: Colors.orangeAccent.withOpacity(0.95),
                        fontSize: 11,
                      ),
                    ),
                  CheckboxListTile(
                    value: confirmoMp,
                    onChanged: (v) => setDialogState(() => confirmoMp = v ?? false),
                    activeColor: Colors.cyanAccent,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Confirmo transferencia manual desde Mercado Pago',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR',
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: puedeConfirmar()
                    ? () {
                        Navigator.pop(context);
                        _procesarPagoBackend(
                          liqId,
                          capId,
                          monto,
                          cbu,
                          comprobante: comprobanteController.text.trim(),
                          ticketFile: ticketFile!,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black87,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CONFIRMAR Y REGISTRAR',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );

    comprobanteController.dispose();
  }

  Widget _buildBannerAuditoria() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auditoría de transferencias (solo administrador)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El capitán solo recibe la transferencia. Vos registrás Nº de comprobante y ticket '
            'antes de confirmar. Si hay un reclamo, consultá el historial en el Libro de transferencias.',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminLibroTransferenciasScreen(),
              ),
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Abrir Libro de transferencias'),
            style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
          ),
        ],
      ),
    );
  }

  void _onScrollPendientes() {
    if (_mostrarComisiones || _loadingMorePending || !_hasMorePending) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cargarMasPendientes();
    }
  }

  /// 🛡️ Validar seguridad del Rol Admin
  void _checkSecurity() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final String? email = user.email;
      final String? role = user.userMetadata?['rol']?.toString() ?? user.userMetadata?['role']?.toString();
      
      if (email == 'admin@capitanya.com' || role == 'admin') {
        setState(() {
          _isAdmin = true;
        });
        _cargarLiquidaciones();
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  /// 📥 Cargar datos (liquidaciones pendientes o logs de comisiones)
  Future<void> _cargarLiquidaciones() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _pendingOffset = 0;
    });
    try {
      if (_mostrarComisiones) {
        final logs = await SupabaseService.fetchLogsComisionesAdmin();
        if (mounted) {
          setState(() {
            _comisionesLogs = logs;
            _isLoading = false;
          });
        }
      } else {
        final result = await SupabaseService.fetchPendingLiquidacionesAdmin(
          limit: _pageSize,
          offset: 0,
        );
        if (mounted) {
          setState(() {
            _liquidaciones = result.items;
            _hasMorePending = result.hasMore;
            _pendingOffset = result.items.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _cargarMasPendientes() async {
    if (_loadingMorePending || !_hasMorePending || _mostrarComisiones) return;
    setState(() => _loadingMorePending = true);
    try {
      final result = await SupabaseService.fetchPendingLiquidacionesAdmin(
        limit: _pageSize,
        offset: _pendingOffset,
      );
      if (mounted) {
        setState(() {
          _liquidaciones.addAll(result.items);
          _hasMorePending = result.hasMore;
          _pendingOffset += result.items.length;
          _loadingMorePending = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMorePending = false);
    }
  }

  void _onConfirmarRetiro(Map<String, dynamic> liquidacion) {
    _mostrarDialogoConfirmarRetiro(liquidacion);
  }

  Future<void> _rechazarRetiro(Map<String, dynamic> liquidacion) async {
    final liqId = liquidacion['id']?.toString() ?? '';
    final motivoController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001A33),
        title: const Text('Rechazar retiro', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: motivoController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar y devolver saldo', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmar != true || liqId.isEmpty) return;
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await SupabaseService.rechazarLiquidacionAdmin(
        liquidacionId: liqId,
        motivo: motivoController.text.trim().isEmpty ? null : motivoController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retiro rechazado. Saldo devuelto al capitán.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _cargarLiquidaciones();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// ⚙️ Procesar pago en Supabase de forma segura con prevención de clics dobles
  Future<void> _procesarPagoBackend(
    String liquidacionId,
    String usuarioId,
    double monto,
    String cbu, {
    required String comprobante,
    required XFile ticketFile,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final storagePath = await StorageService.uploadLiquidacionComprobante(
        file: ticketFile,
        liquidacionId: liquidacionId,
      );

      await SupabaseService.procesarLiquidacionAdmin(
        liquidacionId: liquidacionId,
        usuarioId: usuarioId,
        monto: monto,
        cbuDestino: cbu,
        comprobante: comprobante,
        comprobanteStoragePath: storagePath,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Transferencia liquidada y notificada con éxito!',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00E676),
            duration: const Duration(seconds: 4),
          ),
        );
        _cargarLiquidaciones();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mensajeErrorLiquidacion(e)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  /// 📋 Copiar CBU al portapapeles
  void _copiarCbu(String cbu) {
    Clipboard.setData(ClipboardData(text: cbu));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡CBU/CVU copiado al portapapeles! 📋'),
        backgroundColor: Colors.cyan,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ Filtro de seguridad para acceso de Administrador
    if (!_isAdmin && !_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF000A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
            tooltip: 'Volver al menú',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.security, color: Colors.redAccent, size: 80),
              SizedBox(height: 16),
              Text(
                'ACCESO DENEGADO',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              SizedBox(height: 8),
              Text(
                'Solo los administradores con privilegios pueden acceder a este panel.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Permite ver el fondo con orbes de luz del Dashboard
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del panel
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Volver al menú',
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.cyanAccent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Módulo de Liquidaciones',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pendientes de aprobación y envío de fondos',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.menu_book_rounded, color: Colors.cyanAccent),
                      tooltip: 'Libro de transferencias',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLibroTransferenciasScreen(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                      onPressed: _cargarLiquidaciones,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎛️ Selector de Vista (Liquidaciones vs Comisiones)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarComisiones = false;
                            });
                            _cargarLiquidaciones();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_mostrarComisiones
                                  ? Colors.cyan.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: !_mostrarComisiones
                                  ? Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.0)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'RETIROS CAPITANES',
                                style: TextStyle(
                                  color: !_mostrarComisiones ? Colors.cyanAccent : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarComisiones = true;
                            });
                            _cargarLiquidaciones();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _mostrarComisiones
                                  ? Colors.cyan.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _mostrarComisiones
                                  ? Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.0)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'HISTORIAL COMISIONES',
                                style: TextStyle(
                                  color: _mostrarComisiones ? Colors.cyanAccent : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista Principal
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : _mostrarComisiones
                          ? _buildComisionesTab()
                              : _liquidaciones.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    _buildBannerAuditoria(),
                                    const SizedBox(height: 40),
                                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white24, size: 70),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '¡Todo al día!',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'No hay retiros pendientes. Cuando un capitán solicite uno, '
                                        'cargá acá el Nº MP y el ticket antes de confirmar. '
                                        'El historial queda en el Libro de transferencias.',
                                        style: TextStyle(color: Colors.white54, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                )
                              : RefreshIndicator(
                                  color: Colors.cyanAccent,
                                  onRefresh: _cargarLiquidaciones,
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: _liquidaciones.length +
                                        1 +
                                        (_loadingMorePending ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return _buildBannerAuditoria();
                                      }
                                      final dataIndex = index - 1;
                                      if (dataIndex >= _liquidaciones.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.cyanAccent,
                                            ),
                                          ),
                                        );
                                      }
                                      final liq = _liquidaciones[dataIndex];
                                      final nombre = liq['nombre'] ?? 'Usuario';
                                      final avatarUrl = liq['avatar_url'];
                                      final rol = liq['rol'] ?? 'Capitán';
                                      final double monto = (liq['monto'] as num?)?.toDouble() ?? 0.0;
                                      final cbu = liq['cbu'] ?? '';
                                      final saldoRetenido = (liq['saldo_retenido'] as num?)?.toDouble() ?? 0.0;
                                      final bool saldoValido = liq['saldo_valido'] == true;
                                      final int grupoCount =
                                          (liq['pendientes_grupo_count'] as num?)?.toInt() ?? 1;
                                      final int grupoIndice =
                                          (liq['pendientes_grupo_indice'] as num?)?.toInt() ?? 1;
                                      final double grupoTotal =
                                          (liq['pendientes_grupo_total'] as num?)?.toDouble() ??
                                              monto;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF001A33).withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: saldoValido ? Colors.cyan.withOpacity(0.2) : Colors.redAccent.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                            child: Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.cyan.withOpacity(0.02),
                                                    Colors.transparent,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Fila Superior (Perfil y Rol)
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor: Colors.cyan.withOpacity(0.2),
                                                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                                        child: avatarUrl == null
                                                            ? const Icon(Icons.person, color: Colors.cyanAccent)
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              nombre,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                                fontFamily: 'Outfit',
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                // Rol Badge
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: (rol == 'Capitán' ? Colors.orange : Colors.purple).withOpacity(0.15),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(
                                                                      color: (rol == 'Capitán' ? Colors.orangeAccent : Colors.purpleAccent).withOpacity(0.4),
                                                                      width: 0.5,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    rol.toUpperCase(),
                                                                    style: TextStyle(
                                                                      color: rol == 'Capitán' ? Colors.orangeAccent : Colors.purpleAccent,
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                // Validación de Saldo Disponible
                                                                Text(
                                                                  'Retenido total: \$${saldoRetenido.toStringAsFixed(2)}',
                                                                  style: TextStyle(
                                                                    color: saldoValido ? Colors.white54 : Colors.redAccent,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            if (grupoCount > 1) ...[
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                'Solicitud $grupoIndice de $grupoCount · '
                                                                'pendiente acumulado \$${grupoTotal.toStringAsFixed(2)}',
                                                                style: const TextStyle(
                                                                  color: Colors.amberAccent,
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 18),

                                                  // Monto Solicitado en estilo HeadlineMedium
                                                  Text(
                                                    '\$${monto.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),

                                                  // Campo CBU/CVU con Botón Copiar
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.04),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.white10),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.account_balance_outlined, color: Colors.cyanAccent, size: 18),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            cbu.isNotEmpty ? cbu : 'CBU no cargado por el usuario',
                                                            style: const TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (cbu.isNotEmpty)
                                                          GestureDetector(
                                                            onTap: () => _copiarCbu(cbu),
                                                            child: Container(
                                                              padding: const EdgeInsets.all(6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.cyan.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 16),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),

                                                  // Validación de saldo alerta
                                                  if (!saldoValido) ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 12),
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        children: const [
                                                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Saldo retenido insuficiente para este retiro.',
                                                              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],

                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Al confirmar se abre el registro con CBU, Nº MP y ticket.',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.45),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),

                                                  // Botón Confirmar Transferencia Realizada
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: SafeElevatedIconButton(
  onPressed: (saldoValido && !_isProcessing)
      ? () => _onConfirmarRetiro(liq)
      : null,
  icon: Icons.check_circle_outline_rounded,
  iconSize: 18,
  label: 'CONFIRMAR TRANSFERENCIA REALIZADA',
  style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF00E676),
                                                        foregroundColor: Colors.black87,
                                                        disabledBackgroundColor: Colors.white12,
                                                        textStyle: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        elevation: 6,
                                                      ),
),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: OutlinedButton.icon(
                                                      onPressed: () => _rechazarRetiro(liq),
                                                      icon: const Icon(Icons.cancel_outlined, size: 16),
                                                      label: const Text('RECHAZAR Y DEVOLVER SALDO'),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: Colors.redAccent,
                                                        side: const BorderSide(color: Colors.redAccent),
                                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
          
          // Indicador de Carga Global para evitar clics dobles en transacciones
          if (_isProcessing)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        'Procesando transferencia y registrando historial...',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 📊 Tab de Historial de Comisiones
  Widget _buildComisionesTab() {
    if (_comisionesLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 70),
            SizedBox(height: 16),
            Text(
              'Sin comisiones registradas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Las comisiones procesadas aparecerán aquí.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _comisionesLogs.length,
      itemBuilder: (context, index) {
        final log = _comisionesLogs[index];
        final String escenario = log['escenario'] ?? 'SIN_REFERENCIA';
        final double montoViaje = (log['monto_viaje'] as num?)?.toDouble() ?? 0.0;
        final double comisionApp = (log['comision_app'] as num?)?.toDouble() ?? 0.0;
        final double pagoVendedor = (log['pago_vendedor'] as num?)?.toDouble() ?? 0.0;
        final double netaApp = (log['neta_app'] as num?)?.toDouble() ?? 0.0;
        final String? vendedorId = log['vendedor_id']?.toString();
        final comisionista = log['comisionistas'] is Map
            ? Map<String, dynamic>.from(log['comisionistas'] as Map)
            : null;
        final String promotorLabel = comisionista?['codigo_comision']?.toString() ??
            (vendedorId != null ? vendedorId.substring(0, 8) : '');
        final String fecha = log['created_at'] != null 
            ? DateTime.tryParse(log['created_at'].toString())?.toLocal().toString().substring(0, 16) ?? ''
            : '';

        // Badge styling
        Color badgeColor;
        String badgeText;
        switch (escenario) {
          case 'MATCH':
            badgeColor = const Color(0xFF00E676);
            badgeText = 'MATCH PERFECTO (100%)';
            break;
          case 'CAPITAN':
            badgeColor = Colors.cyanAccent;
            badgeText = 'REC. CAPITÁN (70%)';
            break;
          case 'PESCADOR':
            badgeColor = Colors.indigoAccent;
            badgeText = 'REC. PESCADOR (20%)';
            break;
          case 'EXPIRADO_O_REPETIDO':
            badgeColor = Colors.orangeAccent;
            badgeText = 'VENCIDO / REPETIDO';
            break;
          default:
            badgeColor = Colors.white38;
            badgeText = 'SIN REFERENCIA';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF001A33).withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: badgeColor.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: Escenario y Fecha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.5),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          fecha,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Vendedor info (Clickable to view detail)
                    if (vendedorId != null) ...[
                      InkWell(
                        onTap: () => _mostrarPerfilComisionista(vendedorId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Promotor: $promotorLabel',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tabla de comisiones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMontoCol('Total Viaje', montoViaje, Colors.white),
                        _buildMontoCol('Comisión App (10%)', comisionApp, Colors.cyanAccent),
                        _buildMontoCol('Pago Vendedor', pagoVendedor, const Color(0xFF00E676)),
                        _buildMontoCol('Ganancia Neta App', netaApp, Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMontoCol(String titulo, double valor, Color valorColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${valor.toStringAsFixed(2)}',
          style: TextStyle(
            color: valorColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  /// 🌟 Mostrar ficha de comisionista/promotor de forma glassmórfica premium
  Future<void> _mostrarPerfilComisionista(String? selector) async {
    if (selector == null || selector.trim().isEmpty) return;

    // Mostrar diálogo de carga glassmórfico
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      ),
    );

    Map<String, dynamic>? promotor;
    try {
      // Intentar buscar por código de promotor
      promotor = await SupabaseService.validarCodigoPromotor(selector);

      // Si no se encuentra directamente, buscar en todos los comisionistas
      if (promotor == null) {
        final list = await SupabaseService.getComisionistas();
        final match = list.firstWhere(
          (c) => c['id']?.toString() == selector || c['codigo_comision']?.toString().toUpperCase() == selector.toUpperCase(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          promotor = match;
        }
      }
    } catch (e) {
      print('Error al buscar perfil de comisionista: $e');
    }

    // Cerrar diálogo de carga
    if (mounted) Navigator.pop(context);

    if (promotor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron los datos de perfil para este promotor.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final String nombre = promotor['nombre'] ?? 'Sin Nombre';
    final String dni = promotor['dni'] ?? 'Sin DNI';
    final String cuentaMp = promotor['cuenta_mp'] ?? 'Sin Cuenta';
    final String codigo = promotor['codigo_comision'] ?? 'Sin Código';
    final String estado = promotor['estado'] ?? 'activo';
    final bool esActivo = estado.toLowerCase() == 'activo';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.badge_rounded, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                'PERFIL PROMOTOR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFichaRow('Nombre y Apellido:', nombre),
              _buildFichaRow('DNI:', dni),
              _buildFichaRow('Cuenta Mercado Pago:', cuentaMp),
              _buildFichaRow('Código Único:', codigo),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Estado: ',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: esActivo ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: esActivo ? Colors.greenAccent : Colors.orangeAccent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        color: esActivo ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CERRAR',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFichaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
