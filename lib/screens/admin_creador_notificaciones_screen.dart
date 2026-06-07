import 'package:flutter/material.dart';
import '../services/notificacion_service.dart';
import '../services/supabase_service.dart';

class AdminCreadorNotificacionesScreen extends StatefulWidget {
  const AdminCreadorNotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<AdminCreadorNotificacionesScreen> createState() => _AdminCreadorNotificacionesScreenState();
}

class _AdminCreadorNotificacionesScreenState extends State<AdminCreadorNotificacionesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  
  String _audiencia = 'todos'; // 'todos', 'capitanes', 'pescadores'
  IconData _iconoSeleccionado = Icons.info_outline;
  bool _enviando = false;

  final Map<String, IconData> _iconosDisponibles = {
    'Información': Icons.info_outline,
    'Alerta Importante': Icons.warning_amber_rounded,
    'Promoción': Icons.local_offer_outlined,
    'Novedad Náutica': Icons.sailing_rounded,
    'Sistema': Icons.settings_rounded,
  };

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviarNotificacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    try {
      // 1. Obtener los IDs de los usuarios objetivo directamente de la tabla maestra 'profiles'
      List<String> receptoresIds = [];
      final client = SupabaseService.supabase;
      
      if (_audiencia == 'todos') {
        final List<dynamic> res = await client
            .from('profiles')
            .select('user_id');
        receptoresIds.addAll(res.map((r) => r['user_id'].toString()));
      } else if (_audiencia == 'capitanes') {
        final List<dynamic> res = await client
            .from('profiles')
            .select('user_id')
            .eq('es_capitan', true);
        receptoresIds.addAll(res.map((r) => r['user_id'].toString()));
      } else if (_audiencia == 'pescadores') {
        final List<dynamic> res = await client
            .from('profiles')
            .select('user_id')
            .eq('es_capitan', false);
        receptoresIds.addAll(res.map((r) => r['user_id'].toString()));
      }

      // Evitar duplicados (por si un usuario tiene ambos roles o error de DB)
      receptoresIds = receptoresIds.toSet().toList();

      if (receptoresIds.isEmpty) {
        throw Exception('No se encontraron usuarios en la audiencia seleccionada.');
      }

      // 2. Preparar la notificación (el ID y el receptor_id lo pone el servicio)
      final templateDatos = {
        'tipo_actor': 'sistema',
        'categoria': 'informativa',
        'prioridad': 'informativa',
        'titulo': _tituloController.text.trim(),
        'contenido': _mensajeController.text.trim(),
        'leido': false,
        'payload': {
          'tipo': 'admin_broadcast',
          'ruta': null,
          'icono_codepoint': _iconoSeleccionado.codePoint,
        },
      };

      // 3. Enviar masivamente
      await NotificacionService().enviarNotificacionMasiva(receptoresIds, templateDatos);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación enviada con éxito'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volver al dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Redactar Publicación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Audiencia
              const Text('¿A quién va dirigido?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _audiencia,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos los usuarios (Capitanes y Pescadores)')),
                      DropdownMenuItem(value: 'capitanes', child: Text('Solo Capitanes')),
                      DropdownMenuItem(value: 'pescadores', child: Text('Solo Pescadores')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _audiencia = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Icono
              const Text('Selecciona el Ícono de la Notificación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _iconosDisponibles.entries.map((entry) {
                  final isSelected = _iconoSeleccionado == entry.value;
                  return ChoiceChip(
                    label: Icon(entry.value, color: isSelected ? Colors.white : const Color(0xFF0D47A1)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00E676),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? const Color(0xFF00E676) : Colors.grey.shade300),
                    onSelected: (selected) {
                      if (selected) setState(() => _iconoSeleccionado = entry.value);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Título
              const Text('Título', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  hintText: 'Ej. ¡Alerta Meteorológica!',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 24),

              // Mensaje
              const Text('Mensaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mensajeController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Escribe el detalle de la notificación aquí...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 40),

              // Botón Enviar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  onPressed: _enviando ? null : _enviarNotificacion,
                  icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded),
                  label: Text(_enviando ? 'Enviando...' : 'Publicar Notificación', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
