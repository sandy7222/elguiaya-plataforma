import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

class DirectorioCapitanesScreen extends StatefulWidget {
  const DirectorioCapitanesScreen({super.key});

  @override
  State<DirectorioCapitanesScreen> createState() => _DirectorioCapitanesScreenState();
}

class _DirectorioCapitanesScreenState extends State<DirectorioCapitanesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _capitanes = [];
  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _accentColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _cargarCapitanes();
  }

  Future<void> _cargarCapitanes() async {
    try {
      setState(() => _isLoading = true);
      final data = await SupabaseService.getDirectorioCapitanes();
      setState(() {
        _capitanes = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar capitanes: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _generarPDF(Map<String, dynamic> cap) async {
    try {
      await PdfService.generarFichaSocio(cap);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _descargarDocumentos(Map<String, dynamic> cap) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparando paquete de documentos para descarga...'), backgroundColor: Colors.green),
    );
  }

  void _verLegajo(Map<String, dynamic> cap) {
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
            border: Border.all(color: const Color(0xFF001F3F), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado Premium CapitánYA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF001F3F),
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
                        backgroundImage: cap['avatar_url'] != null ? NetworkImage(cap['avatar_url']) : null,
                        child: cap['avatar_url'] == null ? const Icon(Icons.person, size: 35, color: Color(0xFF001F3F)) : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EL GUIA YA - LEGAJO INTERNO', 
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            cap['nombre'] ?? 'SOCIO REGISTRADO', 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('ID: ${cap['id']?.toString().substring(0, 8).toUpperCase() ?? 'S/N'}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
                  ],
                ),
              ),
              
              // Cuerpo del Documento
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      _buildInfoBlock('INFORMACIÓN PERSONAL', [
                        _buildDataRow('DNI', cap['dni']?.toString() ?? 'N/A'),
                        _buildDataRow('MATRÍCULA', cap['expediente'] ?? 'PENDIENTE'),
                        _buildDataRow('TELÉFONO', cap['telefono'] ?? 'N/A'),
                        _buildDataRow('EMAIL', cap['email'] ?? cap['user_email'] ?? 'No registrado'),
                        _buildDataRow('CAPACIDAD', '${cap['capacidad_personas'] ?? 0} PERSONAS'),
                      ]),
                      const SizedBox(height: 20),
                      _buildInfoBlock('DOMICILIO DECLARADO', [
                        _buildDataRow('CALLE', cap['direccion_calle'] ?? cap['calle'] ?? 'No declarada'),
                        _buildDataRow('ALTURA', cap['direccion_numero'] ?? cap['altura'] ?? 'S/N'),
                        _buildDataRow('LOCALIDAD', cap['localidad'] ?? 'No declarada'),
                        _buildDataRow('PROVINCIA', cap['provincia'] ?? 'No declarada'),
                        _buildDataRow('C. POSTAL', cap['cp']?.toString() ?? 'N/A'),
                      ]),
                      const SizedBox(height: 20),
                      _buildInfoBlock('DATOS BANCARIOS', [
                        _buildDataRow('CBU / CVU', cap['cbu'] ?? 'No declarado'),
                        _buildDataRow('BANCO / ENTIDAD', cap['banco_nombre'] ?? 'No declarado'),
                      ]),
                      const SizedBox(height: 20),
                      const _SectionHeader(title: 'REVISIÓN DE DOCUMENTACIÓN', icon: Icons.verified_user),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DocCardCompact(label: 'DNI', url: cap['dni_url'] ?? cap['foto_dni_url']),
                          _DocCardCompact(label: 'CARNET', url: cap['carnet_url']),
                          _DocCardCompact(label: 'SEGURO', url: cap['seguro_url']),
                          _DocCardCompact(label: 'LANCHA', url: cap['embarcacion_url']),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Pie con Sello de Agua El Guia YA (Privado)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.anchor, color: Color(0xFFE2E8F0), size: 40),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('CERRAR ARCHIVO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001F3F),
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
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF001F3F), letterSpacing: 1.5)),
        const Divider(color: Color(0xFF001F3F), thickness: 1.5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GESTIÓN NÁUTICA', style: TextStyle(fontSize: 14, letterSpacing: 1.2, fontWeight: FontWeight.w400)),
            Text('Directorio de Capitanes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _cargarCapitanes,
            icon: const Icon(Icons.refresh),
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
              'Total matriculados: ${_capitanes.length} capitanes activos.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _capitanes.isEmpty
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
          Icon(Icons.anchor_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No hay capitanes activos matriculados.', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // MODO MÓVIL: Lista de Tarjetas (Fichas de Capitán)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _capitanes.length,
            itemBuilder: (context, index) {
              final c = _capitanes[index];
              
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
                            radius: 25,
                            backgroundColor: _primaryColor.withOpacity(0.1),
                            backgroundImage: c['avatar_url'] != null ? NetworkImage(c['avatar_url']) : null,
                            child: c['avatar_url'] == null ? Icon(Icons.anchor, color: _primaryColor) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['nombre'] ?? 'Capitán N/A',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Matrícula: ${c['expediente'] ?? 'S/N'}',
                                  style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c['direccion_calle'] ?? c['calle'] ?? ''} ${c['direccion_numero'] ?? c['altura'] ?? ''}, ${c['localidad'] ?? 'N/A'}',
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
                          _buildActionBtn(Icons.visibility_outlined, 'Ficha', Colors.blue, () => _verLegajo(c)),
                          _buildActionBtn(Icons.picture_as_pdf, 'PDF', Colors.redAccent, () => _generarPDF(c)),
                          _buildActionBtn(Icons.file_download, 'Docs', Colors.green, () => _descargarDocumentos(c)),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
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
                    const DataColumn(label: Text('MATRÍCULA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('CAPITÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('DIRECCIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
                      const DataColumn(label: Text('LOCALIDAD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      const DataColumn(label: Text('TELÉFONO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    const DataColumn(label: Text('EXPORTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const DataColumn(label: Text('FICHA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _capitanes.map((c) {
                    return DataRow(cells: [
                      DataCell(Text(c['expediente'] ?? 'S/N', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue))),
                      DataCell(Text(c['nombre'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${c['direccion_calle'] ?? c['calle'] ?? ''} ${c['direccion_numero'] ?? c['altura'] ?? ''}', style: const TextStyle(fontSize: 12))),
                      if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
                        DataCell(Text(c['localidad'] ?? 'N/A', style: const TextStyle(fontSize: 11))),
                        DataCell(Text(c['telefono'] ?? 'N/A', style: const TextStyle(fontSize: 11))),
                      ],
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20), onPressed: () => _generarPDF(c)),
                            IconButton(icon: const Icon(Icons.file_download, color: Colors.green, size: 20), onPressed: () => _descargarDocumentos(c)),
                          ],
                        ),
                      ),
                      DataCell(
                        IconButton(icon: const Icon(Icons.visibility_outlined, color: Colors.blue), onPressed: () => _verLegajo(c)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        Icon(icon, size: 18, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), letterSpacing: 1.1)),
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
