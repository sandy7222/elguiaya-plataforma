import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:capitanya_master/services/storage_service.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import '../services/despacho_pna_service.dart';
import '../widgets/safe_button.dart';
import '../utils/fecha_nacimiento_utils.dart';

/// Formulario de Declaración de Pasajeros.
/// El titular aparece pre-cargado. Con el botón [+] se agregan invitados.
/// Cada pasajero requiere: Nombre, Apellido, DNI, foto del DNI (opcional) y Talle de Chaleco.
class FormularioPasajerosScreen extends StatefulWidget {
  final String pedidoId;
  final String nombreTitular;
  final String apellidoTitular;
  final String dniTitular;

  const FormularioPasajerosScreen({
    super.key,
    required this.pedidoId,
    required this.nombreTitular,
    required this.apellidoTitular,
    required this.dniTitular,
  });

  @override
  State<FormularioPasajerosScreen> createState() =>
      _FormularioPasajerosScreenState();
}

class _FormularioPasajerosScreenState
    extends State<FormularioPasajerosScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  bool _guardando = false;

  static const _azul = Color(0xFF001F3F);
  static const _azulClaro = Color(0xFFE8F5FF);
  static const _verde = Color(0xFF00875A);

  // Lista de pasajeros — el primero es siempre el titular
  final List<_PasajeroForm> _pasajeros = [];

  @override
  void initState() {
    super.initState();
    // Pre-cargar al titular
    _pasajeros.add(_PasajeroForm(
      nombre: widget.nombreTitular,
      apellido: widget.apellidoTitular,
      dni: widget.dniTitular,
      esTitular: true,
    ));
    _cargarDatosTitular();
  }

  Future<void> _cargarDatosTitular() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('telefono, email, avatar_url')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          final p = _pasajeros[0];
          p.telefonoCtrl.text = profile['telefono']?.toString() ?? '';
          p.emailCtrl.text = profile['email']?.toString() ?? user.email ?? '';
          p.avatarUrl = profile['avatar_url']?.toString();
        });
      }
    } catch (e) {
      print('⚠️ Error al cargar perfil del titular: $e');
    }
  }

  @override
  void dispose() {
    for (final p in _pasajeros) {
      p.dispose();
    }
    super.dispose();
  }

  // ─── Agregar invitado ──────────────────────────────────────────────────────
  void _agregarInvitado() {
    setState(() {
      // Contraer anteriores para mantener el formulario ordenado
      for (var p in _pasajeros) {
        p.expandido = false;
      }
      _pasajeros.add(_PasajeroForm(esTitular: false, expandido: true));
    });
  }

  // ─── Eliminar invitado ─────────────────────────────────────────────────────
  void _eliminarInvitado(int index) {
    if (index == 0) return; // no eliminar al titular
    setState(() {
      _pasajeros[index].dispose();
      _pasajeros.removeAt(index);
    });
  }

  // ─── Seleccionar foto DNI ──────────────────────────────────────────────────
  Future<void> _seleccionarFoto(int index) async {
    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Foto del DNI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _azul),
              title: const Text('Tomar foto con la cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _azul),
              title: const Text('Elegir desde la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (opcion == null) return;

    final picked = await _picker.pickImage(
      source: opcion,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      setState(() => _pasajeros[index].xFile = picked);
    }
  }

  // ─── Validar formulario ────────────────────────────────────────────────────
  bool _validar() {
    for (int i = 0; i < _pasajeros.length; i++) {
      final p = _pasajeros[i];
      if (p.nombreCtrl.text.trim().isEmpty ||
          p.apellidoCtrl.text.trim().isEmpty ||
          p.dniCtrl.text.trim().isEmpty ||
          p.fechaNacimiento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ Completá todos los campos del ${i == 0 ? "titular" : "invitado $i"} (incluida fecha de nacimiento)'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return false;
      }

      if (p.esTitular) {
        if (p.emergenciaCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Por favor, ingresá un teléfono de emergencia obligatorio para el Titular.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return false;
        }
        if (p.emergenciaCtrl.text.trim() == p.telefonoCtrl.text.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ El teléfono de emergencia del Titular debe ser DIFERENTE al suyo.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return false;
        }
      } else {
        if (p.telefonoCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Por favor, completá el teléfono de contacto del invitado $i.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  // ─── Guardar en Supabase ───────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_validar()) return;
    setState(() => _guardando = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      for (int i = 0; i < _pasajeros.length; i++) {
        final p = _pasajeros[i];
        
        setState(() {
          p.subiendo = true;
          p.error = null;
          p.exito = false;
        });

        try {
          String? fotoUrl;

          // Subir foto del DNI si existe (Seguro para Web y Mobile)
          if (p.xFile != null) {
            fotoUrl = await StorageService.uploadXFile(
              xFile: p.xFile!,
              bucket: 'documentacion_privada',
              folderPath: '$userId/${widget.pedidoId}',
              fileNamePrefix: p.dniCtrl.text.trim(),
            );
          }

          // Serializar datos adicionales en el apellido para máxima compatibilidad y cero migraciones de DB
          String apellidoConInfo;
          if (p.esTitular) {
            // Titular: "Apellido (Emergencia: Tel_Emergencia, Email: Correo, Tel: Telefono)"
            apellidoConInfo = '${p.apellidoCtrl.text.trim()} (Emergencia: ${p.emergenciaCtrl.text.trim()}, Email: ${p.emailCtrl.text.trim()}, Tel: ${p.telefonoCtrl.text.trim()})';
          } else {
            // Invitado: "Apellido (Tel: Tel_Contacto)"
            apellidoConInfo = '${p.apellidoCtrl.text.trim()} (Tel: ${p.telefonoCtrl.text.trim()})';
          }

          // Insertar pasajero (insert, no upsert — no hay constraint único)
          await _supabase.from('viajes_invitados').insert({
            'pescador_id': userId,
            'pedido_id': widget.pedidoId,
            'nombre': p.nombreCtrl.text.trim(),
            'apellido': apellidoConInfo,
            'dni': int.tryParse(p.dniCtrl.text.trim()) ?? 0,
            'fecha_nacimiento': FechaNacimientoUtils.toIsoDate(p.fechaNacimiento),
            'es_titular': p.esTitular,
            'foto_dni_url': fotoUrl,
          });

          // Actualizar perfil del titular en Supabase para persistencia
          if (p.esTitular) {
            try {
              await _supabase.from('profiles').update({
                'nombre': '${p.nombreCtrl.text.trim()} ${p.apellidoCtrl.text.trim()}'.trim(),
                'dni': int.tryParse(p.dniCtrl.text.trim()) ?? 0,
                'telefono': p.telefonoCtrl.text.trim(),
              }).eq('user_id', userId);
            } catch (errProfile) {
              print('⚠️ Error al actualizar perfil del titular: $errProfile');
            }
          }

          setState(() {
            p.subiendo = false;
            p.exito = true;
          });
        } catch (err) {
          // 🔍 LOG DIAGNÓSTICO — ver error real en consola
          print('❌ [PASAJEROS] Error guardando pasajero $i: $err');
          setState(() {
            p.subiendo = false;
            // Mensaje amigable: nunca mostrar el error técnico al usuario
            p.error = 'No se pudo guardar este pasajero. Revisá los datos e intentá de nuevo.';
          });
          rethrow;
        }
      }

      if (mounted) {
        await SupabaseService.guardarPescadorSnapshotEnPedido(widget.pedidoId);
        try {
          await DespachoPnaService.notificarCapitanDocumentacion(
            pedidoId: widget.pedidoId,
            escenario: 'manifiesto_actualizado',
          );
        } catch (e) {
          print('⚠️ [PASAJEROS] Aviso despacho PNA al capitán: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Pasajeros guardados. El despacho PNA del capitán quedó precargado '
              '(imprimir, firmar y presentar en Prefectura).',
            ),
            backgroundColor: _verde,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true); // true = guardado exitoso
      }
    } catch (e) {
      // 🔍 LOG DIAGNÓSTICO — error real
      print('❌ [PASAJEROS] Error general: $e');
      if (mounted) {
        // Mostrar error técnico temporalmente para diagnóstico
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ─── Seleccionar fecha de nacimiento ───────────────────────────────────────
  Future<void> _seleccionarFechaNacimiento(int index) async {
    final p = _pasajeros[index];
    final fecha = await showDatePicker(
      context: context,
      initialDate: p.fechaNacimiento ??
          DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 120)),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
    );
    if (fecha != null && mounted) {
      setState(() => p.fechaNacimiento = fecha);
    }
  }

  Widget _buildFechaNacimientoTile(_PasajeroForm p, int index) {
    final label = p.fechaNacimiento == null
        ? 'Seleccionar fecha de nacimiento *'
        : FechaNacimientoUtils.formatearLegible(p.fechaNacimiento);
    return InkWell(
      onTap: () => _seleccionarFechaNacimiento(index),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha de nacimiento *',
          labelStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.cake_outlined, color: _azul, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: p.fechaNacimiento == null
                      ? Colors.grey.shade500
                      : Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 18, color: _azul),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Declaración de Pasajeros',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            SafeTextIconButton(
  onPressed: _guardar,
  icon: Icons.save,
  iconSize: 18,
  iconColor: Colors.white,
  label: 'GUARDAR',
  textStyle: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF8E1),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Por normativa de Prefectura, todos los tripulantes deben declararse con DNI y talle de chaleco salvavidas.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.brown, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          // Lista de pasajeros
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pasajeros.length + 1, // +1 para el botón [+]
              itemBuilder: (_, i) {
                if (i == _pasajeros.length) {
                  return _buildBotonAgregar();
                }
                return _buildTarjetaPasajero(i);
              },
            ),
          ),
        ],
      ),
      // Botón guardar flotante
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: SafeButtonLoadingContent(
                loading: _guardando,
                icon: Icons.check_circle_outline,
                idleLabel:
                    'Confirmar ${_pasajeros.length} pasajero${_pasajeros.length != 1 ? "s" : ""}',
                loadingLabel: 'Procesando carga...',
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                spinnerColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tarjeta de cada pasajero ──────────────────────────────────────────────
  Widget _buildTarjetaPasajero(int index) {
    final p = _pasajeros[index];
    final esTitular = p.esTitular;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esTitular
              ? _azul.withOpacity(0.4)
              : (p.error != null ? Colors.redAccent.withOpacity(0.5) : Colors.grey.shade200),
          width: esTitular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header de la tarjeta (Togglable para efecto acordeón)
          GestureDetector(
            onTap: () => setState(() => p.expandido = !p.expandido),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: esTitular ? _azul : Colors.grey.shade100,
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(16),
                    bottom: Radius.circular(p.expandido ? 0 : 16)),
              ),
              child: Row(
                children: [
                  Icon(
                    esTitular ? Icons.star : Icons.person_outline,
                    color: esTitular ? Colors.amber : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      esTitular
                          ? 'Titular / Pescador Principal'
                          : 'Invitado $index ${p.nombreCtrl.text.isNotEmpty ? "- ${p.nombreCtrl.text}" : ""}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: esTitular ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (p.exito)
                    const Icon(Icons.check_circle, color: _verde, size: 18)
                  else if (p.error != null)
                    const Icon(Icons.error, color: Colors.redAccent, size: 18)
                  else if (p.subiendo)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    p.expandido ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: esTitular ? Colors.white70 : Colors.grey,
                    size: 20,
                  ),
                  if (!esTitular) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _eliminarInvitado(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.redAccent, size: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Barra de progreso de subida individual
          if (p.subiendo)
            const LinearProgressIndicator(
              color: _verde,
              backgroundColor: _azulClaro,
              minHeight: 3,
            ),

          // Campos del formulario (Visibles solo si está expandido)
          if (p.expandido)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No se pudo guardar este pasajero. Revisá los datos e intentá nuevamente.',
                              style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (esTitular) ...[
                    // Perfil Premium del Titular
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: _azul.withOpacity(0.1),
                            backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                            child: p.avatarUrl == null 
                                ? const Icon(Icons.person, size: 36, color: _azul)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: Listenable.merge([p.nombreCtrl, p.apellidoCtrl]),
                            builder: (context, _) {
                              return Text(
                                '${p.nombreCtrl.text} ${p.apellidoCtrl.text}'.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _azul, letterSpacing: 0.5),
                              );
                            },
                          ),
                          Text(
                            p.emailCtrl.text,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.nombreCtrl,
                            label: 'Nombre',
                            icono: Icons.person,
                            enabled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.apellidoCtrl,
                            label: 'Apellido',
                            icono: Icons.person_outline,
                            enabled: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.dniCtrl,
                            label: 'DNI',
                            icono: Icons.badge_outlined,
                            teclado: TextInputType.number,
                            formato: [FilteringTextInputFormatter.digitsOnly],
                            enabled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.telefonoCtrl,
                            label: 'Teléfono',
                            icono: Icons.phone_android_rounded,
                            teclado: TextInputType.phone,
                            formato: [FilteringTextInputFormatter.digitsOnly],
                            enabled: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFechaNacimientoTile(p, index),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 8),
                    const Text(
                      'CONTACTO DE EMERGENCIA ANTE ACCIDENTES (OBLIGATORIO)',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCampo(
                      ctrl: p.emergenciaCtrl,
                      label: 'Número de Teléfono de Emergencia',
                      icono: Icons.emergency_share,
                      teclado: TextInputType.phone,
                      formato: [FilteringTextInputFormatter.digitsOnly],
                      enabled: true,
                    ),
                  ] else ...[
                    // Formulario del Invitado / Pasajero
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.nombreCtrl,
                            label: 'Nombre',
                            icono: Icons.person,
                            enabled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCampo(
                            ctrl: p.apellidoCtrl,
                            label: 'Apellido',
                            icono: Icons.person_outline,
                            enabled: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildCampo(
                            ctrl: p.dniCtrl,
                            label: 'DNI',
                            icono: Icons.badge_outlined,
                            teclado: TextInputType.number,
                            formato: [FilteringTextInputFormatter.digitsOnly],
                            enabled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: _buildCampo(
                            ctrl: p.telefonoCtrl,
                            label: 'Teléfono de Contacto',
                            icono: Icons.phone_android_rounded,
                            teclado: TextInputType.phone,
                            formato: [FilteringTextInputFormatter.digitsOnly],
                            enabled: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFechaNacimientoTile(p, index),
                  ],
                  
                  const SizedBox(height: 16),
                  // Foto del DNI
                  GestureDetector(
                    onTap: () => _seleccionarFoto(index),
                    child: Container(
                      width: double.infinity,
                      height: p.xFile != null ? 140 : 64,
                      decoration: BoxDecoration(
                        color: p.xFile != null
                            ? Colors.transparent
                            : _azulClaro,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: p.xFile != null
                              ? _verde
                              : _azul.withOpacity(0.3),
                          width: p.xFile != null ? 2 : 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: p.xFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  kIsWeb
                                      ? Image.network(p.xFile!.path, fit: BoxFit.cover)
                                      : Image.file(File(p.xFile!.path), fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _verde,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit,
                                              color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text('Cambiar',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: _azul.withOpacity(0.6), size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Foto del DNI (opcional)',
                                  style: TextStyle(
                                    color: _azul.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Botón agregar invitado ────────────────────────────────────────────────
  Widget _buildBotonAgregar() {
    return GestureDetector(
      onTap: _agregarInvitado,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _verde.withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF00875A),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'AGREGAR INVITADO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF00875A),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Campo de texto reutilizable ───────────────────────────────────────────
  Widget _buildCampo({
    required TextEditingController ctrl,
    required String label,
    required IconData icono,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter> formato = const [],
    bool enabled = true,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: teclado,
      inputFormatters: formato,
      enabled: enabled,
      style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey.shade600,
          fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icono, color: _azul, size: 18),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _azul, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

// ─── Modelo interno de un pasajero en el formulario ───────────────────────────
class _PasajeroForm {
  final TextEditingController nombreCtrl;
  final TextEditingController apellidoCtrl;
  final TextEditingController dniCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController emergenciaCtrl;
  final bool esTitular;
  DateTime? fechaNacimiento;
  String? avatarUrl;
  XFile? xFile;
  bool subiendo = false;
  bool exito = false;
  String? error;
  bool expandido = true;

  _PasajeroForm({
    String nombre = '',
    String apellido = '',
    String dni = '',
    required this.esTitular,
    this.expandido = true,
  })  : nombreCtrl = TextEditingController(text: nombre),
        apellidoCtrl = TextEditingController(text: apellido),
        dniCtrl = TextEditingController(text: dni),
        telefonoCtrl = TextEditingController(),
        emailCtrl = TextEditingController(),
        emergenciaCtrl = TextEditingController();

  void dispose() {
    nombreCtrl.dispose();
    apellidoCtrl.dispose();
    dniCtrl.dispose();
    telefonoCtrl.dispose();
    emailCtrl.dispose();
    emergenciaCtrl.dispose();
  }
}
