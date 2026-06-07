import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class AdminComisionistasScreen extends StatefulWidget {
  const AdminComisionistasScreen({super.key});

  @override
  State<AdminComisionistasScreen> createState() => _AdminComisionistasScreenState();
}

class _AdminComisionistasScreenState extends State<AdminComisionistasScreen> with SingleTickerProviderStateMixin {
  late TabController _internalTabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers para el formulario
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _mpController = TextEditingController();
  final _codigoController = TextEditingController();

  List<Map<String, dynamic>> _comisionistas = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Variables para edición
  Map<String, dynamic>? _comisionistaEnEdicion;

  @override
  void initState() {
    super.initState();
    _internalTabController = TabController(length: 2, vsync: this);
    _cargarComisionistas();
  }

  @override
  void dispose() {
    _internalTabController.dispose();
    _nombreController.dispose();
    _dniController.dispose();
    _mpController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  /// 📥 Carga los comisionistas desde la base de datos o fallback
  Future<void> _cargarComisionistas() async {
    setState(() => _isLoading = true);
    try {
      final list = await SupabaseService.getComisionistas();
      setState(() {
        _comisionistas = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarSnackBar('Error al cargar comisionistas: $e', Colors.redAccent);
    }
  }

  /// 🎲 Genera un código alfanumérico único basado en el nombre
  void _generarCodigoAutomatico() {
    final nombre = _nombreController.text.trim();
    String prefix = 'PROM';
    
    if (nombre.isNotEmpty) {
      // Tomar las primeras letras del nombre/apellido limpiando espacios
      final limpia = nombre.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      if (limpia.length >= 4) {
        prefix = limpia.substring(0, 4);
      } else {
        prefix = limpia;
      }
    }
    
    // Generar 4 números aleatorios
    final random = Random();
    final numero = 1000 + random.nextInt(9000); // Entre 1000 y 9999
    
    setState(() {
      _codigoController.text = '$prefix$numero';
    });
    
    _mostrarSnackBar('Código generado automáticamente: $prefix$numero', Colors.cyanAccent);
  }

  /// 💾 Guarda el comisionista nuevo o editado
  Future<void> _guardarComisionista() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final comisionistaData = {
      'nombre': _nombreController.text.trim(),
      'dni': _dniController.text.trim(),
      'cuenta_mp': _mpController.text.trim(),
      'codigo_comision': _codigoController.text.trim().toUpperCase(),
      'estado': 'activo',
    };

    try {
      await SupabaseService.guardarComisionista(comisionistaData);
      
      // Limpiar formulario
      _nombreController.clear();
      _dniController.clear();
      _mpController.clear();
      _codigoController.clear();
      
      _mostrarSnackBar('Comisionista registrado con éxito', const Color(0xFF00E676));
      await _cargarComisionistas();
      
      // Ir a la pestaña del listado
      _internalTabController.animateTo(1);
    } catch (e) {
      _mostrarSnackBar(e.toString().replaceAll('Exception:', '').trim(), Colors.redAccent);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// ✏️ Inicia el proceso de edición abriendo un diálogo Glassmorphic
  void _editarComisionista(Map<String, dynamic> comisionista) {
    setState(() {
      _comisionistaEnEdicion = comisionista;
    });

    final nombreEditController = TextEditingController(text: comisionista['nombre']);
    final dniEditController = TextEditingController(text: comisionista['dni']);
    final mpEditController = TextEditingController(text: comisionista['cuenta_mp']);
    final codigoEditController = TextEditingController(text: comisionista['codigo_comision']);
    final String codigoOriginal = comisionista['codigo_comision'];
    String estadoSeleccionado = comisionista['estado'] ?? 'activo';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF001A33).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
            ),
            title: Row(
              children: const [
                Icon(Icons.edit_rounded, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text(
                  'EDITAR PROMOTOR',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nombreEditController, 'Nombre y Apellido', Icons.person),
                  const SizedBox(height: 12),
                  _buildDialogTextField(dniEditController, 'DNI', Icons.badge_outlined, isNumeric: true),
                  const SizedBox(height: 12),
                  _buildDialogTextField(mpEditController, 'Cuenta MP (Email/CVU)', Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 12),
                  _buildDialogTextField(codigoEditController, 'Código Único', Icons.qr_code_scanner_outlined, isUppercase: true),
                  const SizedBox(height: 16),
                  
                  // Estado dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estado en Plataforma:',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButton<String>(
                          value: estadoSeleccionado,
                          dropdownColor: const Color(0xFF001A33),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'activo', child: Text('ACTIVO', style: TextStyle(color: Color(0xFF00E676)))),
                            DropdownMenuItem(value: 'pausado', child: Text('PAUSADO', style: TextStyle(color: Colors.orangeAccent))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                estadoSeleccionado = val;
                              });
                            }
                          },
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  
                  final nuevosDatos = {
                    'nombre': nombreEditController.text.trim(),
                    'dni': dniEditController.text.trim(),
                    'cuenta_mp': mpEditController.text.trim(),
                    'codigo_comision': codigoEditController.text.trim().toUpperCase(),
                    'estado': estadoSeleccionado,
                  };

                  try {
                    await SupabaseService.actualizarComisionista(codigoOriginal, nuevosDatos);
                    _mostrarSnackBar('Promotor actualizado correctamente', const Color(0xFF00E676));
                    await _cargarComisionistas();
                  } catch (e) {
                    _mostrarSnackBar(e.toString().replaceAll('Exception:', '').trim(), Colors.redAccent);
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔄 Cambia rápido el estado de Activo/Pausado desde la lista
  Future<void> _toggleEstadoComisionista(Map<String, dynamic> comisionista) async {
    final String codigo = comisionista['codigo_comision'];
    final String estadoActual = comisionista['estado'] ?? 'activo';
    final String nuevoEstado = estadoActual == 'activo' ? 'pausado' : 'activo';

    setState(() => _isLoading = true);
    try {
      await SupabaseService.cambiarEstadoComisionista(codigo, nuevoEstado);
      _mostrarSnackBar(
        'Promotor ${comisionista['nombre']} está ahora $nuevoEstado',
        nuevoEstado == 'activo' ? const Color(0xFF00E676) : Colors.orangeAccent,
      );
      await _cargarComisionistas();
    } catch (e) {
      _mostrarSnackBar('Error al actualizar estado: $e', Colors.redAccent);
      setState(() => _isLoading = false);
    }
  }

  /// 📋 Copia el código al portapapeles y avisa al admin
  void _copiarCodigoAlPortapapeles(String codigo) {
    Clipboard.setData(ClipboardData(text: codigo));
    _mostrarSnackBar('¡Código "$codigo" copiado al portapapeles!', Colors.cyanAccent);
  }

  /// 📱 Muestra un Snackbar flotante con estilo Glassmorphic
  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == const Color(0xFF00E676) 
                  ? Icons.check_circle_outline_rounded 
                  : color == Colors.cyanAccent 
                      ? Icons.copy_all_rounded 
                      : Icons.warning_amber_rounded,
              color: Colors.black87,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de Pestañas Interno estilo Glassmorphic
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: TabBar(
            controller: _internalTabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.cyanAccent.withOpacity(0.3), Colors.cyanAccent.withOpacity(0.05)],
              ),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
            ),
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
            tabs: const [
              Tab(
                height: 45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('REGISTRAR'),
                  ],
                ),
              ),
              Tab(
                height: 45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('PROMOTORES'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Contenido de las pestañas
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                )
              : TabBarView(
                  controller: _internalTabController,
                  children: [
                    // Pestaña 1: Formulario de Carga
                    _buildFormularioTab(),
                    // Pestaña 2: Listado de Vendedores
                    _buildListadoTab(),
                  ],
                ),
        ),
      ],
    );
  }

  /// 📝 Construye el Formulario con estilo Glassmorphic
  Widget _buildFormularioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Información
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CÓDIGO ALFANUMÉRICO ÚNICO',
                          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Este código vinculará automáticamente a Pescadores y Capitanes que lo ingresen al registrarse, asignando sus comisiones (Match 80/20) en tiempo real.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Fields
            _buildModernField(
              controller: _nombreController,
              label: 'Nombre y Apellido Completo',
              icon: Icons.person_rounded,
              validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre del promotor' : null,
            ),
            const SizedBox(height: 16),
            
            _buildModernField(
              controller: _dniController,
              label: 'Documento Nacional de Identidad (DNI)',
              icon: Icons.badge_outlined,
              isNumeric: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingresa el DNI';
                if (int.tryParse(val) == null) return 'El DNI debe ser numérico';
                if (val.trim().length < 7 || val.trim().length > 9) return 'DNI inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildModernField(
              controller: _mpController,
              label: 'Cuenta de Mercado Pago (Email o CVU/CBU)',
              icon: Icons.account_balance_wallet_outlined,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingresa la cuenta de cobro';
                if (val.contains('@') && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Código con botón generador integrado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildModernField(
                    controller: _codigoController,
                    label: 'Código Promocional Único',
                    icon: Icons.qr_code_scanner_outlined,
                    isUppercase: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Genera o ingresa un código';
                      if (val.trim().length < 4) return 'Mínimo 4 caracteres';
                      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(val.trim().toUpperCase())) {
                        return 'Solo letras y números';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _generarCodigoAutomatico,
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('GENERAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarComisionista,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.save_rounded, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'REGISTRAR PROMOTOR EN SISTEMA',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 👥 Pestaña del Listado
  Widget _buildListadoTab() {
    if (_comisionistas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No hay promotores registrados',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Crea uno en la pestaña REGISTRAR.',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Si hay espacio suficiente, mostrar grilla responsiva
        final int columns = constraints.maxWidth > 800 ? 2 : 1;
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: _comisionistas.length,
          itemBuilder: (context, index) {
            final com = _comisionistas[index];
            return _buildPromotorCard(com);
          },
        );
      },
    );
  }

  /// 🎴 Tarjeta del Promotor
  Widget _buildPromotorCard(Map<String, dynamic> com) {
    final String estado = com['estado'] ?? 'activo';
    final bool esActivo = estado == 'activo';
    final String codigo = com['codigo_comision'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esActivo ? Colors.white10 : Colors.orangeAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Orbe de fondo tenue para promotores activos
          if (esActivo)
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.08),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Nombre y Badge de Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        com['nombre'] ?? 'Sin Nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: esActivo ? const Color(0xFF00E676).withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: esActivo ? const Color(0xFF00E676).withOpacity(0.5) : Colors.orangeAccent.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        estado.toUpperCase(),
                        style: TextStyle(
                          color: esActivo ? const Color(0xFF00E676) : Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),

                // Info: DNI y Cuenta MP
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoRow(Icons.badge_outlined, 'DNI: ${com['dni'] ?? ""}'),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.account_balance_wallet_outlined, 'MP: ${com['cuenta_mp'] ?? ""}'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),

                // Fila Inferior: Código Alfanumérico y Botones
                Row(
                  children: [
                    // Código Promocional
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded, color: Colors.cyanAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            codigo,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Copiar
                    _buildCompactActionBtn(
                      Icons.copy_all_rounded,
                      'Copiar',
                      Colors.cyanAccent,
                      () => _copiarCodigoAlPortapapeles(codigo),
                    ),
                    const Spacer(),

                    // Pausar/Activar
                    _buildCompactActionBtn(
                      esActivo ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      esActivo ? 'Pausar' : 'Activar',
                      esActivo ? Colors.orangeAccent : const Color(0xFF00E676),
                      () => _toggleEstadoComisionista(com),
                    ),
                    const SizedBox(width: 8),

                    // Editar
                    _buildCompactActionBtn(
                      Icons.edit_rounded,
                      'Editar',
                      Colors.white70,
                      () => _editarComisionista(com),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ℹ️ Fila simple de información de la tarjeta
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// ⚙️ Botón de acción compacto para la tarjeta
  Widget _buildCompactActionBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(icon, color: color, size: 18),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  /// 🏷️ Campo de texto personalizado con estética Glassmorphic
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumeric = false,
    bool isUppercase = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (isNumeric) FilteringTextInputFormatter.digitsOnly,
        if (isUppercase) UpperCaseTextFormatter(),
      ],
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.8), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 🏷️ Campo de texto para el Diálogo de Edición
  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumeric = false,
    bool isUppercase = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (isNumeric) FilteringTextInputFormatter.digitsOnly,
        if (isUppercase) UpperCaseTextFormatter(),
      ],
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.8), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// 🔠 Formateador de texto que fuerza mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
