import 'package:flutter/material.dart';
import '../models/atributo.dart';
import '../models/rubro.dart';
import '../services/supabase_service.dart';

class AdminAtributosScreen extends StatefulWidget {
  const AdminAtributosScreen({super.key});

  @override
  State<AdminAtributosScreen> createState() => _AdminAtributosScreenState();
}

class _AdminAtributosScreenState extends State<AdminAtributosScreen> {
  List<Atributo> _atributos = [];
  List<Rubro> _rubros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      final results = await Future.wait<dynamic>([
        SupabaseService.supabase.from('atributos').select().order('nombre'),
        SupabaseService.getRubros(),
      ]);

      setState(() {
        _atributos = List<Atributo>.from(results[0].map((x) => Atributo.fromSupabase(x)));
        _rubros = results[1] as List<Rubro>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarFormulario({Atributo? atributo}) {
    final nombreController = TextEditingController(text: atributo?.nombre);
    final unidadController = TextEditingController(text: atributo?.unidad);
    String? selectedRubroId = atributo?.rubroId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(atributo == null ? 'Nuevo Atributo' : 'Editar Atributo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController, 
                  decoration: const InputDecoration(labelText: 'Nombre (ej: Rulemanes)', hintText: 'Nombre de la especificación'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unidadController, 
                  decoration: const InputDecoration(labelText: 'Unidad (ej: lbs, mts, kg)', hintText: 'Unidad de medida (opcional)'),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedRubroId,
                  decoration: const InputDecoration(labelText: 'Asignar a Rubro', border: OutlineInputBorder()),
                  hint: const Text('Seleccionar Rubro'),
                  items: _rubros.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.nombre),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedRubroId = val),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vincular un rubro ayuda a que este atributo aparezca automáticamente al cargar productos de ese tipo.',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) return;

                final data = {
                  'nombre': nombreController.text.trim(),
                  'unidad': unidadController.text.trim().isEmpty ? null : unidadController.text.trim(),
                  'rubro_id': selectedRubroId,
                };

                try {
                  if (atributo == null) {
                    await SupabaseService.supabase.from('atributos').insert(data);
                  } else {
                    await SupabaseService.supabase.from('atributos').update(data).eq('id', atributo.id);
                  }
                  Navigator.pop(context);
                  _cargarDatos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diccionario Técnico Master'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _atributos.length,
              itemBuilder: (context, index) {
                final attr = _atributos[index];
                final rubroName = _rubros.any((r) => r.id == attr.rubroId) 
                    ? _rubros.firstWhere((r) => r.id == attr.rubroId).nombre 
                    : 'Sin asignar';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: attr.rubroId != null ? Colors.green : Colors.grey, 
                      child: const Icon(Icons.settings_suggest, color: Colors.white, size: 20),
                    ),
                    title: Text(attr.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attr.unidad != null ? 'Unidad: ${attr.unidad}' : 'Sin unidad'),
                        Text('Rubro: $rubroName', style: TextStyle(color: attr.rubroId != null ? Colors.blue : Colors.grey, fontSize: 11)),
                      ],
                    ),
                    trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _mostrarFormulario(atributo: attr)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
