import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminLogsScreen extends StatefulWidget {
  final bool embedMode;
  const AdminLogsScreen({super.key, this.embedMode = false});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _systemLogs = [];
  List<Map<String, dynamic>> _commissionLogs = [];
  List<Map<String, dynamic>> _adminLogs = [];
  List<Map<String, dynamic>> _downloadLogs = [];
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarTodosLosLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodosLosLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    dynamic sysLogsRes = [];
    dynamic commLogsRes = [];
    dynamic adminLogsRes = [];
    dynamic downloadLogsRes = [];
    
    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch logs_sistema
      try {
        sysLogsRes = await supabase
            .from('logs_sistema')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Error al cargar logs_sistema: $e');
      }
      
      // 2. Fetch logs_comisiones
      try {
        commLogsRes = await SupabaseService.fetchLogsComisionesAdmin();
      } catch (e) {
        debugPrint('Error al cargar logs_comisiones: $e');
      }

      // 3. Fetch admin_logs
      try {
        adminLogsRes = await supabase
            .from('admin_logs')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Error al cargar admin_logs: $e');
      }

      // 4. Fetch descargas_app
      try {
        downloadLogsRes = await supabase
            .from('descargas_app')
            .select('*')
            .order('creado_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Error al cargar descargas_app: $e');
      }

      if (mounted) {
        setState(() {
          _systemLogs = List<Map<String, dynamic>>.from(sysLogsRes);
          _commissionLogs = List<Map<String, dynamic>>.from(commLogsRes);
          _adminLogs = List<Map<String, dynamic>>.from(adminLogsRes);
          _downloadLogs = List<Map<String, dynamic>>.from(downloadLogsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error general en _cargarTodosLosLogs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error al cargar logs: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatFecha(dynamic rawDate) {
    if (rawDate == null) return 'N/D';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (_) {
      return rawDate.toString();
    }
  }

  void _verDetallesLog(Map<String, dynamic> log, String title) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001F3F).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: log.entries.map((entry) {
                  final key = entry.key;
                  final value = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value is Map || value is List
                              ? const JsonEncoder.withIndent('  ').convert(value)
                              : value?.toString() ?? 'N/D',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(color: Colors.white10),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CERRAR',
                style: GoogleFonts.outfit(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filters search query
  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> lista, List<String> campos) {
    if (_searchQuery.isEmpty) return lista;
    return lista.where((item) {
      return campos.any((campo) {
        final val = item[campo];
        if (val == null) return false;
        return val.toString().toLowerCase().contains(_searchQuery.toLowerCase());
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
        : Column(
            children: [
              // Buscador Glassmorphic
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Filtrar logs en tiempo real...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      icon: const Icon(Icons.search, color: Colors.cyanAccent),
                    ),
                  ),
                ),
              ),

              // TabBar secundario
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.cyanAccent,
                labelColor: Colors.cyanAccent,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Sistema', icon: Icon(Icons.dns_rounded)),
                  Tab(text: 'Comisiones', icon: Icon(Icons.monetization_on_rounded)),
                  Tab(text: 'Actividad Admin', icon: Icon(Icons.admin_panel_settings_rounded)),
                  Tab(text: 'Descargas App', icon: Icon(Icons.download_rounded)),
                ],
              ),

              const SizedBox(height: 8),

              // TabBarView content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSystemLogsTab(),
                    _buildCommissionLogsTab(),
                    _buildAdminLogsTab(),
                    _buildDownloadLogsTab(),
                  ],
                ),
              ),
            ],
          );

    if (widget.embedMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: Text(
          'Bitácora de Logs',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarTodosLosLogs,
          )
        ],
      ),
      body: body,
    );
  }

  Widget _buildSystemLogsTab() {
    final filtered = _filtrar(_systemLogs, ['tipo', 'descripcion']);
    if (filtered.isEmpty) {
      return const Center(child: Text('No hay logs del sistema coincidentes.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final tipo = log['tipo']?.toString() ?? 'SISTEMA';
        final desc = log['descripcion']?.toString() ?? '';
        final fecha = _formatFecha(log['created_at']);

        // Determine icon & color based on log type
        Color logColor = Colors.cyanAccent;
        IconData logIcon = Icons.info_outline;

        if (tipo.contains('error') || tipo.contains('fail')) {
          logColor = Colors.redAccent;
          logIcon = Icons.error_outline;
        } else if (tipo.contains('exito') || tipo.contains('aprobado') || tipo.contains('confirmado')) {
          logColor = const Color(0xFF00E676);
          logIcon = Icons.check_circle_outline;
        } else if (tipo.contains('reembolso')) {
          logColor = Colors.orangeAccent;
          logIcon = Icons.settings_backup_restore_rounded;
        }

        return Card(
          color: const Color(0xFF001F3F).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: logColor.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _verDetallesLog(log, 'Detalle Log Sistema'),
            leading: CircleAvatar(
              backgroundColor: logColor.withOpacity(0.12),
              child: Icon(logIcon, color: logColor),
            ),
            title: Text(
              tipo.toUpperCase().replaceAll('_', ' '),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ),
        );
      },
    );
  }

  Widget _buildCommissionLogsTab() {
    final filtered = _filtrar(_commissionLogs, ['descripcion', 'tipo']);
    if (filtered.isEmpty) {
      return const Center(child: Text('No hay logs de comisiones coincidentes.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final desc = log['descripcion']?.toString() ?? 'Cálculo de comisión';
        final tipo = log['tipo']?.toString() ?? 'comision';
        final fecha = _formatFecha(log['created_at']);
        final datos = log['datos_adicionales'] ?? {};
        final double? comisionMonto = (datos['monto_comision'] ?? datos['fee_monto'] ?? datos['comision']) as double?;

        return Card(
          color: const Color(0xFF001F3F).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _verDetallesLog(log, 'Detalle de Comisión'),
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.12),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blueAccent),
            ),
            title: Text(
              tipo.toUpperCase().replaceAll('_', ' '),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (comisionMonto != null)
                  Text(
                    '+\$${comisionMonto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminLogsTab() {
    final filtered = _filtrar(_adminLogs, ['accion', 'modulo', 'entidad_id']);
    if (filtered.isEmpty) {
      return const Center(child: Text('No hay actividad de administrador coincidente.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final accion = log['accion']?.toString() ?? 'ACCIÓN';
        final modulo = log['modulo']?.toString() ?? 'general';
        final fecha = _formatFecha(log['created_at']);
        final adminId = log['admin_id']?.toString() ?? '';

        return Card(
          color: const Color(0xFF001F3F).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orangeAccent.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _verDetallesLog(log, 'Detalle Actividad Admin'),
            leading: CircleAvatar(
              backgroundColor: Colors.orangeAccent.withOpacity(0.12),
              child: const Icon(Icons.gavel_rounded, color: Colors.orangeAccent),
            ),
            title: Text(
              accion.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Módulo: ${modulo.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin UUID: ${adminId.isNotEmpty && adminId.length > 8 ? adminId.substring(0, 8) : adminId}',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ),
        );
      },
    );
  }

  Widget _buildDownloadLogsTab() {
    final filtered = _filtrar(_downloadLogs, ['origen', 'dispositivo']);
    if (filtered.isEmpty) {
      return const Center(child: Text('No hay registros de descargas.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final origen = log['origen']?.toString() ?? 'DESCARGA';
        final dispositivo = log['dispositivo']?.toString() ?? 'Otro';
        final fecha = _formatFecha(log['creado_at']);

        Color logColor = const Color(0xFF00E676);
        IconData logIcon = Icons.download_done_rounded;

        if (dispositivo.toLowerCase() == 'ios') {
          logColor = Colors.lightBlueAccent;
          logIcon = Icons.phone_iphone_rounded;
        } else if (dispositivo.toLowerCase() == 'android') {
          logColor = Colors.greenAccent;
          logIcon = Icons.phone_android_rounded;
        }

        String sourceText = 'Enlace directo';
        if (origen.toLowerCase() == 'qr') {
          sourceText = 'Código QR';
        } else if (origen.toLowerCase() == 'boton') {
          sourceText = 'Botón de descarga';
        } else if (origen.toLowerCase() == 'direct_url') {
          sourceText = 'URL Directa (/descarga)';
        }

        return Card(
          color: const Color(0xFF001F3F).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: logColor.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _verDetallesLog(log, 'Detalle de Descarga'),
            leading: CircleAvatar(
              backgroundColor: logColor.withOpacity(0.12),
              child: Icon(logIcon, color: logColor),
            ),
            title: Text(
              'Descarga - $sourceText',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Dispositivo: $dispositivo',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ),
        );
      },
    );
  }
}
