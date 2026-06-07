import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminCentroComputosScreen extends StatefulWidget {
  const AdminCentroComputosScreen({super.key});

  @override
  State<AdminCentroComputosScreen> createState() => _AdminCentroComputosScreenState();
}

class _AdminCentroComputosScreenState extends State<AdminCentroComputosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _capitanes = [];
  bool _autoSuspensionEngine = true; // Activo por defecto

  // Estadísticas locales
  int _totalMonitoreados = 0;
  int _totalAlDia = 0;
  int _totalVencidos = 0;

  final Color _bgDark = const Color(0xFF001A33);
  final Color _accentGold = const Color(0xFFFFC107);
  final Color _primaryBlue = const Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();
    _cargarCapitanesYAuditar();
  }

  Future<void> _cargarCapitanesYAuditar() async {
    try {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;

      // 1. Obtener todos los perfiles que son capitanes
      final data = await supabase
          .from('profiles')
          .select('*')
          .eq('es_capitan', true)
          .order('nombre', ascending: true);

      final List<Map<String, dynamic>> listaCapitanes = List<Map<String, dynamic>>.from(data);

      // 2. Ejecutar motor de auditoría en vivo si está encendido
      int alDia = 0;
      int vencidos = 0;
      final hoy = DateTime.now();

      for (var cap in listaCapitanes) {
        bool seguroVencido = false;
        bool carnetVencido = false;

        // Comprobar vencimiento de Seguro
        if (cap['vencimiento_seguro'] != null) {
          final fechaSeguro = DateTime.parse(cap['vencimiento_seguro']);
          if (fechaSeguro.isBefore(hoy)) {
            seguroVencido = true;
          } else {
            // Auditoría de Proximidad de Seguro (5 días)
            final diasRestantes = fechaSeguro.difference(hoy).inDays;
            if (diasRestantes >= 0 && diasRestantes <= 5) {
              final formattedDate = '${fechaSeguro.day.toString().padLeft(2, '0')}/${fechaSeguro.month.toString().padLeft(2, '0')}/${fechaSeguro.year}';
              final titulo = '🚨 Vencimiento de Seguro Próximo';
              final mensaje = 'Hola ${cap['nombre'] ?? 'Capitán'}, tu Seguro de Embarcación vencerá el $formattedDate. Por favor renuévalo para evitar la suspensión de tu cuenta.';
              
              // Verificar si ya tiene una notificación igual activa no leída para evitar spam
              supabase
                  .from('notificaciones')
                  .select('id')
                  .eq('usuario_id', cap['user_id'])
                  .eq('titulo', titulo)
                  .eq('leida', false)
                  .maybeSingle()
                  .then((existeNoti) async {
                if (existeNoti == null) {
                  await SupabaseService.enviarNotificacion(
                    usuarioId: cap['user_id'],
                    titulo: titulo,
                    mensaje: mensaje,
                    tipo: 'viaje',
                  );
                }
              }).catchError((err) => debugPrint('Error al notificar vencimiento seguro: $err'));
            }
          }
        } else {
          // Si no tiene seguro declarado, se considera de alto riesgo
          seguroVencido = true; 
        }

        // Comprobar vencimiento de Carnet/Licencia
        if (cap['vencimiento_carnet'] != null) {
          final fechaCarnet = DateTime.parse(cap['vencimiento_carnet']);
          if (fechaCarnet.isBefore(hoy)) {
            carnetVencido = true;
          } else {
            // Auditoría de Proximidad de Carnet (5 días)
            final diasRestantes = fechaCarnet.difference(hoy).inDays;
            if (diasRestantes >= 0 && diasRestantes <= 5) {
              final formattedDate = '${fechaCarnet.day.toString().padLeft(2, '0')}/${fechaCarnet.month.toString().padLeft(2, '0')}/${fechaCarnet.year}';
              final titulo = '🚨 Vencimiento de Carnet Próximo';
              final mensaje = 'Hola ${cap['nombre'] ?? 'Capitán'}, tu Carnet de Timonel vencerá el $formattedDate. Por favor renuévalo para evitar la suspensión de tu cuenta.';
              
              supabase
                  .from('notificaciones')
                  .select('id')
                  .eq('usuario_id', cap['user_id'])
                  .eq('titulo', titulo)
                  .eq('leida', false)
                  .maybeSingle()
                  .then((existeNoti) async {
                if (existeNoti == null) {
                  await SupabaseService.enviarNotificacion(
                    usuarioId: cap['user_id'],
                    titulo: titulo,
                    mensaje: mensaje,
                    tipo: 'viaje',
                  );
                }
              }).catchError((err) => debugPrint('Error al notificar vencimiento carnet: $err'));
            }
          }
        } else {
          carnetVencido = true;
        }

        // Si el motor automático está activo y tiene algo vencido, suspenderlo
        if (_autoSuspensionEngine && (seguroVencido || carnetVencido)) {
          if (cap['estado'] == 'activo') {
            // Suspender en base de datos en segundo plano
            await supabase
                .from('profiles')
                .update({'estado': 'suspendido', 'verificado': false})
                .eq('user_id', cap['user_id']);
            cap['estado'] = 'suspendido';
          }
          vencidos++;
        } else {
          if (seguroVencido || carnetVencido) {
            vencidos++;
          } else {
            alDia++;
          }
        }
      }

      setState(() {
        _capitanes = listaCapitanes;
        _totalMonitoreados = listaCapitanes.length;
        _totalAlDia = alDia;
        _totalVencidos = vencidos;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error en Centro de Cómputos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar Centro de Cómputos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarEstadoManual(String userId, String nuevoEstado) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({'estado': nuevoEstado, 'verificado': nuevoEstado == 'activo'})
          .eq('user_id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado == 'activo' ? 'Capitán Activado con Éxito.' : 'Capitán Suspendido Manualmente.'),
          backgroundColor: nuevoEstado == 'activo' ? Colors.green : Colors.red,
        ),
      );

      _cargarCapitanesYAuditar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _mostrarDialogoActivacion(Map<String, dynamic> cap) async {
    bool extenderSeguro = true;
    bool extenderCarnet = true;
    DateTime nuevaFechaSeguro = DateTime.now().add(const Duration(days: 365));
    DateTime nuevaFechaCarnet = DateTime.now().add(const Duration(days: 365));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF001F3F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
              title: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Activar a ${cap['nombre'] ?? 'Capitán'}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      'Para evitar que el motor de auditoría automática vuelva a suspender al socio inmediatamente, podés extender el vencimiento de sus credenciales:',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    
                    CheckboxListTile(
                      title: const Text('Extender Seguro (1 año)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('Nueva fecha: ${_formatFecha(nuevaFechaSeguro.toIso8601String())}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      value: extenderSeguro,
                      activeColor: const Color(0xFF00E676),
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setDialogState(() {
                          extenderSeguro = val ?? false;
                        });
                      },
                    ),
                    
                    const Divider(color: Colors.white12),
                    
                    CheckboxListTile(
                      title: const Text('Extender Carnet/Licencia (1 año)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('Nueva fecha: ${_formatFecha(nuevaFechaCarnet.toIso8601String())}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      value: extenderCarnet,
                      activeColor: const Color(0xFF00E676),
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setDialogState(() {
                          extenderCarnet = val ?? false;
                        });
                      },
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
                    await _confirmarActivacion(
                      userId: cap['user_id'],
                      extenderSeguro: extenderSeguro,
                      nuevaFechaSeguro: nuevaFechaSeguro,
                      extenderCarnet: extenderCarnet,
                      nuevaFechaCarnet: nuevaFechaCarnet,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ACTIVAR ACCESO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarActivacion({
    required String userId,
    required bool extenderSeguro,
    required DateTime nuevaFechaSeguro,
    required bool extenderCarnet,
    required DateTime nuevaFechaCarnet,
  }) async {
    try {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;
      
      final Map<String, dynamic> updates = {
        'estado': 'activo',
        'verificado': true,
        'motivo_suspension': null,
      };

      if (extenderSeguro) {
        updates['vencimiento_seguro'] = nuevaFechaSeguro.toIso8601String();
      }
      if (extenderCarnet) {
        updates['vencimiento_carnet'] = nuevaFechaCarnet.toIso8601String();
      }

      await supabase
          .from('profiles')
          .update(updates)
          .eq('user_id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capitán Activado con Éxito y credenciales extendidas.'),
          backgroundColor: Colors.green,
        ),
      );

      await _cargarCapitanesYAuditar();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al activar capitán: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatFecha(String? dateStr) {
    if (dateStr == null) return 'No declarada';
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'CENTRO DE CÓMPUTOS Y AUDITORÍA',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(color: Colors.white.withOpacity(0.03)),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDark, const Color(0xFF0A192F)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Panel de Control e Indicador de Motor Automático
                      _buildEnginePanel(),
                      const SizedBox(height: 24),

                      // Tarjetas de Estadísticas Náuticas
                      _buildStatsDashboard(),
                      const SizedBox(height: 32),

                      // Título y Filtros
                      const Row(
                        children: [
                          Icon(Icons.monitor_heart_rounded, color: Colors.orangeAccent, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'LEGAJO GENERAL DE EXPIRACIÓN NÁUTICA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Listado de Capitanes Auditados
                      _capitanes.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _capitanes.length,
                              itemBuilder: (context, index) {
                                final cap = _capitanes[index];
                                return _buildCaptainAuditCard(cap);
                              },
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEnginePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: _autoSuspensionEngine ? const Color(0xFF00E676) : Colors.orangeAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MOTOR DE AUDITORÍA AUTOMÁTICA',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: _autoSuspensionEngine,
                activeColor: const Color(0xFF00E676),
                onChanged: (value) {
                  setState(() {
                    _autoSuspensionEngine = value;
                  });
                  _cargarCapitanesYAuditar();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _autoSuspensionEngine
                ? '🤖 PROTECCIÓN ACTIVA: El sistema escanea y suspende automáticamente a cualquier Capitán que tenga el Seguro o Carnet de Timonel vencido o no declarado, garantizando cero responsabilidad civil para la plataforma.'
                : '⚠️ MANUAL: El sistema solo notificará de las expiraciones. Las suspensiones o bloqueos de acceso deberán realizarse manualmente por un administrador.',
            style: TextStyle(
              color: _autoSuspensionEngine ? Colors.white60 : Colors.orangeAccent.withOpacity(0.8),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('MONITOREADOS', _totalMonitoreados.toString(), Icons.analytics_outlined, Colors.blue),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('AL DÍA', _totalAlDia.toString(), Icons.verified_user_rounded, const Color(0xFF00E676)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('SUSPENDIDOS', _totalVencidos.toString(), Icons.block_flipped, Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainAuditCard(Map<String, dynamic> cap) {
    final hoy = DateTime.now();
    bool seguroVencido = false;
    bool carnetVencido = false;

    // Verificar seguro
    if (cap['vencimiento_seguro'] != null) {
      final fechaSeguro = DateTime.parse(cap['vencimiento_seguro']);
      if (fechaSeguro.isBefore(hoy)) {
        seguroVencido = true;
      }
    } else {
      seguroVencido = true;
    }

    // Verificar carnet
    if (cap['vencimiento_carnet'] != null) {
      final fechaCarnet = DateTime.parse(cap['vencimiento_carnet']);
      if (fechaCarnet.isBefore(hoy)) {
        carnetVencido = true;
      }
    } else {
      carnetVencido = true;
    }

    final bool isSuspended = cap['estado'] != 'activo';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuspended ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cap['estado'] == 'en_revision') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NUEVA DOCUMENTACIÓN ENVIADA',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'El socio actualizó sus credenciales y espera activación.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _mostrarDialogoRevisarDocumento(cap),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(60, 30),
                    ),
                    child: const Text('REVISAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
          // Header del Capitán
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white10,
                      backgroundImage: cap['avatar_url'] != null ? NetworkImage(cap['avatar_url']) : null,
                      child: cap['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white54) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cap['nombre'] ?? 'Sin Nombre',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'DNI: ${cap['dni'] ?? 'N/A'} • Exp: ${cap['expediente'] ?? 'PENDIENTE'}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuspended ? Colors.red.withOpacity(0.12) : const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuspended ? Colors.red.withOpacity(0.3) : const Color(0xFF00E676).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isSuspended ? 'SUSPENDIDO' : 'ACTIVO',
                  style: TextStyle(
                    color: isSuspended ? Colors.redAccent : const Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 18),

          // Control de Vencimientos
          Row(
            children: [
              // Seguro Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SEGURO DE EMBARCACIÓN', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _formatFecha(cap['vencimiento_seguro']),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusIndicator(
                      seguroVencido ? 'VENCIDO / INEXISTENTE' : 'VIGENTE AL DÍA',
                      !seguroVencido,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Licencia Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CARNET DE TIMONEL', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _formatFecha(cap['vencimiento_carnet']),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusIndicator(
                      carnetVencido ? 'VENCIDO / INEXISTENTE' : 'VIGENTE AL DÍA',
                      !carnetVencido,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Acciones Administrativas
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSuspended)
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoActivacion(cap),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('ACTIVAR ACCESO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _cambiarEstadoManual(cap['user_id'], 'suspendido'),
                  icon: const Icon(Icons.block_flipped, size: 14, color: Colors.redAccent),
                  label: const Text('SUSPENDER SOCIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String text, bool isValid) {
    final color = isValid ? const Color(0xFF00E676) : Colors.redAccent;
    return Row(
      children: [
        Icon(isValid ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, color: color, size: 12),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.supervisor_account_rounded, color: Colors.white24, size: 60),
          const SizedBox(height: 16),
          const Text('Sin Capitanes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('No se encontraron perfiles de Capitán en la base de datos.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _rechazarDocumentacion(String userId, String motivo) async {
    try {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('profiles')
          .update({
            'estado': 'suspendido',
            'verificado': false,
            'motivo_suspension': motivo.isNotEmpty 
                ? 'Documentación rechazada: $motivo'
                : 'Documentación rechazada por la administración. Por favor suba una foto legible de sus credenciales.',
          })
          .eq('user_id', userId);

      await SupabaseService.enviarNotificacion(
        usuarioId: userId,
        titulo: '❌ Credenciales Rechazadas',
        mensaje: 'Tu documentación fue rechazada por la administración: $motivo. Por favor, sube una foto legible.',
        tipo: 'viaje',
      ).catchError((err) => debugPrint('Error al notificar rechazo: $err'));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documentación rechazada y Capitán notificado.'),
          backgroundColor: Colors.orange,
        ),
      );

      await _cargarCapitanesYAuditar();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _mostrarDialogoRevisarDocumento(Map<String, dynamic> cap) async {
    final String? seguroUrl = cap['seguro_url'];
    final String? carnetUrl = cap['carnet_url'];
    final String userId = cap['user_id'];

    await showDialog(
      context: context,
      builder: (context) {
        final TextEditingController rechazoController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF001220),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.blueAccent, width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.rate_review_rounded, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Revisar Documentos: ${cap['nombre'] ?? 'Capitán'}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      'Verificá que las imágenes de las credenciales subidas sean legibles y correspondan con las fechas declaradas:',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    
                    if (seguroUrl != null) ...[
                      const Text(
                        'SEGURO DE EMBARCACIÓN',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Vencimiento Declarado: ${_formatFecha(cap['vencimiento_seguro'])}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _verImagenCompleta(context, seguroUrl, 'Seguro de Embarcación'),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                            image: DecorationImage(
                              image: NetworkImage(seguroUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.black38,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('AMPLIAR FOTO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (carnetUrl != null) ...[
                      const Text(
                        'CARNET DE TIMONEL / LICENCIA',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Vencimiento Declarado: ${_formatFecha(cap['vencimiento_carnet'])}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _verImagenCompleta(context, carnetUrl, 'Carnet de Timonel'),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                            image: DecorationImage(
                              image: NetworkImage(carnetUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.black38,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('AMPLIAR FOTO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),
                    const Text(
                      'Motivo de rechazo (solo si vas a rechazar):',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rechazoController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ej: Foto ilegible / documento vencido...',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _rechazarDocumentacion(userId, rechazoController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _confirmarActivacion(
                      userId: userId,
                      extenderSeguro: false,
                      nuevaFechaSeguro: DateTime.now(),
                      extenderCarnet: false,
                      nuevaFechaCarnet: DateTime.now(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('APROBAR Y ACTIVAR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _verImagenCompleta(BuildContext context, String url, String titulo) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.orange));
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
