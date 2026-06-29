import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/disponibilidad_service_final.dart';
import '../services/supabase_service.dart';
import 'safe_button.dart';

/// Calendario de bloqueo/desbloqueo de días del capitán (embeddable en scroll).
class BloqueoAlmanaqueWidget extends StatefulWidget {
  final String? capitanId;

  const BloqueoAlmanaqueWidget({super.key, this.capitanId});

  @override
  State<BloqueoAlmanaqueWidget> createState() => _BloqueoAlmanaqueWidgetState();
}

class _BloqueoAlmanaqueWidgetState extends State<BloqueoAlmanaqueWidget> {
  DateTime _mesActual = DateTime.now();
  Map<String, bool> _calendario = {};
  Map<String, String> _tiposDia = {};
  bool _isLoading = false;
  bool _resolviendoCapitan = true;
  String? _capitanId;

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
    _initCapitanId();
  }

  Future<void> _initCapitanId() async {
    _capitanId = widget.capitanId ?? DisponibilidadServiceFinal.getCapitanIdActual();
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

    setState(() => _isLoading = true);

    try {
      final calendario = await DisponibilidadServiceFinal.generarCalendarioMensual(
        _capitanId!,
        _mesActual.year,
        _mesActual.month,
      );

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
        setState(() => _isLoading = false);
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

    final estadoActual = _calendario[dia.toString()] ?? true;
    final tipoActual = _tiposDia[dia.toString()] ?? 'disponible';

    if (tipoActual == 'reserva') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No puedes modificar una fecha ya reservada'),
            backgroundColor: _naranjaIntenso,
          ),
        );
      }
      return;
    }

    final fecha = DateTime(_mesActual.year, _mesActual.month, dia);

    try {
      if (estadoActual) {
        await DisponibilidadServiceFinal.bloquearFecha(
          fecha,
          'Bloqueado manualmente desde calendario',
        );
        setState(() {
          _calendario[dia.toString()] = false;
          _tiposDia[dia.toString()] = 'bloqueo_manual';
        });
      } else {
        await DisponibilidadServiceFinal.desbloquearFecha(fecha);
        setState(() {
          _calendario[dia.toString()] = true;
          _tiposDia.remove(dia.toString());
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(estadoActual ? 'Dia bloqueado' : 'Dia desbloqueado'),
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
    var bloqueados = 0;

    for (var i = 0; i < 7; i++) {
      try {
        await DisponibilidadServiceFinal.bloquearFecha(
          inicioSemana.add(Duration(days: i)),
          'Bloqueo semanal automatico',
        );
        bloqueados++;
      } catch (e) {
        debugPrint('Error bloqueando fecha: $e');
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
            content: const Text('No hay dias bloqueados este mes'),
            backgroundColor: _grisMedio,
          ),
        );
      }
      return;
    }

    var desbloqueados = 0;
    for (final fecha in diasBloqueados) {
      try {
        await DisponibilidadServiceFinal.desbloquearFecha(fecha);
        desbloqueados++;
      } catch (e) {
        debugPrint('Error desbloqueando fecha: $e');
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

  Widget _buildDiaSemana(String dia) {
    return SizedBox(
      width: 40,
      height: 30,
      child: Center(
        child: Text(
          dia,
          style: TextStyle(
            color: _blancoPuro.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
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
                style: const TextStyle(
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

  Widget _buildCalendarioGrid() {
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final ultimoDia = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final diasEnMes = ultimoDia.day;
    final primerDiaSemana = primerDia.weekday == 0 ? 7 : primerDia.weekday;

    if (_isLoading) {
      return SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          final diaNumero = index - primerDiaSemana + 2;

          if (diaNumero < 1 || diaNumero > diasEnMes) {
            return const SizedBox.shrink();
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
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      diaNumero.toString(),
                      style: TextStyle(
                        color: _getTextoColor(estaDisponible, tipoDia, esHoy, esPasado),
                        fontSize: 14,
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
                        decoration: const BoxDecoration(
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
                        decoration: const BoxDecoration(
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
    if (esPasado) return _grisMedio.withOpacity(0.3);
    if (tipo == 'reserva') return _naranjaIntenso.withOpacity(0.2);
    if (!disponible) return _rojoFuerte.withOpacity(0.2);
    if (esHoy) return _azulVibrante.withOpacity(0.2);
    return _verdeBrillante.withOpacity(0.2);
  }

  Color _getBorderColor(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva') return _naranjaIntenso;
    if (!disponible) return _rojoFuerte;
    if (esHoy) return _azulVibrante;
    return Colors.transparent;
  }

  double _getBorderWidth(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva' || !disponible) return 2;
    if (esHoy) return 1;
    return 0;
  }

  Color _getTextoColor(bool disponible, String tipo, bool esHoy, bool esPasado) {
    if (esPasado) return _grisMedio.withOpacity(0.5);
    if (tipo == 'reserva') return _naranjaIntenso;
    if (!disponible) return _rojoFuerte;
    if (esHoy) return _azulVibrante;
    return _verdeBrillante;
  }

  FontWeight _getFontWeight(bool disponible, String tipo, bool esHoy) {
    if (tipo == 'reserva' || !disponible) return FontWeight.bold;
    if (esHoy) return FontWeight.w600;
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
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
                  onPressed: _bloquearSemanaActual,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLeyenda(_verdeBrillante, 'Disponible')),
              const SizedBox(width: 8),
              Expanded(child: _buildLeyenda(_rojoFuerte, 'Bloqueado')),
              const SizedBox(width: 8),
              Expanded(child: _buildLeyenda(_naranjaIntenso, 'Reservado')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeyenda(Color color, String label) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoCapitan) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    if (_capitanId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _fondoOscuro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, color: _rojoFuerte, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No tienes permisos de capitan',
                style: TextStyle(color: _blancoPuro, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildCalendarioGrid(),
          _buildActions(),
        ],
      ),
    );
  }
}
