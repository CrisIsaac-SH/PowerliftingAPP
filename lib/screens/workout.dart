import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'record_set_screen.dart';
import 'workout_detail_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Map<String, dynamic>> _plannedWorkouts = [];
  List<Map<String, dynamic>> _completedWorkouts = [];
  bool _isLoading = true;
  final _userId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    if (_userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('workouts')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      final allWorkouts = List<Map<String, dynamic>>.from(response);

      setState(() {
        _plannedWorkouts = allWorkouts.where((w) => w['status'] == 'planned').toList();
        _completedWorkouts = allWorkouts.where((w) => w['status'] != 'planned').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar workouts: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _crearWorkoutEspontaneo() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RecordSetScreen(),
        ),
      ).then((_) => _fetchWorkouts());
    }
  }

  Future<void> _iniciarWorkoutPlanificado(Map<String, dynamic> workout) async {
    await Supabase.instance.client.from('workouts').update({
      'status': 'completed',
      'date': DateTime.now().toIso8601String(),
    }).eq('id', workout['id']);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RecordSetScreen(),
        ),
      ).then((_) => _fetchWorkouts());
    }
  }

  Future<void> _eliminarWorkout(String id) async {
    await Supabase.instance.client.from('workouts').delete().eq('id', id);
    _fetchWorkouts();
  }

  Widget _buildWorkoutList(List<Map<String, dynamic>> workouts, bool isPlannedView) {
    if (workouts.isEmpty) {
      return Center(
        child: Text(
          isPlannedView ? 'No tienes bloques asignados.' : 'No hay historial aún.',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        final dateStr = workout['date'] != null 
            ? workout['date'].toString().split('T')[0]
            : 'Sin fecha';
        
        final title = isPlannedView 
            ? 'Bloque: ${workout['day_label'] ?? 'Día Sugerido'}'
            : 'Entrenamiento: $dateStr';

        return Card(
          color: const Color(0xFF252525),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text(
              title,
              style: TextStyle(
                color: isPlannedView ? Colors.cyanAccent : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isPlannedView ? 'Toca para iniciar este bloque hoy' : 'Completado',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPlannedView)
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blueAccent),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutDetailScreen(
                            workoutId: workout['id'],
                            date: dateStr,
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _eliminarWorkout(workout['id']),
                ),
              ],
            ),
            onTap: () {
              if (isPlannedView) {
                _iniciarWorkoutPlanificado(workout);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordSetScreen(),
                  ),
                ).then((_) => _fetchWorkouts());
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF333333),
        appBar: AppBar(
          title: const Text('Entrenamientos'),
          backgroundColor: const Color(0xFF180A0A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Plan del Coach', icon: Icon(Icons.assignment)),
              Tab(text: 'Historial', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : TabBarView(
                children: [
                  _buildWorkoutList(_plannedWorkouts, true),
                  _buildWorkoutList(_completedWorkouts, false),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.redAccent,
          onPressed: _crearWorkoutEspontaneo,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Entrenamiento Libre', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}