

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/safe_button.dart';

import '../services/disponibilidad_service.dart';
import '../services/supabase_service.dart';

class CalendarioDisponibilidadScreen extends StatefulWidget {
  const CalendarioDisponibilidadScreen({super.key});

  @override
  State<CalendarioDisponibilidadScreen> createState() => _CalendarioDisponibilidadScreenState();
}

class _CalendarioDisponibilidadScreenState extends State<CalendarioDisponibilidadScreen> {
  DateTime _mesActual = DateTime.now();
  Map<String, bool> _calendario = {};
  bool _isLoading = false;
  bool _resolviendoCapitan = true;
  String? _capitanId;

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
    _initCapitanId();
  }

  Future<void> _initCapitanId() async {
    _capitanId = DisponibilidadService.getCapitanIdActual();
    if (_capitanId == null) {
      final esCapitan = await SupabaseService.resolveEsCapitan();
      if (esCapitan && mounted) {
        _capitanId = SupabaseService.currentUserId;
      }
    }
    if (!mounted) return;
    setState(() => _resolviendoCapitan = false);
    if (_capitanId != null) {
      await _cargarCalendario();
    }
  }

  Future<void> _cargarCalendario() async {
    if (_capitanId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final calendario = await DisponibilidadService.generarCalendarioMensual(
        _capitanId!,
        _mesActual.year,
        _mesActual.month,
      );

      if (mounted) {
        setState(() {
          _calendario = calendario;
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
            content: Text('Error al cargar calendario: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  void _cambiarMes(int direccion) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + direccion, 1);
    });
    _cargarCalendario();
  }

  Future<void> _toggleDia(int dia) async {
    if (_capitanId == null) return;

    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
    final estadoActual = _calendario[dia.toString()] ?? true;
    final nuevoEstado = !estadoActual;

    try {
      await DisponibilidadService.actualizarDisponibilidad(
        capitanId: _capitanId!,
        fecha: fecha,
        estaBloqueado: !nuevoEstado,
        motivoBloqueo: nuevoEstado ? null : 'Bloqueado manualmente',
      );

      // Actualizar estado local
      setState(() {
        _calendario[dia.toString()] = nuevoEstado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado ? 'Dia habilitado' : 'Dia bloqueado',
            ),
            backgroundColor: nuevoEstado ? _verdeBrillante : _naranjaIntenso,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar dia: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Future<void> _bloquearSemana() async {
    if (_capitanId == null) return;

    final hoy = DateTime.now();
    final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
    final fechas = <DateTime>[];

    for (int i = 0; i < 7; i++) {
      fechas.add(inicioSemana.add(Duration(days: i)));
    }

    try {
      final count = await DisponibilidadService.bloquearFechasMultiples(
        capitanId: _capitanId!,
        fechas: fechas,
        motivo: 'Bloqueo semanal',
      );

      await _cargarCalendario();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count dias bloqueados esta semana'),
            backgroundColor: _naranjaIntenso,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al bloquear semana: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Future<void> _desbloquearMes() async {
    if (_capitanId == null) return;

    final diasBloqueados = <DateTime>[];
    _calendario.forEach((dia, disponible) {
      if (!disponible) {
        diasBloqueados.add(DateTime(_mesActual.year, _mesActual.month, int.parse(dia)));
      }
    });

    if (diasBloqueados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay dias bloqueados este mes'),
            backgroundColor: _grisMedio,
          ),
        );
      }
      return;
    }

    try {
      final count = await DisponibilidadService.desbloquearFechasMultiples(
        capitanId: _capitanId!,
        fechas: diasBloqueados,
      );

      await _cargarCalendario();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count dias desbloqueados'),
            backgroundColor: _verdeBrillante,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desbloquear mes: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        border: Border(
          bottom: BorderSide(color: _blancoPuro.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _cambiarMes(-1),
                icon: Icon(Icons.chevron_left, color: _blancoPuro),
              ),
              Text(
                DateFormat('MMMM yyyy', 'es').format(_mesActual).toUpperCase(),
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => _cambiarMes(1),
                icon: Icon(Icons.chevron_right, color: _blancoPuro),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDiaSemana('LUN'),
              _buildDiaSemana('MAR'),
              _buildDiaSemana('MIE'),
              _buildDiaSemana('JUE'),
              _buildDiaSemana('VIE'),
              _buildDiaSemana('SAB'),
              _buildDiaSemana('DOM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiaSemana(String dia) {
    return Container(
      width: 40,
      height: 30,
      alignment: Alignment.center,
      child: Text(
        dia,
        style: TextStyle(
          color: _blancoPuro.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCalendario() {
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final ultimoDia = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final diasEnMes = ultimoDia.day;
    final primerDiaSemana = primerDia.weekday == 0 ? 7 : primerDia.weekday;

    return Expanded(
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 42, // 6 semanas * 7 dias
              itemBuilder: (context, index) {
                final diaNumero = index - primerDiaSemana + 2;
                
                if (diaNumero < 1 || diaNumero > diasEnMes) {
                  return Container(); // Dias vacios
                }

                final estaDisponible = _calendario[diaNumero.toString()] ?? true;
                final esHoy = _esHoy(diaNumero);
                final esPasado = _esPasado(diaNumero);

                return GestureDetector(
                  onTap: esPasado ? null : () => _toggleDia(diaNumero),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDiaColor(estaDisponible, esHoy, esPasado),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: esHoy ? _azulVibrante : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (!esPasado)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            diaNumero.toString(),
                            style: TextStyle(
                              color: _getTextoColor(estaDisponible, esHoy, esPasado),
                              fontSize: 16,
                              fontWeight: esHoy ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!estaDisponible && !esPasado)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _rojoFuerte,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getDiaColor(bool disponible, bool esHoy, bool esPasado) {
    if (esPasado) {
      return _grisMedio.withOpacity(0.3);
    }
    if (!disponible) {
      return _rojoFuerte.withOpacity(0.2);
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.2);
    }
    return _verdeBrillante.withOpacity(0.2);
  }

  Color _getTextoColor(bool disponible, bool esHoy, bool esPasado) {
    if (esPasado) {
      return _grisMedio.withOpacity(0.5);
    }
    if (!disponible) {
      return _rojoFuerte;
    }
    if (esHoy) {
      return _azulVibrante;
    }
    return _verdeBrillante;
  }

  bool _esHoy(int dia) {
    final hoy = DateTime.now();
    return hoy.year == _mesActual.year &&
           hoy.month == _mesActual.month &&
           hoy.day == dia;
  }

  bool _esPasado(int dia) {
    final fechaDia = DateTime(_mesActual.year, _mesActual.month, dia);
    final hoy = DateTime.now();
    return fechaDia.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        border: Border(
          top: BorderSide(color: _blancoPuro.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SafeElevatedIconButton(
  onPressed: _bloquearSemana,
  icon: Icons.block,
  iconColor: _blancoPuro,
  label: 'Bloquear Semana',
  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranjaIntenso,
                    foregroundColor: _blancoPuro,
                  ),
),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeElevatedIconButton(
  onPressed: _desbloquearMes,
  icon: Icons.check_circle,
  iconColor: _blancoPuro,
  label: 'Desbloquear Mes',
  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeBrillante,
                    foregroundColor: _blancoPuro,
                  ),
),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _verdeBrillante.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _verdeBrillante,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Disponible',
                        style: TextStyle(
                          color: _verdeBrillante,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rojoFuerte.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _rojoFuerte,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bloqueado',
                        style: TextStyle(
                          color: _rojoFuerte,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoCapitan) {
      return Scaffold(
        backgroundColor: _fondoOscuro,
        body: Center(
          child: CircularProgressIndicator(color: _blancoPuro),
        ),
      );
    }

    if (_capitanId == null) {
      return Scaffold(
        backgroundColor: _fondoOscuro,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: _rojoFuerte,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No tienes permisos de capitan',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: _blancoPuro),
            const SizedBox(width: 8),
            Text(
              'Calendario de Disponibilidad',
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
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildCalendario(),
          _buildActions(),
        ],
      ),
    );
  }
}
