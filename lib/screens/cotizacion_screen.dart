

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class CotizacionScreen extends StatefulWidget {
  const CotizacionScreen({super.key});

  @override
  State<CotizacionScreen> createState() => _CotizacionScreenState();
}

class _CotizacionScreenState extends State<CotizacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lugarController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  String? _provinciaSeleccionada;
  bool _isLoading = false;

  // Lista de provincias argentinas
  final List<String> _provincias = [
    'Buenos Aires', 'Catamarca', 'Chaco', 'Chubut', 'Cordoba', 'Corrientes',
    'Entre Rios', 'Formosa', 'Jujuy', 'La Pampa', 'La Rioja', 'Mendoza',
    'Misiones', 'Neuquen', 'Rio Negro', 'Salta', 'San Juan', 'San Luis',
    'Santa Cruz', 'Santa Fe', 'Santiago del Estero', 'Tierra del Fuego', 'Tucuman'
  ];

  @override
  void initState() {
    super.initState();
    _cargarProvinciaDelGuia();
  }

  Future<void> _cargarProvinciaDelGuia() async {
    try {
      // Obtenemos la provincia del perfil del guia actual
      final perfilGuia = await SupabaseService.obtenerPerfilGuiaActual();
      
      if (perfilGuia != null && perfilGuia['provincia'] != null) {
        setState(() {
          _provinciaSeleccionada = perfilGuia['provincia'];
        });
      } else {
        // Si no hay provincia, usamos un valor por defecto
        setState(() {
          _provinciaSeleccionada = 'Buenos Aires';
        });
      }
    } catch (e) {
      print('Error al cargar provincia del guia: $e');
      // En caso de error, usamos valor por defecto
      setState(() {
        _provinciaSeleccionada = 'Buenos Aires';
      });
    }
  }

  Future<void> _guardarCotizacion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Aqui iria la logica para guardar la cotizacion
      // Por ahora, solo mostramos un mensaje de exito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cotizacion guardada con exito!'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpiar formulario
      _lugarController.clear();
      _descripcionController.clear();
      _precioController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar cotizacion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'NUEVA COTIZACION',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 40,
                    color: Color(0xFF002366),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Crear Cotizacion',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002366),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Provincia del guia (autocompletada)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _provinciaSeleccionada,
                      decoration: InputDecoration(
                        labelText: 'Provincia del guia*',
                        prefixIcon: const Icon(Icons.location_on, color: Color(0xFF002366), size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      items: _provincias.map((provincia) {
                        return DropdownMenuItem(
                          value: provincia,
                          child: Text(provincia),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _provinciaSeleccionada = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecciona una provincia';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lugar del servicio
                  _buildTextField(
                    _lugarController,
                    'Lugar del servicio',
                    Icons.place,
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),

                  // Descripcion
                  _buildTextField(
                    _descripcionController,
                    'Descripcion del trabajo',
                    Icons.description,
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),

                  // Precio
                  _buildTextField(
                    _precioController,
                    'Precio estimado',
                    Icons.attach_money,
                    type: TextInputType.number,
                    isRequired: true,
                  ),
                  const SizedBox(height: 15),

                  // Boton de guardar
                  _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF002366))
                      : ElevatedButton(
                          onPressed: _guardarCotizacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002366),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'GUARDAR COTIZACION',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: type,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es obligatorio';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            prefixIcon: Icon(icon, color: const Color(0xFF002366), size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}
