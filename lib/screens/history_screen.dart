import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'workout_detail_screen.dart';
import '../utils/one_rep_max.dart'; // Asegúrate de que la ruta sea correcta

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  
  // Lista para el historial
  List<Map<String, dynamic>> _workouts = [];
  
  // Datos para los gráficos
  List<FlSpot> _squatSpots = [];
  List<FlSpot> _benchSpots = [];
  List<FlSpot> _deadliftSpots = [];
  List<String> _dateLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener todos los entrenamientos ordenados por fecha
      final workoutsResponse = await supabase
          .from('workouts')
          .select('id, date')
          .eq('user_id', user.id)
          .order('date', ascending: false);

      // 2. Obtener todas las series para calcular el 1RM histórico
      final setsResponse = await supabase
          .from('sets')
          .select('weight, reps, exercises(name), workouts!inner(date, user_id)')
          .eq('workouts.user_id', user.id)
          .order('workouts(date)', ascending: true); // Ascendente para el gráfico (de más viejo a más nuevo)

      // Procesar datos para el gráfico
      Map<String, Map<String, double>> maxRmsPerDate = {};
      
      for (var s in setsResponse) {
        final date = s['workouts']['date'];
        final exerciseName = (s['exercises']?['name'] ?? '').toString().toLowerCase();
        final weight = double.tryParse(s['weight'].toString()) ?? 0.0;
        final reps = int.tryParse(s['reps'].toString()) ?? 0;
        
        final rm = PowerliftingUtils.calcular1RM(weight, reps);

        maxRmsPerDate.putIfAbsent(date, () => {'Squat': 0.0, 'Bench': 0.0, 'Deadlift': 0.0});

        if (exerciseName.contains('squat') || exerciseName.contains('sentadilla')) {
          if (rm > maxRmsPerDate[date]!['Squat']!) maxRmsPerDate[date]!['Squat'] = rm;
        } else if (exerciseName.contains('bench') || exerciseName.contains('banca')) {
          if (rm > maxRmsPerDate[date]!['Bench']!) maxRmsPerDate[date]!['Bench'] = rm;
        } else if (exerciseName.contains('deadlift') || exerciseName.contains('muerto')) {
          if (rm > maxRmsPerDate[date]!['Deadlift']!) maxRmsPerDate[date]!['Deadlift'] = rm;
        }
      }

      // Generar los puntos (Spots) para el gráfico
      List<FlSpot> sqSpots = [];
      List<FlSpot> bpSpots = [];
      List<FlSpot> dlSpots = [];
      List<String> labels = [];

      int index = 0;
      // Ordenamos las fechas de más antigua a más reciente
      final sortedDates = maxRmsPerDate.keys.toList()..sort();
      
      for (var date in sortedDates) {
        labels.add(date.substring(5)); // Guardar solo MM-DD para que quepa
        final dayData = maxRmsPerDate[date]!;
        
        if (dayData['Squat']! > 0) sqSpots.add(FlSpot(index.toDouble(), dayData['Squat']!));
        if (dayData['Bench']! > 0) bpSpots.add(FlSpot(index.toDouble(), dayData['Bench']!));
        if (dayData['Deadlift']! > 0) dlSpots.add(FlSpot(index.toDouble(), dayData['Deadlift']!));
        
        index++;
      }

      if (mounted) {
        setState(() {
          _workouts = List<Map<String, dynamic>>.from(workoutsResponse);
          _squatSpots = sqSpots;
          _benchSpots = bpSpots;
          _deadliftSpots = dlSpots;
          _dateLabels = labels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando historial completo: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF333333),
        appBar: AppBar(
          title: const Text('Mi Progreso'),
          backgroundColor: const Color(0xFF180A0A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Historial'),
              Tab(icon: Icon(Icons.show_chart), text: 'Gráficos'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : TabBarView(
                children: [
                  _buildHistoryTab(),
                  _buildChartTab(),
                ],
              ),
      ),
    );
  }

  // --- PESTAÑA 1: LISTA DE HISTORIAL ---
  Widget _buildHistoryTab() {
    if (_workouts.isEmpty) {
      return const Center(
        child: Text('Aún no tienes entrenamientos.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workouts.length,
      itemBuilder: (context, index) {
        final workout = _workouts[index];
        return Card(
          color: const Color(0xFF2C2C2C),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.redAccent),
            title: Text(
              'Entrenamiento',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              workout['date'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutDetailScreen(
                    workoutId: workout['id'],
                    date: workout['date'],
                  ),
                ),
              );
              _fetchData(); // Recargar al volver por si se borró algo
            },
          ),
        );
      },
    );
  }

  // --- PESTAÑA 2: GRÁFICOS ---
  Widget _buildChartTab() {
    if (_squatSpots.isEmpty && _benchSpots.isEmpty && _deadliftSpots.isEmpty) {
      return const Center(
        child: Text('No hay datos suficientes para graficar.', style: TextStyle(color: Colors.white54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Squat', Colors.redAccent),
              _buildLegendItem('Bench', Colors.blueAccent),
              _buildLegendItem('Deadlift', Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _dateLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _dateLabels[value.toInt()],
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (_squatSpots.isNotEmpty) _buildLineChartBarData(_squatSpots, Colors.redAccent),
                  if (_benchSpots.isNotEmpty) _buildLineChartBarData(_benchSpots, Colors.blueAccent),
                  if (_deadliftSpots.isNotEmpty) _buildLineChartBarData(_deadliftSpots, Colors.greenAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.1),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}