import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class AdminLibroTransferenciasScreen extends StatefulWidget {
  const AdminLibroTransferenciasScreen({super.key});

  @override
  State<AdminLibroTransferenciasScreen> createState() =>
      _AdminLibroTransferenciasScreenState();
}

class _AdminLibroTransferenciasScreenState
    extends State<AdminLibroTransferenciasScreen> {
  static const int _pageSize = 50;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _busquedaController = TextEditingController();

  List<Map<String, dynamic>> _filas = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _offset = 0;
  int _totalCount = 0;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cargar(reset: false);
    }
  }

  Future<void> _cargar({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _filas = [];
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await SupabaseService.fetchLibroTransferenciasAdmin(
        limit: _pageSize,
        offset: reset ? 0 : _offset,
        desde: _desde,
        hasta: _hasta,
        busqueda: _busquedaController.text,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _filas = result.items;
        } else {
          _filas.addAll(result.items);
        }
        _totalCount = result.totalCount;
        _offset = _filas.length;
        _hasMore = result.items.length >= _pageSize;
        _isLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar libro: $e')),
      );
    }
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (esDesde) {
        _desde = DateTime(picked.year, picked.month, picked.day);
      } else {
        _hasta = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      }
    });
    _cargar(reset: true);
  }

  Future<void> _verTicket(String storagePath) async {
    try {
      final url = await StorageService.getSignedComprobanteUrl(storagePath);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF001A33),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                title: const Text('Ticket MP', style: TextStyle(color: Colors.white)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.cyanAccent),
                    tooltip: 'Compartir comprobante',
                    onPressed: () => Share.share(
                      'Comprobante de transferencia CapitanYA:\n$url',
                      subject: 'Comprobante MP',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: Colors.cyanAccent),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el comprobante',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir ticket: $e')),
      );
    }
  }

  String _formatFecha(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportarCsv() async {
    if (_filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Fecha,Capitan,Monto,N Comprobante,CBU,Admin',
    );
    for (final row in _filas) {
      final fecha = _formatFecha(row['procesado_at']);
      final capitan = (row['capitan_nombre'] ?? '').toString().replaceAll(',', ' ');
      final monto = (row['monto'] as num?)?.toStringAsFixed(2) ?? '0';
      final comprobante = (row['numero_comprobante'] ?? '').toString();
      final cbu = (row['cbu_enmascarado'] ?? '').toString();
      final admin = (row['admin_nombre'] ?? '').toString().replaceAll(',', ' ');
      buffer.writeln('$fecha,$capitan,$monto,$comprobante,$cbu,$admin');
    }

    await Share.share(
      buffer.toString(),
      subject: 'Libro de transferencias CapitanYA',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001A33),
        foregroundColor: Colors.white,
        title: Text(
          'Libro de transferencias',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: _exportarCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _cargar(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF001A33).withOpacity(0.6),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar por Nº comprobante o capitán...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _busquedaController.clear();
                        _cargar(reset: true);
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _cargar(reset: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(esDesde: true),
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _desde == null
                              ? 'Desde'
                              : '${_desde!.day}/${_desde!.month}/${_desde!.year}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(esDesde: false),
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(
                          _hasta == null
                              ? 'Hasta'
                              : '${_hasta!.day}/${_hasta!.month}/${_hasta!.year}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _desde = null;
                          _hasta = null;
                        });
                        _cargar(reset: true);
                      },
                      child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                if (_totalCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$_totalCount transferencias registradas',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : _filas.isEmpty
                    ? Center(
                        child: Text(
                          'Sin transferencias en este período',
                          style: GoogleFonts.outfit(color: Colors.white54),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.cyanAccent,
                        onRefresh: () => _cargar(reset: true),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.cyan.withOpacity(0.08),
                              ),
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Fecha',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Capitán',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Monto',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Nº comprobante',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'CBU',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Ticket',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: [
                                ..._filas.map((row) {
                                  final path =
                                      row['comprobante_storage_path']?.toString() ?? '';
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        _formatFecha(row['procesado_at']),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        row['capitan_nombre']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        '\$${(row['monto'] as num?)?.toStringAsFixed(2) ?? '0'}',
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        row['numero_comprobante']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        row['cbu_enmascarado']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        row['admin_nombre']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(
                                        path.isEmpty
                                            ? const Text('-')
                                            : IconButton(
                                                icon: const Icon(
                                                  Icons.receipt_long,
                                                  color: Colors.cyanAccent,
                                                  size: 20,
                                                ),
                                                onPressed: () => _verTicket(path),
                                              ),
                                      ),
                                    ],
                                  );
                                }),
                                if (_loadingMore)
                                  const DataRow(
                                    cells: [
                                      DataCell(Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.cyanAccent,
                                          ),
                                        ),
                                      )),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
