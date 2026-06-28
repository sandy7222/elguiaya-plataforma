

import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';

import '../models/documento.dart';
import '../models/perfil_capitan.dart';
import '../services/supabase_service.dart';
import '../widgets/camera_picker.dart';
import '../widgets/geofencing_config_widget.dart';

class CapitanConfigScreen extends StatefulWidget {
  const CapitanConfigScreen({super.key});

  @override
  State<CapitanConfigScreen> createState() => _CapitanConfigScreenState();
}

class _CapitanConfigScreenState extends State<CapitanConfigScreen> {
  PerfilCapitan? _perfil;
  bool _isLoading = true;
  bool _guardando = false;
  
  String get _capitanId => SupabaseService.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      setState(() => _isLoading = true);
      
      final perfil = await SupabaseService.getPerfilCapitan(_capitanId);
      
      setState(() {
        _perfil = perfil ?? PerfilCapitan.temporal(userId: _capitanId);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar perfil: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _actualizarDisponibilidad(bool disponible) async {
    try {
      setState(() => _guardando = true);
      
      await SupabaseService.cambiarDisponibilidadCapitan(_capitanId, disponible);
      
      // Recargar perfil
      await _cargarPerfil();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(disponible 
                  ? 'Ahora estas disponible para recibir cotizaciones' 
                  : 'Ya no recibiras nuevas cotizaciones'),
            ),
            backgroundColor: disponible ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cambiar disponibilidad: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (_perfil == null) return;
    
    try {
      setState(() => _guardando = true);
      
      await SupabaseService.actualizarPerfilCapitan(_perfil!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Perfil y documentacion actualizados correctamente')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar cambios: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _onPerfilActualizado(PerfilCapitan perfilActualizado) {
    setState(() {
      _perfil = perfilActualizado;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Configuracion del Capitan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado de disponibilidad
            _buildDisponibilidadCard(),
            
            const SizedBox(height: 16),
            
            // Configuracion de geofencing
            GeofencingConfigWidget(
              perfil: _perfil!,
              onPerfilUpdated: _onPerfilActualizado,
            ),
            
            const SizedBox(height: 16),
            
            // Configuracion de tiempo de respuesta
            _buildTiempoRespuestaCard(),
            
            const SizedBox(height: 16),
            
            // Informacion de contacto
            _buildContactoCard(),
            
            const SizedBox(height: 16),
            
            // Documentacion
            _buildDocumentacionCard(),
            
            const SizedBox(height: 32),
            
            // Boton de guardar
            if (_guardando)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: SafeElevatedIconButton(
  onPressed: _guardarCambios,
  icon: Icons.save,
  label: 'Guardar Todo',
  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisponibilidadCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _perfil!.disponible ? Icons.power : Icons.power_off,
                  color: _perfil!.disponible ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disponibilidad',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      Text(
                        _perfil!.disponible 
                            ? 'Recibiendo solicitudes activamente'
                            : 'En pausa - no recibiras nuevas solicitudes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Switch de disponibilidad
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _perfil!.disponible ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _perfil!.disponible ? Colors.green[200]! : Colors.red[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _perfil!.disponible ? Icons.check_circle : Icons.cancel,
                    color: _perfil!.disponible ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _perfil!.disponible ? 'Disponible' : 'No disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _perfil!.disponible ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  Switch(
                    value: _perfil!.disponible,
                    onChanged: _guardando ? null : _actualizarDisponibilidad,
                    activeThumbColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Informacion adicional
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cuando estas disponible, recibiras automaticamente solicitudes de cotizacion dentro de tu zona de trabajo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiempoRespuestaCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Tiempo de Respuesta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Limite actual:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[700],
                    ),
                  ),
                  Text(
                    _perfil!.limiteRespuestaFormateado,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Este es el tiempo maximo que tienes para responder a las solicitudes de cotizacion antes de que se marquen como en riesgo.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Informacion de Contacto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildContactItem('Telefono Principal', _perfil!.telefonoPrincipal),
            const SizedBox(height: 8),
            _buildContactItem('DNI', _perfil!.dni ?? 'No configurado'),
            
            if (_perfil!.tieneGeofencingConfigurado) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Zona de trabajo configurada: ${_perfil!.nombreCentroOperacion}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentacionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_shared, color: Color(0xFF0D47A1), size: 24),
                SizedBox(width: 12),
                Text(
                  'Mi Documentacion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mantene tus documentos actualizados para evitar suspensiones.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            
            CameraPicker(
              userId: _perfil!.userId,
              tipoDoc: Documento.FOTO_PERFIL_CAPITAN,
              titulo: 'Avatar (Foto de Perfil)',
              icono: Icons.face,
              onImageSelected: (_) {},
              onUrlGenerated: (url) {
                setState(() {
                  _perfil = _perfil!.copyWith(avatarUrl: url);
                });
              },
            ),

            CameraPicker(
              userId: _perfil!.userId,
              tipoDoc: Documento.SEGURO,
              titulo: 'Seguro (Póliza)',
              icono: Icons.verified_user,
              onImageSelected: (_) {},
              onUrlGenerated: (url) {
                setState(() {
                  _perfil = _perfil!.copyWith(seguroUrl: url);
                });
              },
            ),

            CameraPicker(
              userId: _perfil!.userId,
              tipoDoc: Documento.FOTO_EMBARCACION,
              titulo: 'Embarcación',
              icono: Icons.directions_boat,
              onImageSelected: (_) {},
              onUrlGenerated: (url) {
                setState(() {
                  _perfil = _perfil!.copyWith(embarcacionUrl: url);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
