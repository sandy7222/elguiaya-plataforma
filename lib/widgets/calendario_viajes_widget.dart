import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class CalendarioViajesWidget extends StatefulWidget {
  final String capitanId;
  final bool initialCollapsed;

  const CalendarioViajesWidget({
    super.key,
    required this.capitanId,
    this.initialCollapsed = true,
  });

  @override
  State<CalendarioViajesWidget> createState() => _CalendarioViajesWidgetState();
}

class _CalendarioViajesWidgetState extends State<CalendarioViajesWidget> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  
  Map<DateTime, List<Map<String, dynamic>>> _viajesPorDia = {};
  bool _isLoading = true;
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initialCollapsed;
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _cargarViajes();
  }

  Future<void> _cargarViajes() async {
    try {
      // Cargamos únicamente los pedidos que estén 'pagados' y no cancelados
      // Esto representa exactamente los cierres pagados que esperan fecha de zarpe
      final response = await SupabaseService.supabase
          .from('pedidos')
          .select('*, profiles:pescador_id(nombre)')
          .eq('capitan_id', widget.capitanId)
          .eq('estado', 'pagado');

      final map = <DateTime, List<Map<String, dynamic>>>{};
      
      for (var row in response) {
        if (row['fecha_servicio'] != null) {
          final fechaStr = row['fecha_servicio'].toString();
          if (fechaStr.isNotEmpty) {
            try {
              final fecha = DateTime.parse(fechaStr);
              // Normalizamos a la fecha UTC sin horas para usar de llave
              final diaNormalizado = DateTime.utc(fecha.year, fecha.month, fecha.day);
              
              if (map[diaNormalizado] == null) {
                map[diaNormalizado] = [];
              }
              map[diaNormalizado]!.add(row);
            } catch (e) {
              print('Error parseando fecha: $fechaStr');
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _viajesPorDia = map;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando calendario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final diaNormalizado = DateTime.utc(day.year, day.month, day.day);
    return _viajesPorDia[diaNormalizado] ?? [];
  }

  // Obtiene la lista plana de todos los viajes pagados ordenados por fecha
  List<Map<String, dynamic>> get _todosViajesPagados {
    final list = <Map<String, dynamic>>[];
    for (var viajes in _viajesPorDia.values) {
      list.addAll(viajes);
    }
    list.sort((a, b) {
      final fA = a['fecha_servicio'] != null ? DateTime.parse(a['fecha_servicio'].toString()) : DateTime.now();
      final fB = b['fecha_servicio'] != null ? DateTime.parse(b['fecha_servicio'].toString()) : DateTime.now();
      return fA.compareTo(fB);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ));
    }

    final eventosDiaActual = _getEventsForDay(_selectedDay ?? _focusedDay);
    final todosViajes = _todosViajesPagados;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Toggleable (Plegable)
          InkWell(
            onTap: () {
              setState(() {
                _isCollapsed = !_isCollapsed;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF001F3F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Almanaque de Reservas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          if (_isCollapsed)
            // Vista Plegada: Resumen compacto de agenda
            InkWell(
              onTap: () {
                setState(() {
                  _isCollapsed = false;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sailing_rounded, color: Color(0xFF001F3F), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        todosViajes.isEmpty
                            ? 'Sin viajes pagados pendientes en agenda.'
                            : 'Tienes ${todosViajes.length} viaje(s) confirmado(s) por zarpar.',
                        style: const TextStyle(
                          color: Color(0xFF001F3F),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Ver Calendario',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Vista Desplegada: Almanaque compacto + detalle del día
            TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              rowHeight: 38.0, // Altura de fila compacta (achicado)
              daysOfWeekHeight: 20.0, // Cabecera de días compacta
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mes',
              },
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left, size: 20, color: Color(0xFF001F3F)),
                rightChevronIcon: Icon(Icons.chevron_right, size: 20, color: Color(0xFF001F3F)),
                titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF001F3F)),
                headerPadding: EdgeInsets.symmetric(vertical: 4.0),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                weekendStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(fontSize: 11),
                weekendTextStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
                outsideTextStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                todayTextStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                selectedTextStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF001F3F).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF001F3F),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            
            // Panel inferior con los detalles del día seleccionado
            if (eventosDiaActual.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reservas para el ${DateFormat('dd/MM/yyyy').format(_selectedDay ?? _focusedDay)}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF001F3F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...eventosDiaActual.map((viaje) {
                      final nombre = viaje['profiles']?['nombre'] ?? 'Pescador';
                      final fechaServicio = viaje['fecha_servicio'] != null 
                          ? DateTime.parse(viaje['fecha_servicio'].toString()) 
                          : null;
                      final horaFormateada = fechaServicio != null 
                          ? DateFormat('HH:mm').format(fechaServicio) 
                          : '--:--';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_boat, color: Color(0xFF00E676), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cliente: $nombre',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    'Hora de Zarpe: $horaFormateada hs',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.grey[400], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Día sin reservas confirmadas.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
