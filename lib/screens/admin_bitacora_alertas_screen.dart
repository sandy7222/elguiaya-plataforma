import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notificacion_service.dart';
import '../services/supabase_service.dart';

class AdminBitacoraAlertasScreen extends StatefulWidget {
  const AdminBitacoraAlertasScreen({super.key});

  @override
  State<AdminBitacoraAlertasScreen> createState() => _AdminBitacoraAlertasScreenState();
}

class _AdminBitacoraAlertasScreenState extends State<AdminBitacoraAlertasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notificaciones = [];
  Map<String, String> _userNamesCache = {};
  
  int _totalEnviadas = 0;
  int _totalLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargarBitacora();
  }

  Future<void> _cargarBitacora() async {
    setState(() => _isLoading = true);
    try {
      // Cargar historial desde NotificacionService
      final historial = await NotificacionService().obtenerHistorialNotificaciones(limit: 200);
      
      // Cargar perfiles para mapear nombres de usuarios
      final capitanes = await SupabaseService.getDirectorioCapitanes();
      final pescadores = await SupabaseService.getDirectorioPescadores();
      final todosLosUsuarios = [...capitanes, ...pescadores];
      
      final Map<String, String> nombresCache = {};
      for (var u in todosLosUsuarios) {
        final id = u['user_id'] ?? u['id'];
        final nombre = u['nombre'] ?? 'Usuario Desconocido';
        final rol = u['es_capitan'] == true ? '(Capitán)' : '(Pescador)';
        nombresCache[id.toString()] = '$nombre $rol';
      }

      int leidas = 0;
      for (var n in historial) {
        if (n['leido'] == true) leidas++;
      }

      if (mounted) {
        setState(() {
          _notificaciones = historial;
          _userNamesCache = nombresCache;
          _totalEnviadas = historial.length;
          _totalLeidas = leidas;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando bitácora: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return isoString; // Fallback al string crudo si falla el parseo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Bitácora de Auditoría', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyan), 
            onPressed: _cargarBitacora,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo oscuro degradado
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0E12), Color(0xFF020617), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                : Column(
                    children: [
                      // Dashboard Superior (Métricas)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Expanded(child: _buildMetricCard('Enviadas', _totalEnviadas.toString(), Icons.send_rounded, Colors.cyan)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildMetricCard('Apertura', '${_totalEnviadas > 0 ? ((_totalLeidas / _totalEnviadas) * 100).toStringAsFixed(1) : 0}%', Icons.visibility_rounded, Colors.greenAccent)),
                          ],
                        ),
                      ),
                      
                      // Lista de Historial (Auditoría)
                      Expanded(
                        child: _notificaciones.isEmpty
                            ? Center(
                                child: Text('No hay historial de alertas emitidas.', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: _notificaciones.length,
                                itemBuilder: (context, index) {
                                  final n = _notificaciones[index];
                                  final receptorId = n['receptor_id'].toString();
                                  
                                  // Cruce de ID a Nombre real
                                  final nombreDestino = _userNamesCache[receptorId] ?? 'UUID: ${receptorId.substring(0, 8)}...';
                                  
                                  final bool leido = n['leido'] == true;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      title: Text(n['titulo'] ?? 'Sin Título', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          Text('A: $nombreDestino', style: TextStyle(color: Colors.cyan.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 4),
                                          Text(n['contenido'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Text(_formatDate(n['created_at']), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            leido ? Icons.done_all_rounded : Icons.done_rounded,
                                            color: leido ? Colors.greenAccent : Colors.white.withValues(alpha: 0.4),
                                            size: 24,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            leido ? 'Leído' : 'Pendiente',
                                            style: TextStyle(
                                              color: leido ? Colors.greenAccent : Colors.white.withValues(alpha: 0.4),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
