import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/mercado_pago_service.dart';
import '../services/dynamic_skill_system.dart';

class AdminSistemaScreen extends StatefulWidget {
  const AdminSistemaScreen({super.key});

  @override
  State<AdminSistemaScreen> createState() => _AdminSistemaScreenState();
}

class _AdminSistemaScreenState extends State<AdminSistemaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _publicKeyController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _logisticaPublicKeyController = TextEditingController();
  final _logisticaAccessTokenController = TextEditingController();
  
  bool _isSandbox = true;
  bool _mantenimientoTienda = false;
  bool _logisticaIsSandbox = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _publicKeyController.dispose();
    _accessTokenController.dispose();
    _logisticaPublicKeyController.dispose();
    _logisticaAccessTokenController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _isLoading = true);
    try {
      final config = await SupabaseService.getSistemaConfig();
      if (config != null) {
        _publicKeyController.text = config['mp_public_key']?.toString() ?? '';
        _accessTokenController.text = config['mp_access_token']?.toString() ?? '';
        _isSandbox = config['is_sandbox'] as bool? ?? true;
        _mantenimientoTienda = config['mantenimiento_tienda'] as bool? ?? false;
        _logisticaPublicKeyController.text = config['logistica_public_key']?.toString() ?? '';
        _logisticaAccessTokenController.text = config['logistica_access_token']?.toString() ?? '';
        _logisticaIsSandbox = config['logistica_is_sandbox'] as bool? ?? true;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Error al cargar configuración: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.guardarSistemaConfig(
        publicKey: _publicKeyController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        isSandbox: _isSandbox,
        mantenimientoTienda: _mantenimientoTienda,
        logisticaPublicKey: _logisticaPublicKeyController.text.trim(),
        logisticaAccessToken: _logisticaAccessTokenController.text.trim(),
        logisticaIsSandbox: _logisticaIsSandbox,
      );

      // Recargar credenciales locales en MercadoPagoService inmediatamente
      await MercadoPagoService.cargarCredenciales();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('¡Configuración guardada y aplicada en tiempo real!', 
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del módulo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.handshake_rounded, // Ícono de manos estrechadas (Mercado Pago handshake)
                    color: Colors.blueAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pasarela de Pagos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Configuración dinámica de Mercado Pago sin recompilar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Card Principal Glassmorphic
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.handshake_outlined,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'CREDENCIALES API DE MERCADO PAGO',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Campo: Public Key
                      const Text(
                        'Mercado Pago Public Key',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _publicKeyController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ej: APP_USR-xxxxxx-xxxx-xxxx...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          prefixIcon: Icon(Icons.key, color: Colors.white.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa la Public Key';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Campo: Access Token
                      const Text(
                        'Mercado Pago Access Token',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accessTokenController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Ej: APP_USR-xxxxxxxxxxxxxxxx...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          prefixIcon: Icon(Icons.vpn_key_rounded, color: Colors.white.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el Access Token';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Switch: Sandbox Mode
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSandbox 
                              ? Colors.orange.withOpacity(0.1) 
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isSandbox 
                                ? Colors.orange.withOpacity(0.3) 
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isSandbox ? Colors.orange : Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSandbox ? Icons.bug_report_outlined : Icons.gavel_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSandbox ? 'Modo Sandbox Activo' : 'Modo Producción Activo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _isSandbox 
                                        ? 'Operando con credenciales de prueba'
                                        : '¡Cobros reales activos en la app!',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isSandbox,
                              activeColor: Colors.orangeAccent,
                              activeTrackColor: Colors.orange.withOpacity(0.4),
                              inactiveThumbColor: Colors.greenAccent,
                              inactiveTrackColor: Colors.green.withOpacity(0.4),
                              onChanged: (value) {
                                  setState(() => _isSandbox = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Switch: Modo Mantenimiento E-Commerce
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _mantenimientoTienda 
                              ? Colors.redAccent.withOpacity(0.1) 
                              : Colors.cyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _mantenimientoTienda 
                                ? Colors.redAccent.withOpacity(0.3) 
                                : Colors.cyan.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _mantenimientoTienda ? Colors.redAccent : Colors.cyan,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _mantenimientoTienda ? Icons.engineering_rounded : Icons.store_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _mantenimientoTienda ? 'Mantenimiento Activo' : 'E-Commerce Online',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _mantenimientoTienda 
                                        ? 'Clientes verán pantalla de mantenimiento'
                                        : 'Tienda oficial accesible al público',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _mantenimientoTienda,
                              activeColor: Colors.redAccent,
                              activeTrackColor: Colors.red.withOpacity(0.4),
                              inactiveThumbColor: Colors.cyanAccent,
                              inactiveTrackColor: Colors.cyan.withOpacity(0.4),
                              onChanged: (value) {
                                setState(() => _mantenimientoTienda = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card Logística Glassmorphic
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            color: Colors.tealAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'CREDENCIALES API DE LOGÍSTICA',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Campo: Public Key de Logística
                      const Text(
                        'Public Key / API Key de Logística',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _logisticaPublicKeyController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ej: LOG-PUB-xxxxxx-xxxx-xxxx...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          prefixIcon: Icon(Icons.key, color: Colors.white.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Campo: Access Token / Token del Integrador
                      const Text(
                        'Token del Integrador Logístico',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _logisticaAccessTokenController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Ej: LOG-TOKEN-xxxxxxxxxxxxxxxx...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          prefixIcon: Icon(Icons.vpn_key_rounded, color: Colors.white.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Switch: Sandbox Mode Logística
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _logisticaIsSandbox 
                              ? Colors.amber.withOpacity(0.1) 
                              : Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _logisticaIsSandbox 
                                ? Colors.amber.withOpacity(0.3) 
                                : Colors.teal.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _logisticaIsSandbox ? Colors.amber : Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _logisticaIsSandbox ? Icons.bug_report_outlined : Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _logisticaIsSandbox ? 'Entorno de Pruebas Activo' : 'Entorno Producción Activo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _logisticaIsSandbox 
                                        ? 'Peticiones de cotización y despacho simuladas'
                                        : '¡Envíos reales activos con la transportadora!',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _logisticaIsSandbox,
                              activeColor: Colors.amberAccent,
                              activeTrackColor: Colors.amber.withOpacity(0.4),
                              inactiveThumbColor: Colors.tealAccent,
                              inactiveTrackColor: Colors.teal.withOpacity(0.4),
                              onChanged: (value) {
                                  setState(() => _logisticaIsSandbox = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Inyección Dinámica de Skills de Sistema
            ...SystemSkillRegistry.skills.map((skill) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: skill.buildConfigCard(context),
                )),

            const SizedBox(height: 32),

            // Botón de Guardar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarConfiguracion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.blueAccent.withOpacity(0.4),
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'GUARDANDO CONFIGURACIÓN...', 
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'APLICAR CAMBIOS EN CALIENTE', 
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
