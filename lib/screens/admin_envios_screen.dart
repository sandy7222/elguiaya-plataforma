import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/safe_button.dart';

/// Módulo de Gestión de Envíos del Administrador.
/// Permite crear, editar y activar/desactivar servicios de transporte
/// con sus tarifas, que luego se aplican automáticamente al carrito.
class AdminEnviosScreen extends StatefulWidget {
  const AdminEnviosScreen({super.key});

  @override
  State<AdminEnviosScreen> createState() => _AdminEnviosScreenState();
}

class _AdminEnviosScreenState extends State<AdminEnviosScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _servicios = [];
  bool _isLoading = true;

  static const _verde = Color(0xFF00875A);
  static const _verdeClaro = Color(0xFFE3F9EE);
  static const _azul = Color(0xFF001F3F);

  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }

  // ─── CARGA DE DATOS ────────────────────────────────────────────────────────
  Future<void> _cargarServicios() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('envios_tarifas')
          .select()
          .order('nombre_servicio');
      setState(() {
        _servicios = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar servicios: $e');
    }
  }

  // ─── GUARDAR (CREAR O EDITAR) ───────────────────────────────────────────────
  Future<void> _guardarServicio({
    String? id,
    required String nombre,
    required String descripcion,
    required double tarifa,
    required bool activo,
  }) async {
    try {
      final payload = {
        'nombre_servicio': nombre.trim(),
        'descripcion': descripcion.trim(),
        'tarifa': tarifa,
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (id == null) {
        await _supabase.from('envios_tarifas').insert(payload);
        _mostrarExito('Servicio creado correctamente ✓');
      } else {
        await _supabase.from('envios_tarifas').update(payload).eq('id', id);
        _mostrarExito('Servicio actualizado correctamente ✓');
      }
      await _cargarServicios();
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    }
  }

  // ─── ACTIVAR / DESACTIVAR ───────────────────────────────────────────────────
  Future<void> _toggleActivo(String id, bool estadoActual) async {
    try {
      await _supabase
          .from('envios_tarifas')
          .update({'activo': !estadoActual})
          .eq('id', id);
      await _cargarServicios();
    } catch (e) {
      _mostrarError('Error al cambiar estado: $e');
    }
  }

  // ─── ELIMINAR ───────────────────────────────────────────────────────────────
  Future<void> _eliminarServicio(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminás el servicio "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase.from('envios_tarifas').delete().eq('id', id);
        _mostrarExito('Servicio eliminado');
        await _cargarServicios();
      } catch (e) {
        _mostrarError('Error al eliminar: $e');
      }
    }
  }

  // ─── DIALOG EDITOR ─────────────────────────────────────────────────────────
  void _abrirEditor({Map<String, dynamic>? servicio}) {
    final nombreCtrl = TextEditingController(text: servicio?['nombre_servicio'] ?? '');
    final descCtrl = TextEditingController(text: servicio?['descripcion'] ?? '');
    final tarifaCtrl = TextEditingController(
        text: servicio != null ? (servicio['tarifa'] as num).toStringAsFixed(0) : '');
    bool activo = servicio?['activo'] ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(servicio == null ? Icons.add_circle : Icons.edit,
                  color: _verde, size: 24),
              const SizedBox(width: 10),
              Text(
                servicio == null ? 'Nuevo Servicio de Envío' : 'Editar Servicio',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del servicio
                  TextField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Servicio *',
                      hintText: 'Ej: OCA, Andreani, Correo Argentino',
                      prefixIcon: const Icon(Icons.local_shipping, color: _verde),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _verde, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Descripción
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Entrega en 24-48hs hábiles, a todo el país',
                      prefixIcon: const Icon(Icons.info_outline, color: _verde),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _verde, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tarifa
                  TextField(
                    controller: tarifaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Tarifa (ARS) *',
                      hintText: 'Ej: 4500',
                      prefixIcon: const Icon(Icons.attach_money, color: _verde),
                      prefixText: '\$ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _verde, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle activo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: activo ? _verdeClaro : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: activo ? _verde.withOpacity(0.3) : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activo ? '✓ Activo (visible en el carrito)' : '✗ Inactivo (oculto)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: activo ? _verde : Colors.grey,
                          ),
                        ),
                        Switch(
                          value: activo,
                          activeColor: _verde,
                          onChanged: (v) => setDialogState(() => activo = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            SafeElevatedIconButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icons.save,
              iconSize: 18,
              label: 'Guardar',
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty || tarifaCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Nombre y tarifa son obligatorios.'),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _guardarServicio(
                  id: servicio?['id']?.toString(),
                  nombre: nombreCtrl.text,
                  descripcion: descCtrl.text,
                  tarifa: double.parse(tarifaCtrl.text),
                  activo: activo,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────
  void _mostrarExito(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _verde),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 22),
            SizedBox(width: 10),
            Text('Gestión de Envíos y Tarifas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarServicios,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(),
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Servicio', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _verde))
          : _servicios.isEmpty
              ? _buildEmptyState()
              : _buildLista(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text('No hay servicios de envío configurados',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tocá el botón verde para agregar tu primer servicio.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      children: [
        // Banner informativo
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _verdeClaro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _verde.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: _verde, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las tarifas activas se muestran como opciones de envío en el carrito del cliente y se suman automáticamente al total cobrado por Mercado Pago.',
                  style: TextStyle(color: _verde, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: _servicios.length,
            itemBuilder: (_, i) => _buildCard(_servicios[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> s) {
    final activo = s['activo'] as bool? ?? false;
    final tarifa = (s['tarifa'] as num?)?.toDouble() ?? 0;
    final nombre = s['nombre_servicio']?.toString() ?? '';
    final desc = s['descripcion']?.toString() ?? '';
    final id = s['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? _verde.withOpacity(0.4) : Colors.grey.shade200,
          width: activo ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activo ? _verdeClaro : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_shipping,
                      color: activo ? _verde : Colors.grey, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (desc.isNotEmpty)
                        Text(desc,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
                // Badge estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activo ? _verdeClaro : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activo ? '● ACTIVO' : '○ INACTIVO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activo ? _verde : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tarifa destacada
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tarifa de envío:',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    '\$ ${tarifa.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: _azul,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Acciones
            Row(
              children: [
                // Toggle activo/inactivo
                Expanded(
                  child: SafeOutlinedIconButton(
                    onPressed: () => _toggleActivo(id, activo),
                    icon: activo ? Icons.toggle_on : Icons.toggle_off,
                    iconColor: activo ? _verde : Colors.grey,
                    label: activo ? 'Desactivar' : 'Activar',
                    textStyle: TextStyle(color: activo ? _verde : Colors.grey),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: activo ? _verde : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Editar
                IconButton(
                  onPressed: () => _abrirEditor(servicio: s),
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF5E5CE6)),
                  tooltip: 'Editar',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEEEEFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                // Eliminar
                IconButton(
                  onPressed: () => _eliminarServicio(id, nombre),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Eliminar',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEEEE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
