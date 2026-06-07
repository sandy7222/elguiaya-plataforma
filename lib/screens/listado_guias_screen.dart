

import 'package:flutter/material.dart';

import '../models/guia.dart';
import '../services/seguridad_service.dart';
import '../services/supabase_service.dart';
import 'registro_screen.dart';

class ListadoGuiasScreen extends StatefulWidget {
  const ListadoGuiasScreen({super.key});

  @override
  State<ListadoGuiasScreen> createState() => _ListadoGuiasScreenState();
}

class _ListadoGuiasScreenState extends State<ListadoGuiasScreen> {
  List<Guia> _guias = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarGuias();
  }

  Future<void> _cargarGuias() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final guias = await SupabaseService.getGuias();
      setState(() {
        _guias = guias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshGuias() async {
    await _cargarGuias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'CAPITAN YA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistroScreen()),
          );
          
          if (result == true) {
            _refreshGuias();
          }
        },
        backgroundColor: const Color(0xFF002366),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF002366),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar los guias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshGuias,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_guias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.anchor,
              size: 64,
              color: Color(0xFF002366),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay guias registrados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002366),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona el boton + para agregar el primero',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGuias,
      color: const Color(0xFF002366),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _guias.length,
        itemBuilder: (context, index) {
          final guia = _guias[index];
          return _GuiaCard(guia: guia);
        },
      ),
    );
  }
}

class _GuiaCard extends StatefulWidget {
  final Guia guia;

  const _GuiaCard({required this.guia});

  @override
  State<_GuiaCard> createState() => _GuiaCardState();
}

class _GuiaCardState extends State<_GuiaCard> {
  bool _esVerificado = false;
  bool _isLoadingVerificacion = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadoVerificacion();
  }

  Future<void> _cargarEstadoVerificacion() async {
    try {
      // Intentar obtener el estado de verificacion del capitan
      // Usamos el ID del guia como referencia (asumiendo que corresponde a un capitan)
      final usuario = await SeguridadService.getUsuarioPorId(widget.guia.id.toString());
      if (usuario != null) {
        setState(() {
          _esVerificado = usuario.verificado;
          _isLoadingVerificacion = false;
        });
      } else {
        setState(() {
          _isLoadingVerificacion = false;
        });
      }
    } catch (e) {
      // Si hay error, asumimos que no esta verificado
      setState(() {
        _esVerificado = false;
        _isLoadingVerificacion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFF8F9FA),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF002366),
                    radius: 24,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.guia.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF002366),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Icono de verificacion
                            if (_isLoadingVerificacion)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              )
                            else if (_esVerificado)
                              Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DNI: ${widget.guia.dni}',
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.location_on,
                      label: 'Localidad',
                      value: widget.guia.localidad,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.set_meal,
                      label: 'Especialidad',
                      value: widget.guia.especialidad,
                    ),
                  ),
                ],
              ),
              if (widget.guia.telefono.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoItem(
                  icon: Icons.phone,
                  label: 'Telefono',
                  value: widget.guia.telefono,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF002366),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value.isNotEmpty ? value : 'No especificado',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
