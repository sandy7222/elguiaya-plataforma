import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/afip_service.dart';

class AfipConfigCard extends StatefulWidget {
  const AfipConfigCard({super.key});

  @override
  State<AfipConfigCard> createState() => _AfipConfigCardState();
}

class _AfipConfigCardState extends State<AfipConfigCard> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  
  bool _facturacionActiva = false;
  String _entorno = 'sandbox';
  bool _obscureToken = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarConfigAfip();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfigAfip() async {
    setState(() => _isLoading = true);
    try {
      final config = await AfipService.obtenerConfigAfip();
      if (config != null) {
        setState(() {
          _facturacionActiva = config['afip_facturacion_activa'] as bool? ?? false;
          _entorno = config['afip_entorno']?.toString() ?? 'sandbox';
          _tokenController.text = config['afip_api_token']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error al cargar configuración AFIP: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _guardarConfigAfip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await AfipService.guardarConfigAfip(
        activa: _facturacionActiva,
        entorno: _entorno,
        token: _tokenController.text.trim().isEmpty ? null : _tokenController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '¡Configuración de AFIP guardada exitosamente!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar AFIP: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    // El color de acento cambia según el modo/entorno
    final Color accentColor = _facturacionActiva
        ? (_entorno == 'produccion' ? Colors.amberAccent : Colors.cyanAccent)
        : Colors.grey;

    return Form(
      key: _formKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate oscuro (800)
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER CON ESTÉTICA PREMIUM SLATE
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.4), // Slate oscuro (900)
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FACTURACIÓN ELECTRÓNICA AFIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _facturacionActiva
                                ? 'Facturación automática habilitada en entorno $_entorno'
                                : 'Módulo en Standby (sin emisión)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SWITCH DE ACTIVACIÓN
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Activar Facturación AFIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Genera facturas automáticamente al completar transacciones.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        value: _facturacionActiva,
                        activeColor: accentColor,
                        activeTrackColor: accentColor.withOpacity(0.3),
                        onChanged: (value) {
                          setState(() {
                            _facturacionActiva = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DROPDOWN DE ENTORNO
                    const Text(
                      'Entorno de Operación',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _entorno,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withOpacity(0.3),
                        prefixIcon: Icon(Icons.dns_rounded, color: accentColor.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: accentColor, width: 1.5),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'sandbox',
                          child: Text('Sandbox (Modo Pruebas Simulado)'),
                        ),
                        DropdownMenuItem(
                          value: 'homologacion',
                          child: Text('Homologación (Pruebas AFIP Oficial)'),
                        ),
                        DropdownMenuItem(
                          value: 'produccion',
                          child: Text('Producción (Emisión Real de Facturas)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _entorno = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // TEXTFIELD PROTEGIDO PARA TOKEN
                    const Text(
                      'AFIP API Token',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ingrese clave / token de facturación...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withOpacity(0.3),
                        prefixIcon: Icon(Icons.key_rounded, color: accentColor.withOpacity(0.6)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.white38,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: accentColor, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (_facturacionActiva && _entorno == 'produccion' && (value == null || value.trim().isEmpty)) {
                          return 'El token de API es mandatorio para entorno de producción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // BOTÓN DE GUARDADO ASÍNCRONO
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _guardarConfigAfip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: const Color(0xFF0F172A),
                          disabledBackgroundColor: accentColor.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0F172A),
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, color: const Color(0xFF0F172A)),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'APLICAR CONFIGURACIÓN AFIP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // MONITOR DE AUDITORÍA (ÚLTIMAS 3 FACTURAS)
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.query_stats_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'MINI-MONITOR DE AUDITORÍA (ÚLTIMAS 3)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // STREAMBUILDER EN TIEMPO REAL
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('facturas_afip')
                          .stream(primaryKey: ['id'])
                          .order('created_at', ascending: false)
                          .map((event) => List<Map<String, dynamic>>.from(event).take(3).toList()),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar logs: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          );
                        }

                        final logs = snapshot.data!;
                        if (logs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.03)),
                            ),
                            child: Center(
                              child: Text(
                                'No se registran transacciones en el log de AFIP.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: logs.map((log) {
                            final String estado = log['estado']?.toString() ?? 'pendiente';
                            final double monto = (log['monto'] as num?)?.toDouble() ?? 0.0;
                            final String dni = log['dni_cliente']?.toString() ?? 'N/A';
                            final String? cae = log['numero_cae']?.toString();
                            final String entornoLog = log['entorno']?.toString() ?? 'sandbox';
                            final String timestampStr = log['created_at']?.toString() ?? '';
                            final DateTime timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();

                            Color badgeColor = Colors.grey;
                            String badgeText = estado.toUpperCase();
                            if (estado == 'emitida') {
                              badgeColor = Colors.green;
                            } else if (estado == 'error') {
                              badgeColor = Colors.redAccent;
                            } else if (estado == 'omitida') {
                              badgeColor = Colors.grey;
                              badgeText = 'STANDBY';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: stateBorderColor(estado).withOpacity(0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Cliente DNI/CUIT: $dni',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Monto: \$${monto.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.cyanAccent.withOpacity(0.8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Entorno: ${entornoLog.toUpperCase()}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (cae != null && cae.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'CAE: $cae | Vence: ${log['vencimiento_cae'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                  ],
                                  if (estado == 'error' && log['error_detalle'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Detalle: ${log['error_detalle']}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.2),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color stateBorderColor(String estado) {
    switch (estado) {
      case 'emitida':
        return Colors.green;
      case 'error':
        return Colors.redAccent;
      case 'omitida':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
