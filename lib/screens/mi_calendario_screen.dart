

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/disponibilidad_service_final.dart';

class MiCalendarioScreen extends StatefulWidget {
  const MiCalendarioScreen({super.key});

  @override
  State<MiCalendarioScreen> createState() => _MiCalendarioScreenState();
}

class _MiCalendarioScreenState extends State<MiCalendarioScreen> {
  DateTime _mesActual = DateTime.now();
  Map<String, bool> _calendario = {};
  Map<String, String> _tiposDia = {}; // 'disponible', 'bloqueo_manual', 'reserva'
  bool _isLoading = false;
  String? _capitanId;

  // Colores CapitanYA - Nautical Premium Theme
  static const Color _fondoOscuro = Color(0xFF001F3F);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0D47A1);
  static const Color _verdeBrillante = Color(0xFF00E676);
  static const Color _naranjaIntenso = Color(0xFFFFB300);
  static const Color _rojoFuerte = Color(0xFFD32F2F);
  static const Color _grisMedio = Color(0xFF78909C);

  @override
  void initState() {
    super.initState();
    _capitanId = DisponibilidadServiceFinal.getCapitanIdActual();
    if (_capitanId != null) {
      _cargarCalendario();
    }
  }

  Future<void> _cargarCalendario() async {
    if (_capitanId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final calendario = await DisponibilidadServiceFinal.generarCalendarioMensual(
        _capitanId!,
        _mesActual.year,
        _mesActual.month,
      );

      // Obtener tipos de cada dia
      final disponibilidadCompleta = await DisponibilidadServiceFinal.getFechasBloqueadas(
        _capitanId!,
        fechaInicio: DateTime(_mesActual.year, _mesActual.month, 1),
        fechaFin: DateTime(_mesActual.year, _mesActual.month + 1, 0),
      );

      final tipos = <String, String>{};
      for (final bloqueo in disponibilidadCompleta) {
        final fecha = DateTime.parse(bloqueo['fecha']);
        tipos[fecha.day.toString()] = bloqueo['tipo'] ?? 'bloqueo_manual';
      }

      if (mounted) {
        setState(() {
          _calendario = calendario;
          _tiposDia = tipos;
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
    final tipoActual = _tiposDia[dia.toString()] ?? 'disponible';
    
    // No permitir modificar dias reservados
    if (tipoActual == 'reserva') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No puedes modificar una fecha ya reservada'),
            backgroundColor: _naranjaIntenso,
          ),
        );
      }
      return;
    }

    try {
      if (estadoActual) {
        // Bloquear el dia
        await DisponibilidadServiceFinal.bloquearFecha(fecha, 'Bloqueado manualmente desde calendario');
        setState(() {
          _calendario[dia.toString()] = false;
          _tiposDia[dia.toString()] = 'bloqueo_manual';
        });
      } else {
        // Desbloquear el dia
        await DisponibilidadServiceFinal.desbloquearFecha(fecha);
        setState(() {
          _calendario[dia.toString()] = true;
          _tiposDia.remove(dia.toString());
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              estadoActual ? 'Dia bloqueado' : 'Dia desbloqueado',
            ),
            backgroundColor: estadoActual ? _naranjaIntenso : _verdeBrillante,
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

  Future<void> _bloquearSemanaActual() async {
    if (_capitanId == null) return;

    final hoy = DateTime.now();
    final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
    final fechas = <DateTime>[];

    for (int i = 0; i < 7; i++) {
      fechas.add(inicioSemana.add(Duration(days: i)));
    }

    int bloqueados = 0;
    for (final fecha in fechas) {
      try {
        await DisponibilidadServiceFinal.bloquearFecha(fecha, 'Bloqueo semanal automatico');
        bloqueados++;
      } catch (e) {
        print('Error bloqueando ${fecha.toIso8601String()}: $e');
      }
    }

    await _cargarCalendario();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$bloqueados dias bloqueados esta semana'),
          backgroundColor: _naranjaIntenso,
        ),
      );
    }
  }

  Future<void> _desbloquearMes() async {
    if (_capitanId == null) return;

    final diasBloqueados = <DateTime>[];
    _tiposDia.forEach((dia, tipo) {
      if (tipo == 'bloqueo_manual') {
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

    int desbloqueados = 0;
    for (final fecha in diasBloqueados) {
      try {
        await DisponibilidadServiceFinal.desbloquearFecha(fecha);
        desbloqueados++;
      } catch (e) {
        print('Error desbloqueando ${fecha.toIso8601String()}: $e');
      }
    }

    await _cargarCalendario();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$desbloqueados dias desbloqueados'),
          backgroundColor: _verdeBrillante,
        ),
      );
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
                final tipoDia = _tiposDia[diaNumero.toString()] ?? 'disponible';
                final esHoy = _esHoy(diaNumero);
                final esPasado = _esPasado(diaNumero);

                return GestureDetector(
                  onTap: (esPasado || tipoDia == 'reserva') ? null : () => _toggleDia(diaNumero),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDiaColor(estaDisponible, tipoDia, esHoy, esPasado),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getBorderColor(estaDisponible, tipoDia, esHoy),
                        width: _getBorderWidth(estaDisponible, tipoDia, esHoy),
                      ),
                      boxShadow: [
                        if (!esPasado && tipoDia != 'reserva')
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
                              color: _getTextoColor(estaDisponible, tipoDia, esHoy, esPasado),
                              fontSize: 16,
                              fontWeight: _getFontWeight(estaDisponible, tipoDia, esHoy),
                            ),
                          ),
                        ),
                        if (tipoDia == 'bloqueo_manual' && !esPasado)
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
                        if (tipoDia == 'reserva' && !esPasado)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _naranjaIntenso,
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

  Color _getDiaColor(bool disponible, String tipo, bool esHoy, bool esPasado) {
    if (esPasado) {
      return _grisMedio.withOpacity(0.3);
    }
    if (tipo == 'reserva') {
      return _naranjaIntenso.withOpacity(0.2);
    }
    if (!disponible) {
      return _rojoFuerte.withOpacity(0.2);
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.2);
    }
    return _verdeBrillante.withOpacity(0.2);
  }

  Color _getBorderColor(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva') {
      return _naranjaIntenso;
    }
    if (!disponible) {
      return _rojoFuerte;
    }
    if (esHoy) {
      return _azulVibrante;
    }
    return Colors.transparent;
  }

  double _getBorderWidth(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva' || !disponible) {
      return 2;
    }
    if (esHoy) {
      return 1;
    }
    return 0;
  }

  Color _getTextoColor(bool disponible, String tipo, bool esHoy, bool esPasado) {
    if (esPasado) {
      return _grisMedio.withOpacity(0.5);
    }
    if (tipo == 'reserva') {
      return _naranjaIntenso;
    }
    if (!disponible) {
      return _rojoFuerte;
    }
    if (esHoy) {
      return _azulVibrante;
    }
    return _verdeBrillante;
  }

  FontWeight _getFontWeight(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva' || !disponible) {
      return FontWeight.bold;
    }
    if (esHoy) {
      return FontWeight.w600;
    }
    return FontWeight.normal;
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
                child: ElevatedButton.icon(
                  onPressed: _bloquearSemanaActual,
                  icon: Icon(Icons.block, color: _blancoPuro),
                  label: Text('Bloquear Semana'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranjaIntenso,
                    foregroundColor: _blancoPuro,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _desbloquearMes,
                  icon: Icon(Icons.check_circle, color: _blancoPuro),
                  label: Text('Desbloquear Mes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeBrillante,
                    foregroundColor: _blancoPuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
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
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
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
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _naranjaIntenso.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _naranjaIntenso,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reservado',
                        style: TextStyle(
                          color: _naranjaIntenso,
                          fontSize: 11,
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
              'Mi Calendario',
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
