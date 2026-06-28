import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';

import '../services/supabase_service.dart';

class DocumentosPendientesScreen extends StatefulWidget {
  const DocumentosPendientesScreen({super.key});

  @override
  State<DocumentosPendientesScreen> createState() => _DocumentosPendientesScreenState();
}

class _DocumentosPendientesScreenState extends State<DocumentosPendientesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendientesCapitanes = [];
  List<Map<String, dynamic>> _pendientesPescadores = [];
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _accentColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    try {
      setState(() => _isLoading = true);
      final data = await SupabaseService.getPerfilesPendientes(); 
      
      setState(() {
        // FILTRO ESTRICTO: Si es_capitan es true -> va a Capitanes. Si no -> va a Pescadores.
        _pendientesCapitanes = data.where((u) => u['es_capitan'] == true).toList();
        _pendientesPescadores = data.where((u) => u['es_capitan'] != true).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error de Conexión'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarSocio(Map<String, dynamic> socio, String estado, {String? expediente}) async {
    try {
      await SupabaseService.actualizarEstadoSocio(socio['user_id'], estado, expediente: expediente);
      if (mounted) {
        final bool esActivo = estado == 'activo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esActivo ? 'Socio admitido y traspasado con éxito' : 'Socio rechazado'),
            backgroundColor: esActivo ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _cargarPendientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _verDocumentos(Map<String, dynamic> capitan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(10), // Margen para que no toque los bordes del celular
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9, // 90% del ancho de la pantalla
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20), // Un poco menos de padding en movil
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: capitan['es_capitan'] == true ? Colors.blue[900] : Colors.green[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          capitan['es_capitan'] == true ? '⚓ CUENTA EL CAPITÁN' : '🎣 CUENTA EL PESCADOR',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        capitan['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 40),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildDocItem('Avatar', capitan['avatar_url']),
                          _buildDocItem('DNI', capitan['dni_url'] ?? capitan['foto_dni_url']),
                          // Solo mostramos estos si es capitán
                          if (capitan['es_capitan'] == true) ...[
                            _buildDocItem('Carnet Timonel', capitan['carnet_url']),
                            _buildDocItem('Seguro', capitan['seguro_url']),
                            _buildDocItem('Embarcación', capitan['embarcacion_url']),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'ASIGNACIÓN DE EXPEDIENTE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          onChanged: (val) => capitan['temp_expediente'] = val,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'NÚMERO DE EXPEDIENTE',
                            hintText: 'Ej: EXP-2024-001',
                            prefixIcon: const Icon(Icons.assignment, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                            isDense: true, // Mas compacto para evitar el overflow
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botones de acción optimizados para móvil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CERRAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ),
                    SafeElevatedIconButton(
  onPressed: () {
                        Navigator.pop(context);
                        _procesarSocio(capitan, 'rechazado');
                      },
  icon: Icons.cancel,
  iconSize: 18,
  label: 'RECHAZAR',
  textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
  style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red[100]!)),
                      ),
),
                    SafeElevatedIconButton(
  onPressed: () {
                        Navigator.pop(context);
                        _procesarSocio(capitan, 'activo', expediente: capitan['temp_expediente']);
                      },
  icon: Icons.verified,
  iconSize: 18,
  label: 'ADMITIR SOCIO',
  textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
  style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                        shadowColor: _primaryColor.withOpacity(0.4),
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

  Widget _buildDocItem(String titulo, String? url) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            titulo.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: url != null ? () => _mostrarImagenGrande(url, titulo) : null,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: url != null && url.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                    ),
                  )
                : const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.no_photography_outlined, color: Colors.grey, size: 32),
                      SizedBox(height: 8),
                      Text('No cargado', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )),
          ),
        ),
      ],
    );
  }

  void _mostrarImagenGrande(String url, String titulo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url),
            ),
            Positioned(
              top: 10, right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('CENTRAL DE ADMISIONES', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _cargarPendientes,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 5,
            tabs: [
              Tab(icon: Icon(Icons.anchor), text: 'CAPITANES (NÁUTICOS)'),
              Tab(icon: Icon(Icons.phishing), text: 'PESCADORES (CLIENTES)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent(_pendientesCapitanes, true),
            _buildTabContent(_pendientesPescadores, false),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<Map<String, dynamic>> lista, bool esCapitan) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          color: esCapitan ? _accentColor : Colors.green[700],
          child: Text(
            'Tienes ${lista.length} solicitudes de ${esCapitan ? 'Capitanes' : 'Pescadores'} pendientes.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : lista.isEmpty
                  ? _buildEmptyState(esCapitan)
                  : _buildDataTable(lista),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool esCapitan) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: esCapitan ? Colors.blue[50] : Colors.green[50], 
              shape: BoxShape.circle
            ),
            child: Icon(
              esCapitan ? Icons.anchor : Icons.phishing, 
              size: 80, 
              color: esCapitan ? Colors.blue[400] : Colors.green[400]
            ),
          ),
          const SizedBox(height: 24),
          const Text('¡Todo al día!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            esCapitan 
              ? 'No hay nuevos capitanes para revisión.' 
              : 'No hay nuevos pescadores esperando.', 
            style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> lista) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final cap = lista[index];
        // Generamos un Numero de Legajo temporal basado en el ID si no tiene uno
        final String legajoId = 'LEG-${cap['user_id'].toString().substring(0, 4).toUpperCase()}-${DateTime.now().year}';
        final bool esCapitan = cap['es_capitan'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: esCapitan ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              // Encabezado de la Carpeta (Legajo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: esCapitan ? Colors.blue[50] : Colors.green[50],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(esCapitan ? Icons.folder_shared : Icons.folder_open, size: 16, color: esCapitan ? Colors.blue[800] : Colors.green[800]),
                        const SizedBox(width: 6),
                        Text(
                          'LEGAJO: $legajoId',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: esCapitan ? Colors.blue[900] : Colors.green[900], letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: esCapitan ? Colors.blue[100]! : Colors.green[100]!),
                      ),
                      child: Text(
                        esCapitan ? '⚓ CUENTA CAPITÁN' : '🎣 CUENTA PESCADOR',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: esCapitan ? Colors.blue[700] : Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenido de la Carpeta
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: cap['user_id'],
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: esCapitan ? Colors.blue[100]! : Colors.green[100]!, width: 2),
                              image: DecorationImage(
                                image: cap['avatar_url'] != null ? NetworkImage(cap['avatar_url']) : const AssetImage('assets/placeholder_user.png') as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cap['nombre'] ?? 'Sin Nombre', 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.badge_outlined, size: 12, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Text('DNI: ${cap['dni'] ?? 'N/A'}', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                                ],
                              ),
                              Text(cap['telefono'] ?? 'N/A', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: SafeElevatedIconButton(
  onPressed: () => _verDocumentos(cap),
  icon: Icons.visibility,
  iconSize: 16,
  label: 'REVISAR LEGAJO COMPLETO',
  textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
  style: ElevatedButton.styleFrom(
                          backgroundColor: esCapitan ? const Color(0xFF0D47A1) : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
