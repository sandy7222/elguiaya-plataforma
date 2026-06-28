import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/notificacion_helper.dart';
import 'dart:ui';
import '../widgets/safe_button.dart';

class AdminPerfilValidationScreen extends StatefulWidget {
  const AdminPerfilValidationScreen({super.key});

  @override
  State<AdminPerfilValidationScreen> createState() => _AdminPerfilValidationScreenState();
}

class _AdminPerfilValidationScreenState extends State<AdminPerfilValidationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _perfiles = [];
  String _filtroRol = 'todos'; // 'todos', 'capitan', 'pescador'
  
  final Color _primaryBlue = const Color(0xFF0D47A1);
  final Color _accentGold = const Color(0xFFFFC107);
  final Color _bgDark = const Color(0xFF001A33);

  @override
  void initState() {
    super.initState();
    _cargarPerfiles();
  }

  Future<void> _cargarPerfiles() async {
    try {
      setState(() => _isLoading = true);
      final data = await SupabaseService.getPerfilesPendientes();
      setState(() {
        _perfiles = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfiles: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  double _calcularTrustScore(Map<String, dynamic> perfil) {
    double score = 0;
    if (perfil['avatar_url'] != null) score += 20;
    if (perfil['dni'] != null) score += 20;
    if (perfil['telefono'] != null) score += 20;
    if (perfil['localidad'] != null) score += 20;
    if (perfil['es_capitan'] == true) {
      if (perfil['carnet_url'] != null) score += 10;
      if (perfil['seguro_url'] != null) score += 10;
    } else {
      score += 20; // Pescadores tienen menos campos
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CENTRO DE VALIDACIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDark, const Color(0xFF003366)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsHeader(),
              _buildFilterBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _perfiles.isEmpty
                        ? _buildEmptyState()
                        : _buildProfileGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('PENDIENTES', _perfiles.length.toString(), Icons.hourglass_empty, Colors.orange),
          _buildStatItem('CALIDAD ALTA', _perfiles.where((p) => _calcularTrustScore(p) > 80).length.toString(), Icons.verified, Colors.green),
          _buildStatItem('VALOR PROY.', '\$${_perfiles.length * 150}k', Icons.trending_up, _accentGold),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip('TODOS', 'todos'),
          const SizedBox(width: 8),
          _buildFilterChip('CAPITANES', 'capitan'),
          const SizedBox(width: 8),
          _buildFilterChip('PESCADORES', 'pescador'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filtroRol == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroRol = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accentGold : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _accentGold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileGrid() {
    // Filtrado en el cliente para mayor velocidad de respuesta
    final filtrados = _perfiles.where((p) {
      if (_filtroRol == 'todos') return true;
      if (_filtroRol == 'capitan') return p['es_capitan'] == true;
      if (_filtroRol == 'pescador') return p['es_capitan'] == false;
      return true;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final perfil = filtrados[index];
        return _buildProfileCard(perfil);
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> perfil) {
    double score = _calcularTrustScore(perfil);
    bool esCapitan = perfil['es_capitan'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar con Score
              Stack(
                children: [
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: perfil['avatar_url'] != null
                          ? DecorationImage(image: NetworkImage(perfil['avatar_url']), fit: BoxFit.cover)
                          : null,
                      color: Colors.white10,
                    ),
                    child: perfil['avatar_url'] == null 
                        ? const Icon(Icons.person, color: Colors.white30, size: 50) 
                        : null,
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: _accentGold, size: 12),
                          const SizedBox(width: 4),
                          Text('${score.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: esCapitan ? Colors.blue : Colors.green,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        esCapitan ? 'CAPITÁN' : 'PESCADOR',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil['nombre'] ?? 'Sin Nombre',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${perfil['localidad'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _verDetalle(perfil),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('VALIDAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verDetalle(Map<String, dynamic> perfil) {
    // Reutilizamos la logica de ver documentos o abrimos un nuevo panel lateral
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildValidationPanel(perfil),
    );
  }

  Widget _buildValidationPanel(Map<String, dynamic> perfil) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('REVISIÓN DE SOCIO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDetailRow('Nombre Completo', perfil['nombre'] ?? 'No especificado'),
                  _buildDetailRow('DNI / Identificación', perfil['dni'] ?? 'No especificado'),
                  _buildDetailRow('Dirección', '${perfil['direccion_calle'] ?? 'N/A'} ${perfil['direccion_numero'] ?? ''}'),
                  _buildDetailRow('Ubicación', '${perfil['localidad'] ?? 'N/A'}, ${perfil['provincia'] ?? 'N/A'}'),
                  _buildDetailRow('Código Postal', perfil['cp']?.toString() ?? 'N/A'),
                  _buildDetailRow('Teléfono', perfil['telefono'] ?? 'No especificado'),
                  if (perfil['es_capitan'] == true)
                    _buildDetailRow('Capacidad Embarcación', '${perfil['capacidad_personas'] ?? 0} Personas'),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
                  const Text('DOCUMENTACIÓN ADJUNTA', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 16),
                  _buildDocumentGallery(perfil),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _procesar(perfil, 'rechazado'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('RECHAZAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _procesar(perfil, 'activo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('APROBAR PERFIL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDocumentGallery(Map<String, dynamic> perfil) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (perfil['foto_dni_url'] != null || perfil['dni_url'] != null) 
            _buildMiniDoc('DNI', perfil['foto_dni_url'] ?? perfil['dni_url']!),
          if (perfil['carnet_url'] != null) _buildMiniDoc('TIMONEL', perfil['carnet_url']),
          if (perfil['seguro_url'] != null) _buildMiniDoc('SEGURO', perfil['seguro_url']),
          if (perfil['embarcacion_url'] != null) _buildMiniDoc('BARCO', perfil['embarcacion_url']),
        ],
      ),
    );
  }

  Widget _buildMiniDoc(String label, String url) {
    return GestureDetector(
      onTap: () => _mostrarImagenFull(url, label),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 140, height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))],
                image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  void _mostrarImagenFull(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black87),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                SafeTextIconButton(
  onPressed: () => Navigator.pop(context),
  icon: Icons.close,
  iconColor: Colors.white,
  label: 'CERRAR',
  textStyle: TextStyle(color: Colors.white),
),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesar(Map<String, dynamic> perfil, String estado) async {
    try {
      await SupabaseService.actualizarEstadoSocio(perfil['user_id'], estado);

      // Notificar al usuario según la decisión del admin
      final userId = perfil['user_id'] as String?;
      final esCapitan = perfil['es_capitan'] == true;
      if (userId != null) {
        if (estado == 'activo') {
          await NotificacionHelper.perfilAprobado(userId);
        } else if (estado == 'rechazado') {
          final motivo = esCapitan
              ? 'Revisá tu documentación (carnet, seguro o foto de embarcación) y volvela a subir.'
              : 'Revisá tus datos y documentación y volvelos a subir.';
          await NotificacionHelper.perfilRechazado(userId, motivo);
        }
      }

      if (mounted) Navigator.pop(context);
      _cargarPerfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(estado == 'activo'
                ? '✅ Socio ACTIVADO — se le notificó por la campanita'
                : '❌ Socio rechazado — se le notificó para que corrija'),
            backgroundColor: estado == 'activo' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all, color: Colors.white24, size: 80),
          const SizedBox(height: 24),
          const Text('¡MISIÓN CUMPLIDA!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No hay perfiles pendientes de validación.', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
