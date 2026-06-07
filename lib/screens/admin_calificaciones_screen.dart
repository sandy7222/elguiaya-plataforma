import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/reputacion_badge_widget.dart';

/// Panel de calificaciones para el administrador.
/// Muestra ranking de capitanes y pescadores por reputación, 
/// listado filtrable de calificaciones y acciones de moderación.
class AdminCalificacionesScreen extends StatefulWidget {
  const AdminCalificacionesScreen({super.key});

  @override
  State<AdminCalificacionesScreen> createState() => _AdminCalificacionesScreenState();
}

class _AdminCalificacionesScreenState extends State<AdminCalificacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _calificaciones = [];
  List<Map<String, dynamic>> _rankingCapitanes = [];
  List<Map<String, dynamic>> _rankingPescadores = [];
  String _filtro = 'todos'; // 'todos' | 'criticas' | 'excelentes' | 'incidentes'

  static const Color _verde = Color(0xFF00E676);
  static const Color _azul = Color(0xFF0D47A1);
  static const Color _fondo = Color(0xFF000B21);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      // Cargar todas las calificaciones
      final cals = await Supabase.instance.client
          .from('calificaciones_viaje')
          .select('*')
          .order('created_at', ascending: false);

      final allCals = List<Map<String, dynamic>>.from(cals);

      // Calcular rankings agrupando por calificado_id
      final Map<String, List<int>> porUsuario = {};
      for (final cal in allCals) {
        final uid = cal['calificado_id']?.toString() ?? '';
        final val = cal['calificacion'] as int? ?? 0;
        if (uid.isNotEmpty) {
          porUsuario.putIfAbsent(uid, () => []).add(val);
        }
      }

      // Construir listas de ranking
      final rankingData = porUsuario.entries.map((e) {
        final promedio = e.value.fold(0, (a, b) => a + b) / e.value.length;
        return {
          'user_id': e.key,
          'promedio': promedio,
          'total': e.value.length,
          'codigo': '#${e.key.substring(0, 4).toUpperCase()}',
        };
      }).toList()
        ..sort((a, b) => (b['promedio'] as double).compareTo(a['promedio'] as double));

      // Separar ranking en capitanes y pescadores por rol de calificador
      final capIds = allCals
          .where((c) => c['calificador_rol'] == 'pescador')
          .map((c) => c['calificado_id']?.toString() ?? '')
          .toSet();
      final pescIds = allCals
          .where((c) => c['calificador_rol'] == 'capitan')
          .map((c) => c['calificado_id']?.toString() ?? '')
          .toSet();

      setState(() {
        _calificaciones = allCals;
        _rankingCapitanes = rankingData.where((r) => capIds.contains(r['user_id'])).toList();
        _rankingPescadores = rankingData.where((r) => pescIds.contains(r['user_id'])).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar calificaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _calificacionesFiltradas {
    switch (_filtro) {
      case 'criticas':
        return _calificaciones.where((c) => (c['calificacion'] as int? ?? 5) <= 2).toList();
      case 'excelentes':
        return _calificaciones.where((c) => (c['calificacion'] as int? ?? 0) == 5).toList();
      case 'incidentes':
        return _calificaciones.where((c) {
          final asp = c['aspectos_puntuados'] as Map<String, dynamic>?;
          final tags = (asp?['etiquetas'] as List?)?.cast<String>() ?? [];
          return tags.contains('INCIDENTE_REPORTADO');
        }).toList();
      default:
        return _calificaciones;
    }
  }

  Future<void> _eliminarCalificacion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Calificación', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta calificación? Quedará registrado en el log de moderación.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Supabase.instance.client.from('calificaciones_viaje').delete().eq('id', id);
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificación eliminada'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sistema de Calificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('PANEL DE ADMINISTRACIÓN', style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _verde,
          labelColor: _verde,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.anchor_rounded, size: 18), text: 'Capitanes'),
            Tab(icon: Icon(Icons.phishing_rounded, size: 18), text: 'Pescadores'),
            Tab(icon: Icon(Icons.list_rounded, size: 18), text: 'Todas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _verde))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRankingTab(_rankingCapitanes, '⚓ Ranking Capitanes'),
                _buildRankingTab(_rankingPescadores, '🎣 Ranking Pescadores'),
                _buildTodasTab(),
              ],
            ),
    );
  }

  Widget _buildRankingTab(List<Map<String, dynamic>> ranking, String titulo) {
    if (ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border_rounded, size: 48, color: Colors.white12),
            const SizedBox(height: 12),
            const Text('Sin datos de calificaciones aún', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    // Promedios globales
    final promedioGlobal = ranking.fold(0.0, (a, b) => a + (b['promedio'] as double)) / ranking.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI global
        _buildGlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKPIItem('PROMEDIO\nPLATAFORMA', '${promedioGlobal.toStringAsFixed(1)} ⚓', _verde),
              _buildKPIItem('PERFILES\nCALIFICADOS', '${ranking.length}', Colors.blueAccent),
              _buildKPIItem('TOTAL\nCALIFICACIONES', '${ranking.fold(0, (a, b) => a + (b['total'] as int))}', Colors.orangeAccent),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(titulo, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),

        ...List.generate(ranking.length, (i) {
          final item = ranking[i];
          final promedio = item['promedio'] as double;
          final total = item['total'] as int;
          final userId = item['user_id'] as String;
          final badgeColor = promedio >= 4 ? _verde : promedio >= 3 ? Colors.amber : Colors.redAccent;

          return _buildGlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            borderColor: i < 3 ? _verde.withOpacity(0.3) : null,
            child: Row(
              children: [
                // Posición
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? Colors.amber.withOpacity(0.2) : i == 1 ? Colors.white10 : Colors.white.withOpacity(0.04),
                    border: Border.all(color: i == 0 ? Colors.amber : Colors.white10),
                  ),
                  child: Center(
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(color: i == 0 ? Colors.amber : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info usuario
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userId.substring(0, 8).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text('$total calificación${total == 1 ? '' : 'es'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                // Badge de reputación
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (j) => Icon(Icons.anchor_rounded, size: 12, color: j < promedio.round() ? badgeColor : Colors.white10)),
                    ),
                    Text(promedio.toStringAsFixed(1), style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 14)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTodasTab() {
    final filtradas = _calificacionesFiltradas;

    return Column(
      children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFiltroChip('Todas', 'todos'),
                const SizedBox(width: 8),
                _buildFiltroChip('⭐ Excelentes', 'excelentes'),
                const SizedBox(width: 8),
                _buildFiltroChip('⚠️ Críticas', 'criticas'),
                const SizedBox(width: 8),
                _buildFiltroChip('🚨 Incidentes', 'incidentes'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtradas.length} calificación${filtradas.length == 1 ? '' : 'es'}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: filtradas.isEmpty
              ? const Center(child: Text('No hay calificaciones para este filtro', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtradas.length,
                  itemBuilder: (context, i) => _buildCalCard(filtradas[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCalCard(Map<String, dynamic> cal) {
    final rol = cal['calificador_rol']?.toString() ?? '?';
    final rating = cal['calificacion'] as int? ?? 0;
    final comentario = cal['comentario']?.toString() ?? '';
    final asp = cal['aspectos_puntuados'] as Map<String, dynamic>?;
    final tags = (asp?['etiquetas'] as List?)?.cast<String>() ?? [];
    final tieneIncidente = tags.contains('INCIDENTE_REPORTADO');
    final fecha = cal['created_at']?.toString().substring(0, 10) ?? '—';
    final calId = cal['id']?.toString() ?? '';

    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: tieneIncidente ? Colors.redAccent.withOpacity(0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(rol == 'capitan' ? '⚓' : '🎣', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    rol == 'capitan' ? 'Capitán → Pescador' : 'Pescador → Capitán',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (tieneIncidente) ...[ 
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
                      child: const Text('INCIDENTE', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              IconButton(
                onPressed: calId.isNotEmpty ? () => _eliminarCalificacion(calId) : null,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                tooltip: 'Eliminar calificación',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (j) => Icon(Icons.anchor_rounded, size: 14, color: j < rating ? _verde : Colors.white10)),
              const SizedBox(width: 8),
              Text('$rating/5', style: const TextStyle(color: _verde, fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text(fecha, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          if (comentario.isNotEmpty) ...[ 
            const SizedBox(height: 6),
            Text('"$comentario"', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (tags.isNotEmpty) ...[ 
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tags
                  .where((t) => t != 'INCIDENTE_REPORTADO')
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                        child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor) {
    final selected = _filtro == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtro = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _verde.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _verde.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? _verde : Colors.white54, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildKPIItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor, EdgeInsets? margin}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.07)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
