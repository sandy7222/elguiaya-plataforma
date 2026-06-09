import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

class DirectorioPescadoresScreen extends StatefulWidget {
  const DirectorioPescadoresScreen({super.key});

  @override
  State<DirectorioPescadoresScreen> createState() => _DirectorioPescadoresScreenState();
}

class _DirectorioPescadoresScreenState extends State<DirectorioPescadoresScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pescadores = [];
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _accentColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _cargarPescadores();
  }

  Future<void> _cargarPescadores() async {
    try {
      setState(() => _isLoading = true);
      final data = await SupabaseService.getDirectorioPescadores();
      setState(() {
        _pescadores = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pescadores: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _generarPDF(Map<String, dynamic> p) async {
    try {
      await PdfService.generarFichaSocio(p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _descargarDocumentos(Map<String, dynamic> p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando legajo documental de ${p['nombre']}...'), backgroundColor: Colors.green),
    );
  }

  void _verLegajo(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.98,
          constraints: const BoxConstraints(maxWidth: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF1B5E20), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado Premium Pescador (Verde Bosque / Oro)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B5E20),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(27), topRight: Radius.circular(27)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null,
                        child: p['avatar_url'] == null ? const Icon(Icons.person, size: 35, color: Color(0xFF1B5E20)) : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EL GUIA YA - LEGAJO DE SOCIO', 
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p['nombre'] ?? 'PESCADOR REGISTRADO', 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('ID: ${p['id']?.toString().substring(0, 8).toUpperCase() ?? 'S/N'}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
                  ],
                ),
              ),
              
              // Cuerpo
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      _buildInfoBlock('PERFIL DEL PESCADOR', [
                        _buildDataRow('DNI', p['dni']?.toString() ?? 'N/A'),
                        _buildDataRow('TELÉFONO', p['telefono'] ?? 'N/A'),
                        _buildDataRow('EMAIL', p['email'] ?? 'N/A'),
                        _buildDataRow('C. POSTAL', p['cp']?.toString() ?? 'N/A'),
                      ]),
                      const SizedBox(height: 20),
                      _buildInfoBlock('DOMICILIO DE ENVÍO', [
                        _buildDataRow('CALLE', p['direccion_calle'] ?? p['calle'] ?? 'No declarada'),
                        _buildDataRow('ALTURA', p['direccion_numero'] ?? p['altura'] ?? 'S/N'),
                        _buildDataRow('LOCALIDAD', p['localidad'] ?? 'N/A'),
                        _buildDataRow('PROVINCIA', p['provincia'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 20),
                      const _SectionHeader(title: 'IDENTIFICACIÓN DIGITAL', icon: Icons.badge),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DocCardCompact(label: 'PERFIL', url: p['avatar_url']),
                          const SizedBox(width: 20),
                          _DocCardCompact(label: 'DNI FRENTE', url: p['dni_url'] ?? p['foto_dni_url']),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Pie
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.waves, color: Colors.green[50], size: 40),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('CERRAR ARCHIVO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  Widget _buildInfoBlock(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800], letterSpacing: 1.5)),
        Divider(color: Colors.green[800], thickness: 1.5),
        ...rows,
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Future<void> _cambiarEstado(String userId, String nuevoEstado) async {
    try {
      await SupabaseService.actualizarEstadoPescador(userId, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevoEstado == 'activo' ? 'Acceso habilitado' : 'Usuario bloqueado'),
            backgroundColor: nuevoEstado == 'activo' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _cargarPescadores();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GESTIÓN DE CLIENTES', style: TextStyle(fontSize: 14, letterSpacing: 1.2, fontWeight: FontWeight.w400)),
            Text('Directorio de Pescadores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _cargarPescadores,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: _accentColor,
            child: Text(
              'Total registrados: ${_pescadores.length} pescadores.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pescadores.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No hay pescadores registrados aún.', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // MODO MÓVIL: Lista de Tarjetas (Fichas)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pescadores.length,
            itemBuilder: (context, index) {
              final p = _pescadores[index];
              final bool estaActivo = p['estado'] == 'activo';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _primaryColor.withOpacity(0.1),
                            backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null,
                            child: p['avatar_url'] == null ? Icon(Icons.person, color: _primaryColor) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['nombre'] ?? 'N/A',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Socio: ${p['expediente'] ?? 'S/N'}',
                                  style: TextStyle(color: _accentColor, fontWeight: FontWeight.w500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: estaActivo ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              estaActivo ? 'ACTIVO' : 'BLOQUEADO',
                              style: TextStyle(color: estaActivo ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p['direccion_calle'] ?? p['calle'] ?? ''} ${p['direccion_numero'] ?? p['altura'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionBtn(Icons.visibility_outlined, 'Ver', Colors.blue, () => _verLegajo(p)),
                          _buildActionBtn(Icons.picture_as_pdf, 'PDF', Colors.redAccent, () => _generarPDF(p)),
                          _buildActionBtn(
                            estaActivo ? Icons.block : Icons.check_circle_outline,
                            estaActivo ? 'Bloquear' : 'Activar',
                            estaActivo ? Colors.red : Colors.green,
                            () => _cambiarEstado(p['user_id'], estaActivo ? 'bloqueado' : 'activo')
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // MODO DESKTOP: Tabla Tradicional
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  columnSpacing: 20,
                  dataRowHeight: 70,
                  columns: [
                    const DataColumn(label: Text('SOCIO #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('NOMBRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('DIRECCIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
                      const DataColumn(label: Text('LOCALIDAD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      const DataColumn(label: Text('TELÉFONO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    const DataColumn(label: Text('EXPORTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _pescadores.map((p) {
                    final bool estaActivo = p['estado'] == 'activo';
                    return DataRow(cells: [
                      DataCell(Text(p['expediente'] ?? 'S/N', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue))),
                      DataCell(Text(p['nombre'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${p['direccion_calle'] ?? p['calle'] ?? ''} ${p['direccion_numero'] ?? p['altura'] ?? ''}', style: const TextStyle(fontSize: 11))),
                      if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
                        DataCell(Text(p['localidad'] ?? 'N/A', style: const TextStyle(fontSize: 11))),
                        DataCell(Text(p['telefono'] ?? 'N/A', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                      ],
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20), onPressed: () => _generarPDF(p)),
                            IconButton(icon: const Icon(Icons.file_download, color: Colors.green, size: 20), onPressed: () => _descargarDocumentos(p)),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.visibility_outlined, color: Colors.blue), onPressed: () => _verLegajo(p)),
                            IconButton(
                              icon: Icon(estaActivo ? Icons.block : Icons.check_circle_outline, color: estaActivo ? Colors.red : Colors.green),
                              onPressed: () => _cambiarEstado(p['user_id'], estaActivo ? 'bloqueado' : 'activo')
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green[800]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800], letterSpacing: 1.1)),
      ],
    );
  }
}

class _DataField extends StatelessWidget {
  final String label;
  final String value;
  const _DataField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}

class _DocCardCompact extends StatelessWidget {
  final String label;
  final String? url;
  const _DocCardCompact({required this.label, this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 100,
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            border: Border.all(color: Colors.grey[200]!),
            image: url != null ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
          ),
          child: url == null ? const Icon(Icons.no_photography, color: Colors.grey) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }
}
