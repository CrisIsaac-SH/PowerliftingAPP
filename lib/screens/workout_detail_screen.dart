import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;
  final String date;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
    required this.date,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  List<Map<String, dynamic>> _sets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSets();
  }

  // Carga todas las series asociadas a este entrenamiento
  Future<void> _fetchSets() async {
    try {
      final response = await Supabase.instance.client
          .from('sets')
          .select('id, weight, reps, rpe, exercises(name)')
          .eq('workout_id', widget.workoutId);

      setState(() {
        _sets = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar series: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Eliminar una serie específica de Supabase
  Future<void> _deleteSet(String setId) async {
    try {
      await Supabase.instance.client.from('sets').delete().eq('id', setId);
      _fetchSets(); // Recargamos la lista
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serie eliminada'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Ventana flotante para editar peso, reps o RPE
  void _showEditDialog(Map<String, dynamic> setItem) {
    final pesoController = TextEditingController(text: setItem['weight'].toString());
    final repsController = TextEditingController(text: setItem['reps'].toString());
    final rpeController = TextEditingController(text: setItem['rpe']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Editar Serie: ${setItem['exercises']?['name'] ?? 'Ejercicio'}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pesoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Repeticiones',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rpeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'RPE (Opcional)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 76, 1, 1),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  final newWeight = double.tryParse(pesoController.text);
                  final newReps = int.tryParse(repsController.text);
                  final newRpe = double.tryParse(rpeController.text);

                  if (newWeight != null && newReps != null) {
                    await Supabase.instance.client.from('sets').update({
                      'weight': newWeight,
                      'reps': newReps,
                      'rpe': newRpe,
                    }).eq('id', setItem['id']);

                    if (mounted) Navigator.pop(context);
                    _fetchSets();
                  }
                },
                child: const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: Text('Entrenamiento: ${widget.date}'),
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _sets.isEmpty
              ? const Center(
                  child: Text(
                    'No hay series en este entrenamiento.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _sets.length,
                  itemBuilder: (context, index) {
                    final setItem = _sets[index];
                    final exerciseName = setItem['exercises']?['name'] ?? 'Ejercicio';
                    final weight = setItem['weight'];
                    final reps = setItem['reps'];
                    final rpe = setItem['rpe'];

                    return Card(
                      color: const Color(0xFF252525),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(
                          exerciseName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${weight}kg x $reps ${rpe != null ? '@ RPE $rpe' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _showEditDialog(setItem),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteSet(setItem['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}