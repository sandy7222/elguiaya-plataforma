import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/safe_button.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/viaje_lifecycle_service.dart';
import '../models/pique_pulse.dart';
import '../widgets/calificacion_tag_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmarFinalizacionScreen extends StatefulWidget {
  const ConfirmarFinalizacionScreen({super.key});

  @override
  State<ConfirmarFinalizacionScreen> createState() => _ConfirmarFinalizacionScreenState();
}

class _ConfirmarFinalizacionScreenState extends State<ConfirmarFinalizacionScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _viajesListos = [];
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  
  // ID del pescador autenticado � usa el usuario actual de Supabase
  String get _pescadorId =>
      Supabase.instance.client.auth.currentUser?.id ??
      SupabaseService.currentUserId ??
      ''; // Si es vacío, los métodos fallarán con gracia
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  // static const Color _rojoProblema = Color(0xFFEF4444);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarViajes();
    _iniciarActualizacionAutomatica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actualizacionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarViajes();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarViajes();
      }
    });
  }

  Future<void> _cargarViajes() async {
    try {
      setState(() => _isLoading = true);
      
      // Obtener viajes listos para confirmacion
      final viajes = await SupabaseService.getViajesListosConfirmacion(_pescadorId);
      
      setState(() {
        _viajesListos = viajes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar viajes: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarViajeExitoso(String pedidoId) async {
    try {
      // 1. Mostrar estado de verificación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Verificando ubicación satelital GPS...'),
            ],
          ),
          backgroundColor: _azulNautico,
          duration: Duration(seconds: 2),
        ),
      );

      // 2. Verificar permisos de geolocalización
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception('Se requieren permisos de ubicación para verificar la finalización del viaje.');
      }

      // 3. Capturar ubicación en tiempo real del pescador
      Position pescadorPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      Map<String, double> coordenadasPescador = {
        'lat': pescadorPos.latitude,
        'lon': pescadorPos.longitude,
      };

      // 4. Obtener coordenadas del capitán y puerto de destino
      final coordenadasVerificacion = await SupabaseService.obtenerCoordenadasVerificacion(pedidoId);
      final coordenadasCapitan = coordenadasVerificacion['capitan']!;
      final coordenadasPuertoDestino = coordenadasVerificacion['puerto']!;

      // 5. Confirmar viaje con par�metros de geofencing
      final resultado = await SupabaseService.confirmarViajeExitoso(
        pedidoId,
        _pescadorId,
        coordenadasCapitan: coordenadasCapitan,
        coordenadasPescador: coordenadasPescador,
        coordenadasPuertoDestino: coordenadasPuertoDestino,
      );
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('? �Viaje confirmado exitosamente!')),
              backgroundColor: _verdeExito,
            ),
          );
          _cargarViajes(); // Recargar lista
        } else {
          final String errorTipo = resultado['error_tipo'] ?? '';
          Color snackColor = Colors.red;
          IconData icon = Icons.error_outline;
          
          if (errorTipo == 'POSIBLE_FRAUDE_GPS') {
            snackColor = _naranjaAlerta;
            icon = Icons.warning_amber_rounded;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${resultado['mensaje']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: snackColor,
              duration: const Duration(seconds: 6),
            ),
          );
          _cargarViajes(); // Recargar para mostrar estado actualizado
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al confirmar viaje: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoCalificacion(Map<String, dynamic> viaje) {
    final descripcion = (viaje['descripcion'] as String? ?? '').toLowerCase();
    final esTraslado = descripcion.contains('traslado') ||
        descripcion.contains('transporte') ||
        descripcion.contains('cruce') ||
        descripcion.contains('isla');
    final tipoServicio = esTraslado ? 'Transporte/Traslado' : 'Guía de Pesca';
    final etiquetasDisponibles = esTraslado
        ? ['Puntualidad en Cruce', 'Puntualidad en Retiro', 'Viaje Seguro/Tranquilo', 'Buena Comunicación']
        : ['Buena Embarcación', 'Puntual', 'Conoce los Pozos de Pesca', 'Atento/Asesoró bien'];

    int rating = 5;
    final Set<String> selectedTags = {};
    final commentController = TextEditingController();
    bool isSaving = false;

    // --- Nuevos estados para información de pesca ---
    XFile? capturaFoto;
    final especieController = TextEditingController();
    final pesoController = TextEditingController();
    bool permitirPublicarBlog = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85), // Fondo oscuro
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.anchor, color: Color(0xFF00E5FF), size: 28),
                              SizedBox(width: 10),
                              Text(
                                'Califica tu Experiencia',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Por favor, califica al Capitán del viaje.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Fila de anclas interactiva
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final anchorValue = index + 1;
                              final isSelected = anchorValue <= rating;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    rating = anchorValue;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Icon(
                                      Icons.anchor,
                                      size: 38,
                                      color: isSelected
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),
                          
                          // Badge de Servicio Detectado
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2F45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  esTraslado ? Icons.local_shipping_outlined : Icons.phishing_outlined,
                                  color: const Color(0xFF00E5FF),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Servicio: $tipoServicio',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Chips r�pidos
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: etiquetasDisponibles.map((tag) {
                              final isSelected = selectedTags.contains(tag);
                              return CalificacionTagChip(
                                label: tag,
                                selected: isSelected,
                                accentColor: const Color(0xFF00E5FF),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedTags.add(tag);
                                    } else {
                                      selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          
                          // Input de comentarios
                          TextField(
                            controller: commentController,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Cu�ntanos más sobre el viaje (opcional)...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                              fillColor: Colors.white.withOpacity(0.04),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Sección Detalles de Pesca (Blog de Piques & Gu-IA)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.phishing, color: Color(0xFF00E5FF), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Detalles de tu Jornada de Pesca',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Especie y Peso
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: especieController,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Especie (ej. Dorado, Surub�)',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                                          fillColor: Colors.white.withOpacity(0.03),
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: pesoController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Peso en KG (ej. 15.5)',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                                          fillColor: Colors.white.withOpacity(0.03),
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Subida de Fotos
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await StorageService.pickImageFromGallery();
                                          if (picked != null) {
                                            setDialogState(() {
                                              capturaFoto = picked;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                capturaFoto != null ? Icons.check_circle : Icons.image,
                                                color: capturaFoto != null ? Colors.greenAccent : const Color(0xFF00E5FF),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                capturaFoto != null ? 'Foto Cargada' : 'Galer�a',
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await StorageService.captureImageFromCamera();
                                          if (picked != null) {
                                            setDialogState(() {
                                              capturaFoto = picked;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.camera_alt, color: Color(0xFF00E5FF), size: 18),
                                              SizedBox(width: 6),
                                              Text(
                                                'C�mara',
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (capturaFoto != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Imagen: ${capturaFoto!.name}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Divider(color: Colors.white.withOpacity(0.08)),
                                // Switch de consentimiento
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '�Compartir en el Blog de Piques?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Publicar� tu reseña, fotos y especie de forma pública en la sección de Comunidad de la tienda.',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.4),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: permitirPublicarBlog,
                                      activeColor: const Color(0xFF00E5FF),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          permitirPublicarBlog = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Botones de acci�n
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSaving ? null : () => Navigator.pop(context),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          isSaving = true;
                                        });
                                        try {
                                          String? fotoUrl;
                                          if (permitirPublicarBlog && capturaFoto != null) {
                                            fotoUrl = await StorageService.uploadXFile(
                                              xFile: capturaFoto!,
                                              bucket: 'fotos_perfil',
                                              folderPath: 'capturas_viajes/${viaje['id']}',
                                              fileNamePrefix: 'captura',
                                            );
                                          }

                                          double lat = 0.0;
                                          double lon = 0.0;
                                          if (permitirPublicarBlog) {
                                            try {
                                              Position? currentPos;
                                              LocationPermission perm = await Geolocator.checkPermission();
                                              if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
                                                currentPos = await Geolocator.getCurrentPosition(
                                                  desiredAccuracy: LocationAccuracy.medium,
                                                  timeLimit: const Duration(seconds: 5),
                                                );
                                              }
                                              lat = currentPos?.latitude ?? 0.0;
                                              lon = currentPos?.longitude ?? 0.0;
                                            } catch (locErr) {
                                              print('?? Error al obtener ubicación para coordenadas: $locErr');
                                            }
                                          }

                                          final aspectos = {
                                            'etiquetas': selectedTags.toList(),
                                            'permitir_publicar_blog': permitirPublicarBlog,
                                            'especie_capturada': especieController.text.trim().isEmpty ? null : especieController.text.trim(),
                                            'peso_captura': double.tryParse(pesoController.text.trim()),
                                            'fotos_capturas': fotoUrl != null ? [fotoUrl] : [],
                                            'latitud': lat != 0.0 ? lat : null,
                                            'longitud': lon != 0.0 ? lon : null,
                                          };

                                          // 1. Guardar calificación
                                          await SupabaseService.crearCalificacionViaje(
                                            pedidoId: viaje['id'],
                                            calificadorId: _pescadorId,
                                            capitanCalificadoId: viaje['capitan_id'] ?? '',
                                            calificacion: rating,
                                            comentario: commentController.text.trim(),
                                            aspectosPuntuados: aspectos,
                                          );

                                          // 2. Si dio su consentimiento y el GPS está activo, registrar en PiquePulse local
                                          if (permitirPublicarBlog) {
                                            try {
                                              final box = await Hive.openBox<PiquePulse>('guia_piques');
                                              final pulse = PiquePulse(
                                                id: DateTime.now().microsecondsSinceEpoch.toString(),
                                                timestamp: DateTime.now(),
                                                latitud: lat,
                                                longitud: lon,
                                                tipoActivacion: 'foto_calificacion',
                                                especieDetectada: especieController.text.trim().isEmpty ? 'Desconocido' : especieController.text.trim(),
                                              );
                                              await box.add(pulse);
                                              print('? PiquePulse guardado en Hive box: guia_piques');
                                            } catch (hiveErr) {
                                              print('?? Error al registrar PiquePulse local: $hiveErr');
                                            }
                                          }

                                          if (context.mounted) {
                                            Navigator.pop(context); // Cerrar diálogo
                                            // 2. Confirmar viaje utilizando el m�todo de la pantalla
                                            await _confirmarViajeExitoso(viaje['id']);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            setDialogState(() {
                                              isSaving = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Center(child: Text('Error al calificar o confirmar: $e')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5FF),
                                  foregroundColor: const Color(0xFF0F172A),
                                  elevation: 4,
                                  shadowColor: const Color(0xFF00E5FF).withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                        ),
                                      )
                                    : const Text(
                                        'Guardar Calificación',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _reportarProblema(String pedidoId, String descripcion) async {
    final motivosDisputa = [
      'El capitán/pescador no se presentó',
      'Problema mecánico en la embarcación',
      'Incumplimiento de lo pactado',
      'Maltrato o falta de seguridad',
    ];
    
    String motivoSeleccionado = motivosDisputa.first;
    final descargoController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85), // Fondo oscuro
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header con icono de alerta
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 28),
                              SizedBox(width: 10),
                              Text(
                                'Reportar Disputa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Detalla el inconveniente para iniciar la retención del pago.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Dropdown para seleccionar el motivo
                          const Text(
                            'Motivo del reporte:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: motivoSeleccionado,
                                dropdownColor: const Color(0xFF1E293B),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFB300)),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                isExpanded: true,
                                items: motivosDisputa.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: isSaving ? null : (newValue) {
                                  if (newValue != null) {
                                    setDialogState(() {
                                      motivoSeleccionado = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Textfield para el descargo
                          const Text(
                            'Descargo detallado (Obligatorio):',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: descargoController,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe detalladamente lo sucedido...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                              fillColor: Colors.white.withOpacity(0.04),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFB300)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Banner informativo de bloqueo
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lock_outline, color: Color(0xFFFFB300), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'El saldo del viaje quedará bloqueado de forma preventiva en el sistema y en Mercado Pago hasta su resolución por administración.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFFFFB300).withOpacity(0.85),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Botones de acci�n
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSaving ? null : () => Navigator.pop(context),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final descargo = descargoController.text.trim();
                                        if (descargo.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Center(child: Text('El descargo detallado es obligatorio')),
                                              backgroundColor: Color(0xFFFFB300),
                                            ),
                                          );
                                          return;
                                        }

                                        setDialogState(() {
                                          isSaving = true;
                                        });

                                        try {
                                          final resultado = await SupabaseService.iniciarDisputaViaje(
                                            viajeId: pedidoId,
                                            reclamanteId: _pescadorId,
                                            motivo: motivoSeleccionado,
                                            descargo: descargo,
                                          );

                                          if (context.mounted) {
                                            Navigator.pop(context); // Cerrar diálogo
                                            if (resultado['exito'] == true) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Center(child: Text('?? Disputa iniciada. Fondos retenidos.')),
                                                  backgroundColor: Color(0xFFFFB300),
                                                ),
                                              );
                                              _cargarViajes(); // Recargar lista
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Center(child: Text('Error: ${resultado['mensaje']}')),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            setDialogState(() {
                                              isSaving = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Center(child: Text('Error al iniciar disputa: $e')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB300),
                                  foregroundColor: const Color(0xFF0F172A),
                                  elevation: 4,
                                  shadowColor: const Color(0xFFFFB300).withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                        ),
                                      )
                                    : const Text(
                                        'Enviar Reporte',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Confirmar Finalizacion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarViajes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viajesListos.isEmpty
              ? _buildEstadoVacio()
              : Column(
                  children: [
                    // Header de informacion
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _azulNautico,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Viajes Listos para Confirmar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Estos viajes han pasado su fecha pactada y estan listos para tu confirmacion.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tu confirmacion es importante para que el capitan reciba su pago.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de viajes
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _viajesListos.length,
                        itemBuilder: (context, index) {
                          final viaje = _viajesListos[index];
                          return _buildViajeCard(viaje);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _azulNautico.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay viajes listos para confirmar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando tus viajes pasen la fecha pactada,\napareceran aqui para confirmar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SafeElevatedIconButton(
            onPressed: _cargarViajes,
            icon: Icons.refresh,
            label: 'Verificar Nuevamente',
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final diasDesdePactada = viaje['dias_desde_pactada'] as int? ?? 0;
    final monto = (viaje['total'] as num?)?.toDouble() ?? 0.0;
    final descripcion = viaje['descripcion'] as String? ?? 'Viaje sin descripcion';
    final fechaPactada = viaje['fecha_pactada'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del viaje
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _azulNautico.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sailing, color: _azulNautico, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Fecha pactada: ${_formatFecha(fechaPactada)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (diasDesdePactada > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _naranjaAlerta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+$diasDesdePactada dias',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Monto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto del viaje:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _azulNautico,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botones de accion
            Row(
              children: [
                Expanded(
                  child: SafeElevatedIconButton(
                    onPressed: () => _mostrarDialogoCalificacion(viaje),
                    icon: Icons.check_circle,
                    label: 'Viaje Exitoso',
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verdeExito,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SafeOutlinedIconButton(
                    onPressed: () => _reportarProblema(viaje['id'], descripcion),
                    icon: Icons.warning,
                    label: 'Reportar Problema',
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _naranjaAlerta,
                      side: const BorderSide(color: _naranjaAlerta),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(String fechaString) {
    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (e) {
      return fechaString;
    }
  }
}

// Importar Timer para actualizacion automatica
