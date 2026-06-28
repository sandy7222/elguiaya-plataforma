

import 'package:flutter/material.dart';

import '../widgets/safe_button.dart';
import '../services/moderacion_service.dart';
import '../services/seguridad_service.dart';

class SeguridadAdminScreen extends StatefulWidget {
  const SeguridadAdminScreen({super.key});

  @override
  State<SeguridadAdminScreen> createState() => _SeguridadAdminScreenState();
}

class _SeguridadAdminScreenState extends State<SeguridadAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GestionUsuario> _usuarios = [];
  List<LogAuditoria> _logs = [];
  List<AlertaSeguridad> _alertas = [];
  EstadisticasSeguridad? _estadisticas;
  bool _isLoading = true;
  String _searchQuery = '';
  String _filtroTipoAccion = 'todos';

  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _rojoFuerte = Color(0xFFFF0000);
  static const Color _grisMedio = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usuarios = await SeguridadService.getGestionUsuarios();
      final logs = await SeguridadService.getLogsAuditoria();
      final alertas = await ModeracionService.obtenerAlertasRecientes();
      final estadisticas = await SeguridadService.getEstadisticasSeguridad();

      if (mounted) {
        setState(() {
          _usuarios = usuarios;
          _logs = logs;
          _alertas = alertas;
          _estadisticas = estadisticas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  List<GestionUsuario> get _usuariosFiltrados {
    if (_searchQuery.isEmpty) return _usuarios;
    
    return _usuarios.where((usuario) =>
      usuario.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      usuario.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<LogAuditoria> get _logsFiltrados {
    if (_filtroTipoAccion == 'todos') return _logs;
    return _logs.where((log) => log.tipoAccion == _filtroTipoAccion).toList();
  }

  Widget _buildEstadisticasCard() {
    if (_estadisticas == null) return Container();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blancoPuro.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadisticas de Seguridad',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatCard('Total Usuarios', _estadisticas!.totalUsuarios.toString(), _azulVibrante),
              _buildStatCard('Usuarios Activos', _estadisticas!.usuariosActivos.toString(), _verdeBrillante),
              _buildStatCard('Usuarios Baneados', _estadisticas!.usuariosBaneados.toString(), _rojoFuerte),
              _buildStatCard('Capitanes Verificados', _estadisticas!.capitanesVerificados.toString(), _naranjaIntenso),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGestionUsuariosTab() {
    return Column(
      children: [
        // Barra de busqueda
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fondoOscuro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blancoPuro.withOpacity(0.2)),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar usuarios...',
              hintStyle: TextStyle(color: _blancoPuro.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: _blancoPuro.withOpacity(0.7)),
              border: InputBorder.none,
            ),
            style: TextStyle(color: _blancoPuro),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista de usuarios
        Expanded(
          child: ListView.builder(
            itemCount: _usuariosFiltrados.length,
            itemBuilder: (context, index) {
              final usuario = _usuariosFiltrados[index];
              return _buildUsuarioCard(usuario);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsuarioCard(GestionUsuario usuario) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: usuario.estaBaneado 
              ? _rojoFuerte.withOpacity(0.3)
              : usuario.esCapitanVerificado
                  ? _verdeBrillante.withOpacity(0.3)
                  : _blancoPuro.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          usuario.nombre,
                          style: TextStyle(
                            color: _blancoPuro,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (usuario.esCapitanVerificado) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.verified, color: _verdeBrillante, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.email,
                      style: TextStyle(
                        color: _blancoPuro.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRolColor(usuario.rol).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            usuario.rol.toUpperCase(),
                            style: TextStyle(
                              color: _getRolColor(usuario.rol),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(usuario.estadoCuenta).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            usuario.estadoCuenta.toUpperCase(),
                            style: TextStyle(
                              color: _getEstadoColor(usuario.estadoCuenta),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Switch de estado de cuenta
              Column(
                children: [
                  Switch(
                    value: !usuario.estaBaneado,
                    onChanged: (value) {
                      _cambiarEstadoCuenta(usuario, value ? 'activo' : 'baneado');
                    },
                    activeThumbColor: _verdeBrillante,
                    inactiveThumbColor: _rojoFuerte,
                  ),
                  Text(
                    usuario.estaBaneado ? 'Baneado' : 'Activo',
                    style: TextStyle(
                      color: usuario.estaBaneado ? _rojoFuerte : _verdeBrillante,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (usuario.rol == 'capitan') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Verificacion: ${usuario.verificado ? "Verificado" : "No verificado"}',
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                Switch(
                  value: usuario.verificado,
                  onChanged: (value) {
                    _cambiarVerificacion(usuario, value);
                  },
                  activeThumbColor: _verdeBrillante,
                  inactiveThumbColor: _grisMedio,
                ),
              ],
            ),
          ],
          
          if (usuario.estaBaneado && usuario.motivoBaneo != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _rojoFuerte.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _rojoFuerte.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo de baneo:',
                    style: TextStyle(
                      color: _rojoFuerte,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    usuario.motivoBaneo!,
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'capitan':
        return _naranjaIntenso;
      case 'pescador':
        return _azulVibrante;
      case 'admin':
        return _verdeBrillante;
      default:
        return _grisMedio;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'activo':
        return _verdeBrillante;
      case 'baneado':
        return _rojoFuerte;
      default:
        return _grisMedio;
    }
  }

  Future<void> _cambiarEstadoCuenta(GestionUsuario usuario, String nuevoEstado) async {
    try {
      String? motivo;
      if (nuevoEstado == 'baneado') {
        // Mostrar dialogo para ingresar motivo
        motivo = await _mostrarDialogoMotivo(usuario);
        if (motivo == null) return; // Usuario cancelo
      }

      final resultado = await SeguridadService.cambiarEstadoCuenta(
        usuarioId: usuario.id,
        nuevoEstado: nuevoEstado,
        motivo: motivo,
      );

      if (resultado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario ${nuevoEstado == 'baneado' ? 'baneado' : 'desbaneado'} exitosamente'),
            backgroundColor: nuevoEstado == 'baneado' ? _naranjaIntenso : _verdeBrillante,
          ),
        );
        _cargarDatos(); // Recargar datos
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _rojoFuerte,
        ),
      );
    }
  }

  Future<void> _cambiarVerificacion(GestionUsuario usuario, bool verificado) async {
    try {
      String? motivo;
      if (!verificado) {
        // Mostrar dialogo para ingresar motivo
        motivo = await _mostrarDialogoMotivo(usuario);
        if (motivo == null) return; // Usuario cancelo
      }

      final resultado = await SeguridadService.cambiarEstadoVerificacion(
        capitanId: usuario.id,
        verificado: verificado,
        motivo: motivo,
      );

      if (resultado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capitan ${verificado ? 'verificado' : 'desverificado'} exitosamente'),
            backgroundColor: verificado ? _verdeBrillante : _naranjaIntenso,
          ),
        );
        _cargarDatos(); // Recargar datos
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _rojoFuerte,
        ),
      );
    }
  }

  Future<String?> _mostrarDialogoMotivo(GestionUsuario usuario) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Motivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Por favor ingresa el motivo para esta accion:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ingresa el motivo...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        // Filtro de tipo de accion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fondoOscuro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blancoPuro.withOpacity(0.2)),
          ),
          child: DropdownButton<String>(
            value: _filtroTipoAccion,
            onChanged: (value) {
              setState(() {
                _filtroTipoAccion = value!;
              });
            },
            items: [
              DropdownMenuItem(value: 'todos', child: Text('Todos los logs')),
              DropdownMenuItem(value: 'baneo', child: Text('Baneos')),
              DropdownMenuItem(value: 'desbaneo', child: Text('Desbaneos')),
              DropdownMenuItem(value: 'verificacion', child: Text('Verificaciones')),
              DropdownMenuItem(value: 'desverificacion', child: Text('Desverificaciones')),
            ],
            dropdownColor: _fondoOscuro,
            style: TextStyle(color: _blancoPuro),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista de logs
        Expanded(
          child: ListView.builder(
            itemCount: _logsFiltrados.length,
            itemBuilder: (context, index) {
              final log = _logsFiltrados[index];
              return _buildLogCard(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(LogAuditoria log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getAccionIcon(log.tipoAccion),
                color: _getAccionColor(log.tipoAccion),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.tipoAccion.toUpperCase(),
                  style: TextStyle(
                    color: _getAccionColor(log.tipoAccion),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatDateSeguridad(log.creadoAt),
                style: TextStyle(
                  color: _blancoPuro.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log.detalles,
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Admin: ${log.adminEmail}',
                style: TextStyle(
                  color: _blancoPuro.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              if (log.usuarioAfectadoEmail != null) ...[
                const SizedBox(width: 16),
                Text(
                  'Usuario: ${log.usuarioAfectadoEmail}',
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAccionIcon(String tipoAccion) {
    switch (tipoAccion) {
      case 'baneo':
        return Icons.block;
      case 'desbaneo':
        return Icons.check_circle;
      case 'verificacion':
        return Icons.verified;
      case 'desverificacion':
        return Icons.verified_user;
      default:
        return Icons.info;
    }
  }

  Color _getAccionColor(String tipoAccion) {
    switch (tipoAccion) {
      case 'baneo':
        return _rojoFuerte;
      case 'desbaneo':
        return _verdeBrillante;
      case 'verificacion':
        return _azulVibrante;
      case 'desverificacion':
        return _naranjaIntenso;
      default:
        return _grisMedio;
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.security, color: _blancoPuro),
            const SizedBox(width: 8),
            Text(
              'Seguridad',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blancoPuro,
          labelColor: _blancoPuro,
          unselectedLabelColor: _blancoPuro.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Estadisticas', icon: Icon(Icons.dashboard)),
            Tab(text: 'Usuarios', icon: Icon(Icons.people)),
            Tab(text: 'Capitanes', icon: Icon(Icons.anchor)),
            Tab(text: 'Moderacion', icon: Icon(Icons.security)),
            Tab(text: 'Logs', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando datos de seguridad...',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Estadisticas
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildEstadisticasCard(),
                ),
                // Usuarios
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildGestionUsuariosTab(),
                ),
                // Capitanes
                _buildCapitanesTab(),
                // Moderacion
                _buildModeracionTab(),
                // Logs
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildLogsTab(),
                ),
              ],
            ),
    );
  }

  Widget _buildCapitanesTab() {
    final capitanesPendientes = _usuarios.where((u) => 
      u.rol == 'capitan' && !u.verificado && u.estadoCuenta == 'activo'
    ).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fondoOscuro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blancoPuro.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.anchor, color: _naranjaIntenso),
              const SizedBox(width: 8),
              Text(
                'Capitanes Pendientes de Verificacion',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _naranjaIntenso.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${capitanesPendientes.length}',
                  style: TextStyle(
                    color: _naranjaIntenso,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Expanded(
          child: capitanesPendientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, color: _verdeBrillante, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No hay capitanes pendientes de verificacion',
                        style: TextStyle(
                          color: _blancoPuro.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: capitanesPendientes.length,
                  itemBuilder: (context, index) {
                    final capitan = capitanesPendientes[index];
                    return _buildCapitanPendienteCard(capitan);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCapitanPendienteCard(GestionUsuario capitan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranjaIntenso.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: _naranjaIntenso, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  capitan.nombre,
                  style: TextStyle(
                    color: _blancoPuro,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _naranjaIntenso.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Pendiente',
                  style: TextStyle(
                    color: _naranjaIntenso,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            capitan.email,
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SafeElevatedIconButton(
                  onPressed: () => _cambiarVerificacion(capitan, true),
                  icon: Icons.verified,
                  iconColor: _blancoPuro,
                  label: 'Verificar',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeBrillante,
                    foregroundColor: _blancoPuro,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeElevatedIconButton(
                  onPressed: () => _cambiarVerificacion(capitan, false),
                  icon: Icons.close,
                  iconColor: _blancoPuro,
                  label: 'Rechazar',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rojoFuerte,
                    foregroundColor: _blancoPuro,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeracionTab() {
    return Column(
      children: [
        // Header de moderacion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fondoOscuro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: _rojoFuerte),
              const SizedBox(width: 8),
              Text(
                'Alertas de Moderacion',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _rojoFuerte.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_alertas.where((a) => a.estado == 'pendiente').length}',
                  style: TextStyle(
                    color: _rojoFuerte,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista de alertas
        Expanded(
          child: _alertas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, color: _verdeBrillante, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No hay alertas de seguridad',
                        style: TextStyle(
                          color: _blancoPuro.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _alertas.length,
                  itemBuilder: (context, index) {
                    final alerta = _alertas[index];
                    return _buildAlertaCard(alerta);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlertaCard(AlertaSeguridad alerta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAlertaColor(alerta.tipoAlerta).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getAlertaIcon(alerta.tipoAlerta),
                color: _getAlertaColor(alerta.tipoAlerta),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alerta.tipoAlerta.toUpperCase(),
                  style: TextStyle(
                    color: _getAlertaColor(alerta.tipoAlerta),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeveridadColor(alerta.severidad).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'S: ${alerta.severidad.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: _getSeveridadColor(alerta.severidad),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alerta.patronDetectado,
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"${alerta.mensajeDetectado}"',
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.6),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDateSeguridad(alerta.fechaDeteccion),
                style: TextStyle(
                  color: _blancoPuro.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getEstadoColor(alerta.estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alerta.estado.toUpperCase(),
                  style: TextStyle(
                    color: _getEstadoColor(alerta.estado),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SafeElevatedIconButton(
                  onPressed: () => _revisarAlerta(alerta),
                  icon: Icons.visibility,
                  iconSize: 16,
                  iconColor: _blancoPuro,
                  label: 'Revisar',
                  textStyle: const TextStyle(fontSize: 12, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulVibrante,
                    foregroundColor: _blancoPuro,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeElevatedIconButton(
                  onPressed: () => _resolverAlerta(alerta),
                  icon: Icons.check,
                  iconSize: 16,
                  iconColor: _blancoPuro,
                  label: 'Resolver',
                  textStyle: const TextStyle(fontSize: 12, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeBrillante,
                    foregroundColor: _blancoPuro,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAlertaColor(String tipoAlerta) {
    switch (tipoAlerta) {
      case 'evasion_comision':
        return _naranjaIntenso;
      case 'contacto_directo':
        return _azulVibrante;
      case 'fraude':
        return _rojoFuerte;
      default:
        return _grisMedio;
    }
  }

  IconData _getAlertaIcon(String tipoAlerta) {
    switch (tipoAlerta) {
      case 'evasion_comision':
        return Icons.money_off;
      case 'contacto_directo':
        return Icons.phone;
      case 'fraude':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getSeveridadColor(double severidad) {
    if (severidad >= 0.8) return _rojoFuerte;
    if (severidad >= 0.6) return _naranjaIntenso;
    return _azulVibrante;
  }

  Future<void> _revisarAlerta(AlertaSeguridad alerta) async {
    final controller = TextEditingController();
    
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revisar Alerta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tipo: ${alerta.tipoAlerta}'),
            Text('Severidad: ${alerta.severidad.toStringAsFixed(1)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Notas del administrador',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await ModeracionService.marcarAlertaRevisada(alerta.id, resultado);
      _cargarDatos(); // Recargar datos
    }
  }

  Future<void> _resolverAlerta(AlertaSeguridad alerta) async {
    final controller = TextEditingController();
    
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolver Alerta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tipo: ${alerta.tipoAlerta}'),
            Text('Severidad: ${alerta.severidad.toStringAsFixed(1)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Resolucion',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Resolver'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await ModeracionService.resolverAlerta(alerta.id, resultado);
      _cargarDatos(); // Recargar datos
    }
  }

  String _formatDateSeguridad(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
