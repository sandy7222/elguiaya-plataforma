

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/disponibilidad_service.dart';

class FechaSelectorWidget extends StatefulWidget {
  final String capitanId;
  final Function(DateTime) onFechaSeleccionada;
  final DateTime? fechaInicial;
  final DateTime? fechaMinima;
  final DateTime? fechaMaxima;

  const FechaSelectorWidget({
    super.key,
    required this.capitanId,
    required this.onFechaSeleccionada,
    this.fechaInicial,
    this.fechaMinima,
    this.fechaMaxima,
  });

  @override
  State<FechaSelectorWidget> createState() => _FechaSelectorWidgetState();
}

class _FechaSelectorWidgetState extends State<FechaSelectorWidget> {
  DateTime _mesActual = DateTime.now();
  Map<String, bool> _disponibilidad = {};
  bool _isLoading = false;
  DateTime? _fechaSeleccionada;

  // Colores
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
    _fechaSeleccionada = widget.fechaInicial;
    _cargarDisponibilidad();
  }

  Future<void> _cargarDisponibilidad() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final disponibilidad = await DisponibilidadService.generarCalendarioMensual(
        widget.capitanId,
        _mesActual.year,
        _mesActual.month,
      );

      if (mounted) {
        setState(() {
          _disponibilidad = disponibilidad;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cambiarMes(int direccion) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + direccion, 1);
    });
    _cargarDisponibilidad();
  }

  bool _puedeSeleccionarFecha(int dia) {
    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
    
    // Verificar si esta disponible
    final disponible = _disponibilidad[dia.toString()] ?? true;
    if (!disponible) return false;
    
    // Verificar si es pasado
    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    if (fecha.isBefore(fechaHoy)) return false;
    
    // Verificar fecha minima
    if (widget.fechaMinima != null && fecha.isBefore(widget.fechaMinima!)) {
      return false;
    }
    
    // Verificar fecha maxima
    if (widget.fechaMaxima != null && fecha.isAfter(widget.fechaMaxima!)) {
      return false;
    }
    
    return true;
  }

  void _seleccionarFecha(int dia) {
    if (!_puedeSeleccionarFecha(dia)) return;
    
    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
    setState(() {
      _fechaSeleccionada = fecha;
    });
    widget.onFechaSeleccionada(fecha);
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => _cambiarMes(1),
                icon: Icon(Icons.chevron_right, color: _blancoPuro),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      width: 35,
      height: 25,
      alignment: Alignment.center,
      child: Text(
        dia,
        style: TextStyle(
          color: _blancoPuro.withOpacity(0.7),
          fontSize: 11,
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

    return SizedBox(
      height: 280,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 42, // 6 semanas * 7 dias
              itemBuilder: (context, index) {
                final diaNumero = index - primerDiaSemana + 2;
                
                if (diaNumero < 1 || diaNumero > diasEnMes) {
                  return Container(); // Dias vacios
                }

                final estaDisponible = _disponibilidad[diaNumero.toString()] ?? true;
                final esHoy = _esHoy(diaNumero);
                final esPasado = _esPasado(diaNumero);
                final esSeleccionado = _esSeleccionado(diaNumero);
                final puedeSeleccionar = _puedeSeleccionarFecha(diaNumero);

                return GestureDetector(
                  onTap: puedeSeleccionar ? () => _seleccionarFecha(diaNumero) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDiaColor(estaDisponible, esHoy, esPasado, esSeleccionado),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getBorderColor(esHoy, esSeleccionado),
                        width: _getBorderWidth(esHoy, esSeleccionado),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            diaNumero.toString(),
                            style: TextStyle(
                              color: _getTextoColor(estaDisponible, esHoy, esPasado, esSeleccionado),
                              fontSize: 14,
                              fontWeight: _getFontWeight(esHoy, esSeleccionado),
                            ),
                          ),
                        ),
                        if (!estaDisponible && !esPasado)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 6,
                              height: 6,
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

  Color _getDiaColor(bool disponible, bool esHoy, bool esPasado, bool esSeleccionado) {
    if (esSeleccionado) {
      return _azulVibrante;
    }
    if (esPasado) {
      return _grisMedio.withOpacity(0.2);
    }
    if (!disponible) {
      return _rojoFuerte.withOpacity(0.15);
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.15);
    }
    return _verdeBrillante.withOpacity(0.15);
  }

  Color _getBorderColor(bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
      return _azulVibrante;
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.5);
    }
    return Colors.transparent;
  }

  double _getBorderWidth(bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
      return 2;
    }
    if (esHoy) {
      return 1;
    }
    return 0;
  }

  Color _getTextoColor(bool disponible, bool esHoy, bool esPasado, bool esSeleccionado) {
    if (esSeleccionado) {
      return _blancoPuro;
    }
    if (esPasado) {
      return _grisMedio.withOpacity(0.4);
    }
    if (!disponible) {
      return _rojoFuerte.withOpacity(0.6);
    }
    if (esHoy) {
      return _azulVibrante;
    }
    return _verdeBrillante;
  }

  FontWeight _getFontWeight(bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
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

  bool _esSeleccionado(int dia) {
    if (_fechaSeleccionada == null) return false;
    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
    return fecha.year == _fechaSeleccionada!.year &&
           fecha.month == _fechaSeleccionada!.month &&
           fecha.day == _fechaSeleccionada!.day;
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        border: Border(
          top: BorderSide(color: _blancoPuro.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Disponible', _verdeBrillante),
          _buildLegendItem('Bloqueado', _rojoFuerte),
          _buildLegendItem('Seleccionado', _azulVibrante),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: _blancoPuro.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildCalendario(),
          _buildLegend(),
        ],
      ),
    );
  }
}
