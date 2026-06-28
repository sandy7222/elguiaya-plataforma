import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/services/storage_service.dart';
import 'package:capitanya_master/utils/cya_styles.dart';
import 'dart:ui' as ui;
import '../widgets/safe_button.dart';

class PortalCapitanSuspendidoScreen extends StatefulWidget {
  const PortalCapitanSuspendidoScreen({super.key});

  @override
  State<PortalCapitanSuspendidoScreen> createState() => _PortalCapitanSuspendidoScreenState();
}

class _PortalCapitanSuspendidoScreenState extends State<PortalCapitanSuspendidoScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  String _estado = 'suspendido';
  String _motivoSuspension = 'Cuenta suspendida para revisión de credenciales.';
  String _capitanId = '';
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _cargarDatosSuspension();
  }

  Future<void> _cargarDatosSuspension() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _capitanId = user.id;
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('estado, motivo_suspension')
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            _estado = profile['estado'] ?? 'suspendido';
            _motivoSuspension = profile['motivo_suspension'] ?? 'Cuenta suspendida temporalmente por administración.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando datos de suspensión: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFecha(String? dateStr) {
    if (dateStr == null) return 'No declarada';
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _subirArchivo() async {
    final bool esDeuda = _motivoSuspension.toLowerCase().contains('deuda');
    if (esDeuda) {
      await _procesarSubidaComprobanteDeuda();
      return;
    }
    await _mostrarDialogoDeclararDocumento();
  }

  Future<void> _procesarSubidaComprobanteDeuda() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
      });

      final url = await StorageService.uploadAdminDocument(
        file: pickedFile,
        folder: _capitanId,
        prefix: 'comprobante_deuda',
      );

      if (url != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'estado': 'en_revision',
              'motivo_suspension': 'Verificación de transferencia de comisiones en proceso.',
            })
            .eq('user_id', _capitanId);

        if (mounted) {
          setState(() {
            _estado = 'en_revision';
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Comprobante subido con éxito! Su cuenta está ahora en revisión.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error en carga de archivo deuda: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir archivo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _mostrarDialogoDeclararDocumento() async {
    String tipoDocumento = 'seguro';
    DateTime fechaVencimiento = DateTime.now().add(const Duration(days: 365));
    File? imagenSeleccionada;
    bool subiendoEnDialog = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedDate = '${fechaVencimiento.day.toString().padLeft(2, '0')}/${fechaVencimiento.month.toString().padLeft(2, '0')}/${fechaVencimiento.year}';
            
            return AlertDialog(
              backgroundColor: const Color(0xFF001220),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: const Color(0xFFFFA000).withOpacity(0.3), width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.document_scanner_rounded, color: Color(0xFFFFA000), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Actualizar Credencial',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Declará el tipo de documento y su nueva fecha de vencimiento antes de subir la foto:',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    
                    const Text('¿Qué credencial estás renovando?', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tipoDocumento,
                          dropdownColor: const Color(0xFF001220),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFA000)),
                          items: const [
                            DropdownMenuItem(value: 'seguro', child: Text('Seguro de Embarcación')),
                            DropdownMenuItem(value: 'carnet', child: Text('Carnet de Timonel / Licencia')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                tipoDocumento = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    const Text('Fecha de Vencimiento del documento:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaVencimiento,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFFFFA000),
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF001220),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            fechaVencimiento = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFFFFA000), size: 16),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text('Foto de la credencial:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    imagenSeleccionada == null
                        ? SafeOutlinedIconButton(
  onPressed: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 70,
                              );
                              if (file != null) {
                                setDialogState(() {
                                  imagenSeleccionada = File(file.path);
                                });
                              }
                            },
  icon: Icons.camera_alt,
  iconColor: const Color(0xFFFFA000),
  label: 'TOMAR FOTO',
  textStyle: TextStyle(color: Colors.white70),
  style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFFFFA000).withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 45),
                            ),
)
                        : Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                              image: DecorationImage(
                                image: FileImage(imagenSeleccionada!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black.withOpacity(0.8),
                                    radius: 16,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                      onPressed: () {
                                        setDialogState(() {
                                          imagenSeleccionada = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: subiendoEnDialog ? null : () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: (imagenSeleccionada == null || subiendoEnDialog)
                      ? null
                      : () async {
                          setDialogState(() {
                            subiendoEnDialog = true;
                          });
                          
                          final bool exito = await _subirYGuardarCredencial(
                            tipo: tipoDocumento,
                            fecha: fechaVencimiento,
                            file: XFile(imagenSeleccionada!.path),
                          );
                          
                          if (mounted) {
                            Navigator.pop(context);
                            if (exito) {
                              setState(() {
                                _estado = 'en_revision';
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: subiendoEnDialog
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('ENVIAR A REVISIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _subirYGuardarCredencial({
    required String tipo,
    required DateTime fecha,
    required XFile file,
  }) async {
    try {
      setState(() {
        _isUploading = true;
      });

      final url = await StorageService.uploadAdminDocument(
        file: file,
        folder: _capitanId,
        prefix: tipo,
      );

      if (url == null) throw Exception('Error al subir la imagen al almacenamiento.');

      await Supabase.instance.client
          .from('profiles')
          .update({
            '${tipo}_url': url,
            'vencimiento_$tipo': fecha.toIso8601String(),
            'estado': 'en_revision',
            'motivo_suspension': tipo == 'seguro'
                ? 'Revisión de nueva credencial de Seguro de Embarcación.'
                : 'Revisión de nuevo Carnet de Timonel.',
          })
          .eq('user_id', _capitanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Documento enviado a revisión con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Error actualizando credencial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _contactarSoporte() async {
    final String text = Uri.encodeComponent(
      "Hola Sebastián, quiero regularizar mi cuenta de Capitán [ID: $_capitanId].",
    );
    final Uri url = Uri.parse("https://wa.me/5491130000000?text=$text"); 
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('⚠️ Error abriendo enlace de WhatsApp: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Soporte Técnico'),
            content: Text('Comunicate al +54 9 11 3000-0000 con el mensaje:\n\n"Hola Sebastián, quiero regularizar mi cuenta de Capitán [$_capitanId]"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDIDO'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/bienvenida', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String motivoLower = _motivoSuspension.toLowerCase();
    final bool esDeuda = motivoLower.contains('deuda');
    final bool esDocumento = motivoLower.contains('documento') ||
                             motivoLower.contains('credencial') ||
                             motivoLower.contains('vence') ||
                             motivoLower.contains('vencid') ||
                             motivoLower.contains('seguro') ||
                             motivoLower.contains('carnet') ||
                             motivoLower.contains('licencia') ||
                             motivoLower.contains('revisión') ||
                             motivoLower.contains('revision') ||
                             !esDeuda;

    return Scaffold(
      backgroundColor: const Color(0xFF000814), 
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8F00).withOpacity(0.15), 
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF3D00).withOpacity(0.12), 
              ),
            ),
          ),
          
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFA000)))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.03),
                              border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.4), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFA000).withOpacity(0.1),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFFA000),
                              size: 72,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'CUENTA PAUSADA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Centro de Regularización de Cuenta',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        
                        const SizedBox(height: 32),

                        _estado == 'en_revision'
                            ? _buildEnRevisionWidget()
                            : _buildSuspensionCard(esDeuda, esDocumento),

                        const SizedBox(height: 32),

                        _buildActionButton(),
                        
                        const SizedBox(height: 16),
                        
                        SafeTextIconButton(
  onPressed: _cerrarSesion,
  icon: Icons.exit_to_app,
  iconColor: Colors.white60,
  label: 'Cerrar Sesión',
  textStyle: TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600),
),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSuspensionCard(bool esDeuda, bool esDocumento) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motivo de Suspensión:',
                style: TextStyle(
                  color: Color(0xFFFFA000),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _motivoSuspension,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              if (esDeuda) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 20),
                const Text(
                  'Datos de Pago de la Plataforma:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Banco:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Text('Banco Patagonia', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CBU / CVU:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Text('0000003100000000000000', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Titular:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Text('EL GUIA YA S.R.L.', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Concepto:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Text('Pago Comisión', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnRevisionWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853).withOpacity(0.04), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C853).withOpacity(0.15),
                ),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00C853),
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Recibido!',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Estamos verificando tus datos para reactivarte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El equipo de administración responderá a la brevedad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_estado == 'en_revision') {
      return CYAStyles.primaryButton(
        label: 'CONTACTAR A SOPORTE',
        onPressed: _contactarSoporte,
        icon: Icons.chat_bubble_outline_rounded,
        gradientColors: const [Color(0xFF00C853), Color(0xFF69F0AE)], 
      );
    }

    final String motivoLower = _motivoSuspension.toLowerCase();
    final bool esDeuda = motivoLower.contains('deuda');
    final bool esDocumento = motivoLower.contains('documento') ||
                             motivoLower.contains('credencial') ||
                             motivoLower.contains('vence') ||
                             motivoLower.contains('vencid') ||
                             motivoLower.contains('seguro') ||
                             motivoLower.contains('carnet') ||
                             motivoLower.contains('licencia') ||
                             motivoLower.contains('revisión') ||
                             motivoLower.contains('revision') ||
                             !esDeuda;

    return Column(
      children: [
        if (esDocumento)
          CYAStyles.primaryButton(
            label: _isUploading ? 'SUBIENDO...' : 'SUBIR NUEVA FOTO',
            onPressed: _isUploading ? null : _subirArchivo,
            icon: Icons.camera_alt_outlined,
            isLoading: _isUploading,
            gradientColors: const [Color(0xFFFFA000), Color(0xFFFFB300)], 
          ),
        if (esDeuda)
          CYAStyles.primaryButton(
            label: _isUploading ? 'SUBIENDO...' : 'SUBIR COMPROBANTE',
            onPressed: _isUploading ? null : _subirArchivo,
            icon: Icons.upload_file_outlined,
            isLoading: _isUploading,
            gradientColors: const [Color(0xFFFFA000), Color(0xFFFFB300)], 
          ),
        const SizedBox(height: 16),
        CYAStyles.primaryButton(
          label: 'CONTACTAR A SOPORTE',
          onPressed: _contactarSoporte,
          icon: Icons.chat_bubble_outline_rounded,
          gradientColors: const [Color(0xFF00C853), Color(0xFF69F0AE)], 
        ),
      ],
    );
  }
}
