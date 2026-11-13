import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';
import 'app_shell.dart';
import 'workout_composer_screen.dart';

class TrainHubScreen extends StatefulWidget {
  const TrainHubScreen({super.key});

  @override
  State<TrainHubScreen> createState() => _TrainHubScreenState();
}

class _TrainHubScreenState extends State<TrainHubScreen> {
  final _service = TrainingService();
  bool _busy = false;
  List<Map<String, dynamic>> _today = [];

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _service.findWorkoutsOn(userId, DateTime.now());
      if (mounted) setState(() => _today = rows);
    } catch (e) {
      debugPrint('Workouts de hoy: $e');
    }
  }

  Future<void> _openComposer(String workoutId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WorkoutComposerScreen(workoutId: workoutId)),
    );
    await _loadToday();
  }

  Future<void> _manual() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WorkoutComposerScreen(origin: 'manual')),
    );
    await _loadToday();
  }

  Future<void> _coach() async {
    final assigned = _today.where((workout) {
      final status = workout['status']?.toString();
      return workout['origin'] == 'coach' && status != 'completed' && status != 'skipped';
    }).toList();
    if (assigned.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay rutina asignada para hoy')),
      );
      return;
    }
    await _openComposer(assigned.first['id'].toString());
  }

  Future<void> _ai() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final checkin = await _askCheckin();
    if (checkin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.saveCheckin(
        athleteId: userId,
        date: DateTime.now(),
        sleepHours: checkin.sleepHours,
        soreness: checkin.soreness,
        feeling: checkin.feeling,
      );
      final generated = await _service.requestGeneratedWorkout();
      final sets = List<Map<String, dynamic>>.from(generated['sets'] as List);
      final phase = generated['phase']?.toString();
      final workout = await _service.saveGeneratedWorkout(
        userId: userId,
        date: DateTime.now(),
        generatedSets: sets,
        notes: phase == null ? null : 'Fase: $phase',
      );
      if (!mounted) return;
      await _openComposer(workout['id'].toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la rutina: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({double sleepHours, int soreness, String feeling})?> _askCheckin() async {
    final sleepController = TextEditingController(text: '7');
    var soreness = 2;
    var feeling = 'normal';
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF252525),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Antes de armar la rutina', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: sleepController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Horas de sueño', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              Text('Dolor muscular: $soreness de 5', style: const TextStyle(color: Colors.white70)),
              Slider(
                value: soreness.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$soreness',
                onChanged: (value) => setLocal(() => soreness = value.round()),
              ),
              const Text('¿Cómo te sientes?', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const [('mal', 'Mal'), ('normal', 'Normal'), ('bien', 'Bien')])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: feeling == option.$1,
                      onSelected: (_) => setLocal(() => feeling = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () {
                    final sleep = double.tryParse(sleepController.text);
                    if (sleep == null || sleep <= 0) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Generar rutina'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final sleep = double.tryParse(sleepController.text);
    sleepController.dispose();
    if (accepted != true || sleep == null || sleep <= 0) return null;
    return (sleepHours: sleep, soreness: soreness, feeling: feeling);
  }

  String _originLabel(String? origin) {
    switch (origin) {
      case 'coach':
        return 'Coach';
      case 'ai':
        return 'IA';
      default:
        return 'Manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        leading: const ShellMenuButton(),
        title: const Text('Entrenar'),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : RefreshIndicator(
              color: Colors.redAccent,
              onRefresh: _loadToday,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Elige el entrenamiento de hoy',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes crear varios el mismo día. Los de hoy quedan abajo para retomarlos.',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 24),
                _option(
                  icon: Icons.edit_note,
                  title: 'Workout manual',
                  subtitle: 'Arma las series del día antes de grabarlas',
                  onTap: _manual,
                ),
                _option(
                  icon: Icons.auto_awesome,
                  title: 'Workout con IA',
                  subtitle: 'Genera la rutina con tus avances y objetivos',
                  onTap: _ai,
                ),
                _option(
                  icon: Icons.assignment_ind_outlined,
                  title: 'Workout del coach',
                  subtitle: 'Abre lo programado para esta fecha',
                  onTap: _coach,
                ),
                if (_today.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('HOY', style: TextStyle(color: Colors.white54, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  for (final workout in _today)
                    Card(
                      color: const Color(0xFF252525),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          _originLabel(workout['origin']?.toString()),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          workout['status']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () => _openComposer(workout['id'].toString()),
                      ),
                    ),
                ],
              ],
            ),
            ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
