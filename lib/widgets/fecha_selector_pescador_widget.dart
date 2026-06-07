

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/disponibilidad_service_final.dart';

class FechaSelectorPescadorWidget extends StatefulWidget {
  final String capitanId;
  final Function(DateTime) onFechaSeleccionada;
  final DateTime? fechaInicial;
  final DateTime? fechaMinima;
  final DateTime? fechaMaxima;

  const FechaSelectorPescadorWidget({
    super.key,
    required this.capitanId,
    required this.onFechaSeleccionada,
    this.fechaInicial,
    this.fechaMinima,
    this.fechaMaxima,
  });

  @override
  State<FechaSelectorPescadorWidget> createState() => _FechaSelectorPescadorWidgetState();
}

class _FechaSelectorPescadorWidgetState extends State<FechaSelectorPescadorWidget> {
  DateTime _mesActual = DateTime.now();
  Map<String, String> _tiposDia = {}; // 'disponible', 'bloqueo_manual', 'reserva'
  bool _isLoading = false;
  DateTime? _fechaSeleccionada;
  StreamSubscription? _disponibilidadSubscription;

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
    _escucharDisponibilidadRealtime();
  }

  @override
  void dispose() {
    _disponibilidadSubscription?.cancel();
    super.dispose();
  }

  void _cargarDisponibilidad() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fechasBloqueadas = await DisponibilidadServiceFinal.getFechasBloqueadas(
        widget.capitanId,
        fechaInicio: DateTime(_mesActual.year, _mesActual.month, 1),
        fechaFin: DateTime(_mesActual.year, _mesActual.month + 1, 0),
      );

      final tipos = <String, String>{};
      for (final bloqueo in fechasBloqueadas) {
        final fecha = DateTime.parse(bloqueo['fecha']);
        tipos[fecha.day.toString()] = bloqueo['tipo'] ?? 'bloqueo_manual';
      }

      if (mounted) {
        setState(() {
          _tiposDia = tipos;
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

  void _escucharDisponibilidadRealtime() {
    _disponibilidadSubscription = DisponibilidadServiceFinal
        .getFechasBloqueadasStream(widget.capitanId)
        .listen((fechasBloqueadas) {
      final tipos = <String, String>{};
      for (final bloqueo in fechasBloqueadas) {
        if (bloqueo.fecha.year == _mesActual.year && 
            bloqueo.fecha.month == _mesActual.month) {
          tipos[ bloqueo.fecha.day.toString()] = bloqueo.tipo;
        }
      }

      if (mounted) {
        setState(() {
          _tiposDia = tipos;
        });
      }
    });
  }

  void _cambiarMes(int direccion) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + direccion, 1);
    });
    _cargarDisponibilidad();
  }

  bool _puedeSeleccionarFecha(int dia) {
    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
    final tipoDia = _tiposDia[dia.toString()] ?? 'disponible';
    
    // Verificar si esta disponible
    if (tipoDia != 'disponible') return false;
    
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
    if (!_puedeSeleccionarFecha(dia)) {
      // Mostrar mensaje de por que no se puede seleccionar
      final tipoDia = _tiposDia[dia.toString()] ?? 'disponible';
      String mensaje = 'Fecha no disponible';
      
      if (tipoDia == 'bloqueo_manual') {
        mensaje = 'Dia bloqueado por el capitan';
      } else if (tipoDia == 'reserva') {
        mensaje = 'Dia ya reservado';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: _naranjaIntenso,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
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

                final tipoDia = _tiposDia[diaNumero.toString()] ?? 'disponible';
                final esHoy = _esHoy(diaNumero);
                final esPasado = _esPasado(diaNumero);
                final esSeleccionado = _esSeleccionado(diaNumero);
                final puedeSeleccionar = _puedeSeleccionarFecha(diaNumero);

                return GestureDetector(
                  onTap: () => _seleccionarFecha(diaNumero),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDiaColor(tipoDia, esHoy, esPasado, esSeleccionado),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getBorderColor(tipoDia, esHoy, esSeleccionado),
                        width: _getBorderWidth(tipoDia, esHoy, esSeleccionado),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            diaNumero.toString(),
                            style: TextStyle(
                              color: _getTextoColor(tipoDia, esHoy, esPasado, esSeleccionado),
                              fontSize: 14,
                              fontWeight: _getFontWeight(tipoDia, esHoy, esSeleccionado),
                            ),
                          ),
                        ),
                        if (tipoDia == 'bloqueo_manual' && !esPasado)
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
                        if (tipoDia == 'reserva' && !esPasado)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 6,
                              height: 6,
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

  Color _getDiaColor(String tipo, bool esHoy, bool esPasado, bool esSeleccionado) {
    if (esSeleccionado) {
      return _azulVibrante;
    }
    if (esPasado) {
      return _grisMedio.withOpacity(0.2);
    }
    if (tipo == 'bloqueo_manual') {
      return _rojoFuerte.withOpacity(0.15);
    }
    if (tipo == 'reserva') {
      return _naranjaIntenso.withOpacity(0.15);
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.15);
    }
    return _verdeBrillante.withOpacity(0.15);
  }

  Color _getBorderColor(String tipo, bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
      return _azulVibrante;
    }
    if (tipo == 'bloqueo_manual') {
      return _rojoFuerte.withOpacity(0.5);
    }
    if (tipo == 'reserva') {
      return _naranjaIntenso.withOpacity(0.5);
    }
    if (esHoy) {
      return _azulVibrante.withOpacity(0.5);
    }
    return Colors.transparent;
  }

  double _getBorderWidth(String tipo, bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
      return 2;
    }
    if (tipo == 'bloqueo_manual' || tipo == 'reserva') {
      return 1;
    }
    if (esHoy) {
      return 1;
    }
    return 0;
  }

  Color _getTextoColor(String tipo, bool esHoy, bool esPasado, bool esSeleccionado) {
    if (esSeleccionado) {
      return _blancoPuro;
    }
    if (esPasado) {
      return _grisMedio.withOpacity(0.4);
    }
    if (tipo == 'bloqueo_manual') {
      return _rojoFuerte.withOpacity(0.6);
    }
    if (tipo == 'reserva') {
      return _naranjaIntenso.withOpacity(0.6);
    }
    if (esHoy) {
      return _azulVibrante;
    }
    return _verdeBrillante;
  }

  FontWeight _getFontWeight(String tipo, bool esHoy, bool esSeleccionado) {
    if (esSeleccionado) {
      return FontWeight.bold;
    }
    if (tipo == 'bloqueo_manual' || tipo == 'reserva') {
      return FontWeight.w500;
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
          _buildLegendItem('Reservado', _naranjaIntenso),
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
            fontSize: 10,
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
