import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/models/rubro.dart';
import 'package:capitanya_master/services/importacion_service.dart';
import 'package:capitanya_master/services/exportacion_service.dart';
import 'package:capitanya_master/services/exportacion_meta.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/utils/web_download.dart';
import 'package:capitanya_master/utils/seleccion_catalogo.dart';

class AdminImportacionScreen extends StatefulWidget {
  const AdminImportacionScreen({super.key});

  @override
  State<AdminImportacionScreen> createState() => _AdminImportacionScreenState();
}

class _AdminImportacionScreenState extends State<AdminImportacionScreen>
    with SingleTickerProviderStateMixin {
  // --- Colores ---
  static const Color _bgDark = Color(0xFF0A0E1A);
  static const Color _azul = Color(0xFF0D47A1);
  static const Color _azulClaro = Color(0xFF1565C0);
  static const Color _verde = Color(0xFF00E676);
  static const Color _rojo = Color(0xFFEF5350);
  static const Color _amarillo = Color(0xFFFFCA28);

  /// API local de automatización (n8n bridge). En emulador Android usar 10.0.2.2.
  static const String _apiLocalBase = String.fromEnvironment(
    'ELGUIAYA_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();

  // Estado importación
  List<ProductoImportado> _productosImportados = [];
  List<Rubro> _rubros = [];
  List<Categoria> _categorias = [];
  bool _cargando = false;
  bool _guardando = false;
  bool _procesandoUrl = false;
  bool _procesandoImagen = false;
  String? _imagenSeleccionadaNombre;
  Uint8List? _imagenSeleccionadaBytes;
  String _mensaje = '';
  bool _mensajeError = false;
  int _importadosOk = 0;

  /// El panel de fuentes se colapsa solo al cargar productos para dejar
  /// el máximo alto disponible a la lista editable.
  bool _panelFuentesAbierto = true;

  // Estado exportación
  List<Producto> _productosExportar = [];
  final Set<String> _seleccionados = {};
  bool _cargandoExport = false;

  // Exportación para Meta (catálogo de WhatsApp Business): marca y enlace base de cada producto. El Excel usa lo que se escriba acá;
  // la dirección automática (feed) usa los valores fijos de la función `feed-meta`.
  static const String _prefMarcaMeta = 'meta_marca';
  static const String _prefLinkMeta = 'meta_link_base';
  final TextEditingController _marcaMetaCtrl = TextEditingController(text: 'El Guía YA');
  final TextEditingController _linkMetaCtrl = TextEditingController(text: 'https://www.elguiaya.com/#/producto/');

  /// Dirección pública del feed de Meta (se arma desde la URL del proyecto de Supabase que ya usa la app).
  String get _urlFeedMeta {
    final base = Supabase.instance.client.rest.url; // https://<proyecto>.supabase.co/rest/v1
    return '${base.replaceFirst('/rest/v1', '')}/functions/v1/feed-meta';
  }

  Future<void> _cargarPreferenciasMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marca = prefs.getString(_prefMarcaMeta);
      final link = prefs.getString(_prefLinkMeta);
      if (marca != null && marca.trim().isNotEmpty) _marcaMetaCtrl.text = marca;
      if (link != null && link.trim().isNotEmpty) _linkMetaCtrl.text = link;
    } catch (_) {
      // Sin preferencias: quedan los valores por defecto.
    }
  }

  Future<void> _guardarPreferenciasMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMarcaMeta, _marcaMetaCtrl.text.trim());
      await prefs.setString(_prefLinkMeta, _linkMetaCtrl.text.trim());
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
    _cargarPreferenciasMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _marcaMetaCtrl.dispose();
    _linkMetaCtrl.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        SupabaseService.getRubros(),
        SupabaseService.getCategorias(),
      ]);
      setState(() {
        _rubros = results[0] as List<Rubro>;
        _categorias = results[1] as List<Categoria>;
      });
    } catch (_) {}
  }

  // ─── IMPORTAR desde Excel ML ───────────────────────────────────────────────
  Future<void> _subirExcelML() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() { _cargando = true; _mensaje = ''; _productosImportados = []; });
    try {
      final bytes = result.files.single.bytes!;
      final productos = ImportacionService.parsearExcelML(bytes);
      ImportacionService.asignarIdsDesdeNombres(productos, _rubros, _categorias);
      setState(() {
        _productosImportados = productos;
        _mensaje = '${productos.length} productos encontrados. Revisá la tabla y confirmá la importación.';
        _mensajeError = false;
        if (productos.isNotEmpty) _panelFuentesAbierto = false;
      });
    } catch (e) {
      setState(() { _mensaje = 'Error al leer Excel: $e'; _mensajeError = true; });
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ─── IMPORTAR desde JSON (n8n/Ollama) ─────────────────────────────────────
  Future<void> _subirJSON() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() { _cargando = true; _mensaje = ''; _productosImportados = []; });
    try {
      final jsonStr = utf8.decode(result.files.single.bytes!);
      final productos = ImportacionService.parsearJSON(jsonStr);
      ImportacionService.asignarIdsDesdeNombres(productos, _rubros, _categorias);
      setState(() {
        _productosImportados = productos;
        _mensaje = '${productos.length} productos cargados desde JSON.';
        _mensajeError = false;
        if (productos.isNotEmpty) _panelFuentesAbierto = false;
      });
    } catch (e) {
      setState(() { _mensaje = 'Error al leer JSON: $e'; _mensajeError = true; });
    } finally {
      setState(() => _cargando = false);
    }
  }

  /// Polling compartido Flujo A / Flujo B contra /ultimo-borrador.
  Future<String> _esperarBorradorN8n(double? mtimeAntes) async {
    const maxIntentos = 36; // ~3 min cada 5s
    for (var i = 0; i < maxIntentos; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) {
        throw Exception('Pantalla cerrada durante la espera del borrador.');
      }

      final poll = await http
          .get(Uri.parse('$_apiLocalBase/ultimo-borrador'))
          .timeout(const Duration(seconds: 15));
      if (poll.statusCode != 200) continue;

      final pollJson =
          jsonDecode(utf8.decode(poll.bodyBytes)) as Map<String, dynamic>;
      if (pollJson['existe'] != true) {
        setState(() {
          _mensaje = 'Esperando borrador... (${i + 1}/$maxIntentos)';
        });
        continue;
      }

      final mtime = (pollJson['mtime'] as num?)?.toDouble();
      final listo = mtimeAntes == null
          ? true
          : (mtime != null && mtime > mtimeAntes + 0.01);

      if (!listo) {
        setState(() {
          _mensaje = 'n8n sigue procesando... (${i + 1}/$maxIntentos)';
        });
        continue;
      }

      final contenido = pollJson['contenido']?.toString();
      if (contenido != null && contenido.trim().isNotEmpty) {
        return contenido;
      }
    }
    throw Exception(
      'Timeout esperando borrador_flujoA.json. Revisá Executions en n8n y que la API/Ollama estén arriba.',
    );
  }

  Future<void> _aplicarBorradorImportacion(String contenido) async {
    final productos = ImportacionService.parsearJSON(contenido);
    ImportacionService.asignarIdsDesdeNombres(productos, _rubros, _categorias);
    setState(() {
      _productosImportados = productos;
      _mensaje =
          '${productos.length} producto(s) listos desde n8n. Revisá y confirmá la importación.';
      _mensajeError = false;
      if (productos.isNotEmpty) _panelFuentesAbierto = false;
    });
  }

  // ─── PROCESAR URL vía n8n (API local bridge) ───────────────────────────────
  Future<void> _procesarUrlN8n() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _mensaje = 'Pegá una URL de AliExpress / 1688.';
        _mensajeError = true;
      });
      return;
    }

    setState(() {
      _procesandoUrl = true;
      _cargando = true;
      _mensaje = 'Disparando Flujo A en n8n...';
      _mensajeError = false;
      _productosImportados = [];
    });

    try {
      final disparo = await http
          .post(
            Uri.parse('$_apiLocalBase/disparar-flujo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 30));

      if (disparo.statusCode < 200 || disparo.statusCode >= 300) {
        throw Exception('API ${disparo.statusCode}: ${disparo.body}');
      }

      final disparoJson = jsonDecode(disparo.body) as Map<String, dynamic>;
      final mtimeAntes = (disparoJson['mtime_antes'] as num?)?.toDouble();

      setState(() {
        _mensaje =
            'Flujo iniciado. Esperando borrador (puede tardar 1–2 min)...';
      });

      final contenido = await _esperarBorradorN8n(mtimeAntes);
      await _aplicarBorradorImportacion(contenido);
    } catch (e) {
      setState(() {
        _mensaje = 'Error procesando URL: $e';
        _mensajeError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesandoUrl = false;
          _cargando = false;
        });
      }
    }
  }

  // ─── PROCESAR IMAGEN vía n8n (Flujo B) ─────────────────────────────────────
  Future<void> _seleccionarImagenOnce() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _imagenSeleccionadaBytes = result.files.single.bytes;
      _imagenSeleccionadaNombre = result.files.single.name;
      _mensaje = 'Imagen lista: ${result.files.single.name}';
      _mensajeError = false;
    });
  }

  Future<void> _procesarImagenN8n() async {
    final bytes = _imagenSeleccionadaBytes;
    final nombre = _imagenSeleccionadaNombre;
    if (bytes == null || nombre == null || nombre.isEmpty) {
      setState(() {
        _mensaje = 'Seleccioná una imagen antes de procesar.';
        _mensajeError = true;
      });
      return;
    }

    setState(() {
      _procesandoImagen = true;
      _cargando = true;
      _mensaje = 'Subiendo imagen y disparando Flujo B en n8n...';
      _mensajeError = false;
      _productosImportados = [];
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiLocalBase/subir-imagen-once'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('archivo', bytes, filename: nombre),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final body = utf8.decode(resp.bodyBytes);
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (resp.statusCode < 200 ||
          resp.statusCode >= 300 ||
          json['ok'] != true) {
        throw Exception(json['error']?.toString() ?? 'API ${resp.statusCode}: $body');
      }

      final mtimeAntes = (json['mtime_antes'] as num?)?.toDouble();
      setState(() {
        _mensaje =
            'Flujo B iniciado. Esperando borrador (puede tardar 1–2 min)...';
      });

      final contenido = await _esperarBorradorN8n(mtimeAntes);
      await _aplicarBorradorImportacion(contenido);
    } catch (e) {
      setState(() {
        _mensaje = 'Error procesando imagen: $e';
        _mensajeError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesandoImagen = false;
          _cargando = false;
        });
      }
    }
  }

  // ─── CONFIRMAR IMPORTACIÓN ─────────────────────────────────────────────────
  Future<void> _confirmarImportacion() async {
    final validos = _productosImportados.where((p) => p.esValido).toList();
    if (validos.isEmpty) {
      setState(() { _mensaje = 'No hay productos válidos para importar.'; _mensajeError = true; });
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Confirmar Importación', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se importarán ${validos.length} productos válidos al catálogo.\n'
          '${_productosImportados.length - validos.length} productos con errores serán omitidos.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _verde),
            child: const Text('Importar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() { _guardando = true; _importadosOk = 0; _mensaje = 'Importando...'; });

    int ok = 0;
    int err = 0;
    for (final p in validos) {
      try {
        final producto = Producto(
          id: '',
          nombre: p.nombre,
          descripcion: p.descripcion,
          precio: p.precio,
          stock: p.stock,
          rubro: p.rubro,
          categoriaId: p.categoriaId ?? '',
          imagenUrl: p.imagenUrl,
          videoUrl: p.videoUrl,
          activo: p.activo,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          destacado: false,
          rubroId: p.rubroId,
        );
        await SupabaseService.guardarProducto(producto);
        ok++;
        if (mounted) setState(() { _importadosOk = ok; _mensaje = 'Importando... ($ok/${validos.length})'; });
      } catch (_) { err++; }
    }

    setState(() {
      _guardando = false;
      _mensaje = '✅ Importación completa: $ok productos guardados${err > 0 ? ', $err con error' : ''}.';
      _mensajeError = err > 0 && ok == 0;
      _productosImportados = [];
    });
  }

  // ─── CARGAR PRODUCTOS PARA EXPORTAR ───────────────────────────────────────
  Future<void> _cargarProductosExportar() async {
    setState(() => _cargandoExport = true);
    try {
      _productosExportar = await SupabaseService.getProductos(forceRefresh: true);
      setState(() {});
    } finally {
      setState(() => _cargandoExport = false);
    }
  }

  Future<void> _exportarExcelML() async {
    final lista = _seleccionados.isEmpty
        ? _productosExportar
        : _productosExportar.where((p) => _seleccionados.contains(p.id)).toList();

    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos para exportar')));
      return;
    }

    try {
      final bytes = ExportacionService.generarExcelML(lista);
      if (kIsWeb) {
        _downloadBytes(bytes, 'catalogo_elguiaya.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Excel generado con ${lista.length} productos')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Excel para el catálogo de Meta (WhatsApp Business): columnas del feed de Meta, con las imágenes como enlaces.
  Future<void> _exportarMeta() async {
    final lista = _seleccionados.isEmpty
        ? _productosExportar
        : _productosExportar.where((p) => _seleccionados.contains(p.id)).toList();

    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos para exportar')));
      return;
    }

    try {
      await _guardarPreferenciasMeta();
      final marca = _marcaMetaCtrl.text.trim().isEmpty ? 'El Guía YA' : _marcaMetaCtrl.text.trim();
      final linkBase = _linkMetaCtrl.text.trim().isEmpty ? 'https://www.elguiaya.com/#/producto/' : _linkMetaCtrl.text.trim();
      final r = ExportacionMeta.generarExcel(lista, marca: marca, urlProducto: linkBase);
      if (kIsWeb) {
        _downloadBytes(r.bytes, 'catalogo_meta_whatsapp.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Excel para Meta generado con ${lista.length} productos')));
      if (r.avisos.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Revisá antes de subir (${r.avisos.length})'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: r.avisos.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(a))).toList(),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportarJSON() async {
    final lista = _seleccionados.isEmpty
        ? _productosExportar
        : _productosExportar.where((p) => _seleccionados.contains(p.id)).toList();

    if (lista.isEmpty) return;

    final json = ExportacionService.generarJSON(lista);
    _downloadBytes(utf8.encode(json), 'catalogo_elguiaya.json', 'application/json');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ JSON generado con ${lista.length} productos')));
  }

  void _downloadBytes(List<int> bytes, String filename, String mimeType) {
    if (!kIsWeb) return;
    downloadFileOnWeb(bytes, filename, mimeType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _azul,
        toolbarHeight: 46,
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Importación / Exportación',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _verde,
          labelColor: _verde,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          tabs: const [
            Tab(height: 38, child: _TabLabel(Icons.download_rounded, 'IMPORTAR')),
            Tab(height: 38, child: _TabLabel(Icons.upload_rounded, 'EXPORTAR')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImportarTab(),
          _buildExportarTab(),
        ],
      ),
    );
  }

  // ─── TAB IMPORTAR ──────────────────────────────────────────────────────────
  Widget _buildImportarTab() {
    final ancho = MediaQuery.of(context).size.width;
    return Column(
      children: [
        _buildBarraEstado(ancho),
        if (_panelFuentesAbierto) _buildPanelFuentes(dosColumnas: ancho >= 1080),
        Expanded(
          child: _productosImportados.isEmpty
              ? _buildEmptyImport()
              : _buildTablaEditable(),
        ),
      ],
    );
  }

  /// Barra fija de una línea: toggle del panel, último mensaje y acciones.
  Widget _buildBarraEstado(double ancho) {
    final hayProductos = _productosImportados.isNotEmpty;
    final validos = _productosImportados.where((p) => p.esValido).length;
    final errores = _productosImportados.length - validos;

    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(
                () => _panelFuentesAbierto = !_panelFuentesAbierto),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _panelFuentesAbierto
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _panelFuentesAbierto ? 'Ocultar fuentes' : 'Fuentes de datos',
                    style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (_mensaje.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _mensaje,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: _mensajeError ? _rojo : _verde, fontSize: 12),
                ),
              ),
            )
          else
            const Spacer(),
          if (hayProductos && ancho >= 820) ...[
            _buildChip('Total: ${_productosImportados.length}', Colors.white54),
            const SizedBox(width: 6),
            _buildChip('✅ $validos', _verde),
            const SizedBox(width: 6),
            _buildChip('❌ $errores', _rojo),
            const SizedBox(width: 10),
          ],
          if (hayProductos)
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _confirmarImportacion,
                icon: _guardando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.cloud_upload_rounded, size: 15),
                label: Text(_guardando ? 'Importando...' : 'Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanelFuentes({required bool dosColumnas}) {
    final bloqueUrl = _buildBloqueUrl();
    final bloqueImagen = _buildBloqueImagen();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      color: const Color(0xFF111827),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildBotonCarga(
                icon: Icons.table_chart_rounded,
                label: 'Excel de MercadoLibre',
                sublabel: '.xlsx',
                color: const Color(0xFF1565C0),
                onTap: _subirExcelML,
                loading: _cargando,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildBotonCarga(
                icon: Icons.data_object_rounded,
                label: 'JSON de n8n / Ollama',
                sublabel: '.json',
                color: const Color(0xFF6B21A8),
                onTap: _subirJSON,
                loading: _cargando,
              )),
            ],
          ),
          const SizedBox(height: 10),
          if (dosColumnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: bloqueUrl),
                const SizedBox(width: 14),
                Expanded(child: bloqueImagen),
              ],
            )
          else ...[
            bloqueUrl,
            const SizedBox(height: 10),
            bloqueImagen,
          ],
        ],
      ),
    );
  }

  Widget _buildBloqueUrl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Procesar URL (Flujo A / n8n)',
            style: GoogleFonts.inter(
                color: Colors.white60, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                enabled: !_procesandoUrl && !_cargando,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://es.aliexpress.com/item/....html',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0A0E1A),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _azulClaro),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: (_procesandoUrl || _procesandoImagen || _cargando)
                    ? null
                    : _procesarUrlN8n,
                icon: _procesandoUrl
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_procesandoUrl ? 'Procesando...' : 'Procesar URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.black,
                  textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBloqueImagen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Procesar Imagen (Flujo B / n8n)',
            style: GoogleFonts.inter(
                color: Colors.white60, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: (_procesandoUrl || _procesandoImagen || _cargando)
                      ? null
                      : _seleccionarImagenOnce,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: Text(
                    _imagenSeleccionadaNombre ?? 'Elegir imagen…',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: (_procesandoUrl || _procesandoImagen || _cargando)
                    ? null
                    : _procesarImagenN8n,
                icon: _procesandoImagen
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label:
                    Text(_procesandoImagen ? 'Procesando...' : 'Procesar Imagen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotonCarga({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(sublabel, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyImport() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.white12),
          const SizedBox(height: 12),
          Text('Subí un archivo Excel de MercadoLibre\no un JSON generado por tu agente IA',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Los productos aparecerán aquí para que puedas revisarlos\nantes de confirmar la importación.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white12, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTablaEditable() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _productosImportados.length,
      itemBuilder: (ctx, i) {
        final p = _productosImportados[i];
        final tieneError = !p.esValido;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: tieneError ? _rojo.withOpacity(0.08) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tieneError ? _rojo.withOpacity(0.4) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: ExpansionTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: tieneError ? _rojo.withOpacity(0.2) : _verde.withOpacity(0.15),
              child: Icon(
                tieneError ? Icons.error_outline : Icons.check_circle_outline,
                color: tieneError ? _rojo : _verde,
                size: 16,
              ),
            ),
            title: Text(p.nombre,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            subtitle: Row(
              children: [
                _miniChip('\$${p.precio.toStringAsFixed(0)}', _amarillo),
                const SizedBox(width: 6),
                _miniChip('Stock: ${p.stock}', Colors.lightBlue),
                const SizedBox(width: 6),
                _miniChip(p.rubro, Colors.purple[200]!),
                if (tieneError) ...[
                  const SizedBox(width: 6),
                  _miniChip(p.errores.first, _rojo),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    _campoEditable('Nombre', p.nombre, (v) {
                      setState(() { _productosImportados[i].nombre = v; _productosImportados[i].validar(); });
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _campoEditable('Precio', p.precio.toString(), (v) {
                          setState(() { _productosImportados[i].precio = double.tryParse(v) ?? 0; _productosImportados[i].validar(); });
                        }, tipo: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _campoEditable('Stock', p.stock.toString(), (v) {
                          setState(() { _productosImportados[i].stock = int.tryParse(v) ?? 0; _productosImportados[i].validar(); });
                        }, tipo: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _dropdownRubro(i, p)),
                        const SizedBox(width: 8),
                        Expanded(child: _dropdownCategoria(i, p)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _campoEditable('URL de Imagen (opcional)', p.imagenUrl, (v) {
                      setState(() { _productosImportados[i].imagenUrl = v; });
                    }),
                    if (p.referenciaML != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Ref. MercadoLibre: ${p.referenciaML}',
                            style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _campoEditable(String label, String value, Function(String) onChanged, {TextInputType tipo = TextInputType.text}) {
    return TextFormField(
      initialValue: value,
      keyboardType: tipo,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _verde.withOpacity(0.5))),
      ),
      onChanged: onChanged,
    );
  }

  Widget _dropdownRubro(int i, ProductoImportado p) {
    return DropdownButtonFormField<String>(
      value: _rubros.any((r) => r.nombre == p.rubro) ? p.rubro : null,
      dropdownColor: const Color(0xFF1A2035),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Rubro',
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      items: _rubros.map((r) => DropdownMenuItem(
        value: r.nombre,
        child: Text(r.nombre, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
      )).toList(),
      onChanged: (v) {
        if (v == null) return;
        final rubro = _rubros.firstWhere((r) => r.nombre == v);
        setState(() {
          _productosImportados[i].rubro = v;
          _productosImportados[i].rubroId = rubro.id;
        });
      },
    );
  }

  Widget _dropdownCategoria(int i, ProductoImportado p) {
    return DropdownButtonFormField<String>(
      value: _categorias.any((c) => c.id == p.categoriaId) ? p.categoriaId : null,
      dropdownColor: const Color(0xFF1A2035),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Categoría',
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      items: _categorias.map((c) => DropdownMenuItem(
        value: c.id,
        child: Text(c.nombre, style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: (v) => setState(() => _productosImportados[i].categoriaId = v),
    );
  }

  // ─── TAB EXPORTAR ──────────────────────────────────────────────────────────
  Widget _buildExportarTab() {
    return Column(
      children: [
        // El panel de arriba es desplazable y no pasa de la mitad de la pantalla: en pantallas chicas no desborda y la lista sigue visible.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: SingleChildScrollView(
            child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF111827),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exportar catálogo',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _cargarProductosExportar,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Cargar catálogo'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _azulClaro, foregroundColor: Colors.white),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _productosExportar.isEmpty ? null : _exportarExcelML,
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Excel ML'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _productosExportar.isEmpty ? null : _exportarJSON,
                    icon: const Icon(Icons.data_object_rounded, size: 16),
                    label: const Text('JSON / n8n'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B21A8), foregroundColor: Colors.white),
                  )),
                ],
              ),
              const SizedBox(height: 14),
              Text('Catálogo de Meta (WhatsApp Business)',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _marcaMetaCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Marca', isDense: true, labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _linkMetaCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                          labelText: 'Enlace base del producto (se le suma el id)', isDense: true, labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _productosExportar.isEmpty ? null : _exportarMeta,
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('Excel Meta / WhatsApp Business (con imágenes)'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E), foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF128C7E).withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sincronización automática con Meta',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'En Commerce Manager (Catálogo → Fuentes de datos → Feed de datos) elegí cargar desde una dirección y pegá esta, '
                      'con lectura diaria. Meta vuelve a leer los precios y el stock solo. Solo se publican productos activos y con imagen.',
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: SelectableText(_urlFeedMeta, style: GoogleFonts.inter(color: _verde, fontSize: 11))),
                        IconButton(
                          tooltip: 'Copiar dirección',
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _urlFeedMeta));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dirección copiada')));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_productosExportar.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        // Seleccionar todos (tres estados: todos, ninguno o algunos).
                        tristate: true,
                        value: SeleccionCatalogo.estado(_seleccionados, _productosExportar.map((p) => p.id).toList()),
                        activeColor: _verde,
                        checkColor: Colors.black,
                        onChanged: (_) => setState(() {
                          final nuevo = SeleccionCatalogo.alternarTodos(_seleccionados, _productosExportar.map((p) => p.id).toList());
                          _seleccionados
                            ..clear()
                            ..addAll(nuevo);
                        }),
                      ),
                      Expanded(
                        child: Text(
                          _seleccionados.isEmpty
                              ? 'Seleccionar todos (sin selección se exporta todo el catálogo: ${_productosExportar.length})'
                              : '${SeleccionCatalogo.cantidadAExportar(_seleccionados, _productosExportar.map((p) => p.id).toList())} de ${_productosExportar.length} productos seleccionados',
                          style: GoogleFonts.inter(color: _seleccionados.isEmpty ? Colors.white60 : _verde, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
            ),
          ),
        ),
        Expanded(
          child: _cargandoExport
              ? const Center(child: CircularProgressIndicator())
              : _productosExportar.isEmpty
                  ? Center(child: Text('Presioná "Cargar catálogo" para ver tus productos',
                        style: GoogleFonts.inter(color: Colors.white24)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _productosExportar.length,
                      itemBuilder: (ctx, i) {
                        final p = _productosExportar[i];
                        final selec = _seleccionados.contains(p.id);
                        return CheckboxListTile(
                          value: selec,
                          onChanged: (v) => setState(() {
                            if (v == true) _seleccionados.add(p.id);
                            else _seleccionados.remove(p.id);
                          }),
                          activeColor: _verde,
                          checkColor: Colors.black,
                          tileColor: selec ? _verde.withOpacity(0.06) : Colors.white.withOpacity(0.03),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          title: Text(p.nombre,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text('\$${p.precio.toStringAsFixed(0)} · Stock: ${p.stock} · ${p.rubro}',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                          secondary: p.imagenUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(p.imagenUrl, width: 36, height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 24)),
                                )
                              : const Icon(Icons.inventory_2_outlined, color: Colors.white24),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.icon, this.texto);

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }
}



