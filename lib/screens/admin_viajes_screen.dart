
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/auditor_map_widget.dart';
import 'manifiesto_pasajeros_screen.dart';
import 'admin_detalle_viaje_screen.dart';
import '../widgets/reputacion_badge_widget.dart';

class AdminViajesScreen extends StatefulWidget {
  const AdminViajesScreen({super.key});

  @override
  State<AdminViajesScreen> createState() => _AdminViajesScreenState();
}

class _AdminViajesScreenState extends State<AdminViajesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _viajesActivos = [];
  String _filtroEstado = 'todos'; // todos | en_curso | listo_para_confirmar | cerrado | en_disputa
  String _busqueda = '';
  
  // Colores Premium
  static const Color _azulNautico = Color(0xFF0D47A1);
  static const Color _naranjaMar = Color(0xFFFB8C00);
  static const Color _verde = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _cargarViajes();
  }

  Future<void> _cargarViajes() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('pedidos')
          .select('*, pescador:pescador_id(nombre), capitan:capitan_id(nombre, avatar_url)')
          .order('created_at', ascending: false);
      
      setState(() {
        _viajesActivos = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error al cargar viajes reales: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _viajesFiltrados {
    var lista = _viajesActivos;
    if (_filtroEstado != 'todos') {
      lista = lista.where((v) => v['estado']?.toString() == _filtroEstado).toList();
    }
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista.where((v) {
        final id = v['id']?.toString() ?? '';
        final codigo = '#VJ-${id.replaceAll('-', '').toUpperCase().substring(0, 4)}';
        final capitan = v['capitan']?['nombre']?.toString().toLowerCase() ?? '';
        final pescador = v['pescador']?['nombre']?.toString().toLowerCase() ?? '';
        return codigo.toLowerCase().contains(q) || capitan.contains(q) || pescador.contains(q);
      }).toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Monitoreo de Viajes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarViajes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _azulNautico))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryHeader(),
                  const SizedBox(height: 12),
                  // Buscador
                  TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código #VJ-XXXX, capitán o pescador...',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.black38, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  // Filtros de estado
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFiltroChip('Todos', 'todos'),
                        const SizedBox(width: 6),
                        _buildFiltroChip('En curso', 'en_curso'),
                        const SizedBox(width: 6),
                        _buildFiltroChip('Por confirmar', 'listo_para_confirmar'),
                        const SizedBox(width: 6),
                        _buildFiltroChip('Cerrados', 'cerrado'),
                        const SizedBox(width: 6),
                        _buildFiltroChip('⚠ Disputa', 'en_disputa'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_viajesFiltrados.length} viaje${_viajesFiltrados.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _viajesFiltrados.length,
                      itemBuilder: (context, index) => _buildViajeCard(_viajesFiltrados[index]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azulNautico, Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _azulNautico.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Viajes', '${_viajesActivos.length}', Icons.anchor),
          _buildSummaryItem('Pasajeros', '${_viajesActivos.fold(0, (sum, item) => sum + (item['pasajeros'] as int))}', Icons.people),
          _buildSummaryItem('Lanchas', '2', Icons.directions_boat),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final estado = viaje['estado']?.toString() ?? 'desconocido';
    final bool enCurso = estado == 'en_curso';
    final bool esperandoConfirmar = estado == 'listo_para_confirmar';
    final rawId = viaje['id']?.toString() ?? '--------';
    final codigoViaje = '#VJ-${rawId.replaceAll('-', '').toUpperCase().substring(0, 4)}';
    
    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'en_curso': estadoColor = _verde; estadoIcon = Icons.play_arrow_rounded; break;
      case 'listo_para_confirmar': estadoColor = Colors.orangeAccent; estadoIcon = Icons.hourglass_top_rounded; break;
      case 'cerrado': estadoColor = Colors.blueAccent; estadoIcon = Icons.lock_rounded; break;
      case 'en_disputa': estadoColor = Colors.redAccent; estadoIcon = Icons.warning_rounded; break;
      default: estadoColor = _naranjaMar; estadoIcon = Icons.timer;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: estadoColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(estadoIcon, color: estadoColor),
        ),
        title: Row(
          children: [
            Text(
              codigoViaje,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: estadoColor, letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                viaje['capitan']?['nombre'] ?? 'Capítán',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text('Pescador: ${viaje['pescador']?['nombre'] ?? 'N/A'} | ${viaje['created_at']?.toString().substring(0, 10) ?? ''}'),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: estadoColor.withOpacity(0.3)),
              ),
              child: Text(
                estado.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(color: estadoColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDetalleViajeScreen(viaje: viaje),
          ),
        ).then((_) => _cargarViajes()),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor) {
    final selected = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _azulNautico : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _azulNautico : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.black54, fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  // --- ADMIN FORENSIC VIEW ---
  void _mostrarDetalleForense(Map<String, dynamic> viaje) {
    final trackLog = viaje['track_log'] as List<dynamic>? ?? [];
    
    // Cálculo de Distancia y Tiempo
    double distanciaTotal = 0;
    Duration duracion = Duration.zero;

    if (trackLog.length > 1) {
      for (int i = 0; i < trackLog.length - 1; i++) {
        distanciaTotal += Geolocator.distanceBetween(
          trackLog[i]['lat'], trackLog[i]['lng'],
          trackLog[i+1]['lat'], trackLog[i+1]['lng']
        );
      }
      distanciaTotal = distanciaTotal / 1000; // Convertir a KM

      final inicio = DateTime.parse(trackLog.first['ts']);
      final fin = DateTime.parse(trackLog.last['ts']);
      duracion = fin.difference(inicio);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF001F3F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Forense
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AUDITORÍA DE VIAJE', 
                      style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
                    Text('ID: ${viaje['id'].toString().substring(0, 8)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // MAPA DE AUDITORÍA
            AuditorMapWidget(trackLog: trackLog),
            
            const SizedBox(height: 24),
            
            // PANEL LATERAL DE KPIs (Ahora como fila de tarjetas)
            Row(
              children: [
                Expanded(child: _buildForensicKPI('DISTANCIA', '${distanciaTotal.toStringAsFixed(2)} KM', Icons.straighten)),
                const SizedBox(width: 12),
                Expanded(child: _buildForensicKPI('DURACIÓN', '${duracion.inMinutes} MIN', Icons.timer)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Datos del Capitán y Lancha
            _buildInfoRow('CAPITÁN', viaje['capitan']?['nombre'] ?? 'N/A'),
            _buildInfoRow('CLIENTE', viaje['pescador']?['nombre'] ?? 'N/A'),
            _buildInfoRow('ESTADO', viaje['estado'].toString().toUpperCase(), color: Colors.greenAccent),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ManifiestoPasajerosScreen(
                    pedidoId: viaje['id']?.toString() ?? '',
                  )));
                },
                icon: const Icon(Icons.assignment),
                label: const Text('VER MANIFIESTO DE PASAJEROS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForensicKPI(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
