import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';
import '../services/weight_unit_controller.dart';
import '../utils/one_rep_max.dart';
import 'record_set_screen.dart';

class WorkoutComposerScreen extends StatefulWidget {
  final String? workoutId;
  final String origin;

  const WorkoutComposerScreen({super.key, this.workoutId, this.origin = 'manual'});

  @override
  State<WorkoutComposerScreen> createState() => _WorkoutComposerScreenState();
}

class _WorkoutComposerScreenState extends State<WorkoutComposerScreen> {
  final _service = TrainingService();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController();

  bool _loading = true;
  bool _showForm = false;
  String? _workoutId;
  String _origin = 'manual';
  String _status = 'in_progress';
  List<Map<String, dynamic>> _sets = [];
  List<Map<String, dynamic>> _exercises = [];
  String? _exerciseId;
  double _estimatedRm = 0;

  @override
  void initState() {
    super.initState();
    _workoutId = widget.workoutId;
    _origin = widget.origin;
    _weightController.addListener(_updateRm);
    _repsController.addListener(_updateRm);
    _load();
  }

  @override
  void dispose() {
    _weightController.removeListener(_updateRm);
    _repsController.removeListener(_updateRm);
    _weightController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    super.dispose();
  }

  void _updateRm() {
    final units = context.read<WeightUnitController>();
    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    setState(() => _estimatedRm = PowerliftingUtils.calcular1RM(units.toKg(weight), reps));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _exercises = await _service.fetchExercises();
      _exerciseId ??= _service.exerciseIdFor(_exercises, 'squat');
      if (_workoutId != null) {
        final workout = await Supabase.instance.client
            .from('workouts')
            .select('id, origin, status')
            .eq('id', _workoutId!)
            .maybeSingle();
        if (workout != null) {
          _origin = workout['origin']?.toString() ?? _origin;
          _status = workout['status']?.toString() ?? _status;
        }
        _sets = await _service.setsOf(_workoutId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el entrenamiento: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSet() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final exerciseId = _exerciseId;
    if (userId == null || exerciseId == null) return;
    final units = context.read<WeightUnitController>();
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);
    final rpe = double.tryParse(_rpeController.text);
    if (weight == null || reps == null || weight <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa peso y repeticiones'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      _workoutId ??= (await _service.createWorkout(
        userId: userId,
        date: DateTime.now(),
        origin: _origin,
        status: _origin == 'coach' ? 'planned' : 'in_progress',
      ))['id'].toString();
      await _service.addPlannedSet(
        workoutId: _workoutId!,
        exerciseId: exerciseId,
        weightKg: units.toKg(weight),
        reps: reps,
        rpe: rpe,
        markCustomized: _origin == 'coach' || _origin == 'ai',
      );
      _weightController.clear();
      _repsController.clear();
      _rpeController.clear();
      _showForm = false;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la serie: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _record(Map<String, dynamic> set) async {
    final name = (set['exercises']?['name'] ?? 'SQUAT').toString();
    final key = TrainingService.liftKey(name);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordSetScreen(
          setId: set['id'].toString(),
          initialExercise: TrainingService.labelForLift(key),
          initialWeightKg: (set['target_weight'] as num?)?.toDouble() ?? (set['weight'] as num?)?.toDouble(),
          initialReps: (set['target_reps'] as num?)?.toInt() ?? (set['reps'] as num?)?.toInt(),
          initialRpe: (set['target_rpe'] as num?)?.toDouble() ?? (set['rpe'] as num?)?.toDouble(),
          returnAfterSave: true,
        ),
      ),
    );
    if (saved == true && _workoutId != null) {
      await _service.completeWorkoutIfDone(_workoutId!);
      await _load();
    }
  }

  Future<void> _skip() async {
    if (_workoutId == null) return;
    await _service.skipWorkout(_workoutId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<WeightUnitController>();
    final finished = _status == 'completed' || _status == 'skipped';
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        title: Text(_origin == 'coach' ? 'Rutina del coach' : _origin == 'ai' ? 'Rutina con IA' : 'Workout manual'),
        actions: [
          if (_origin == 'coach' && !finished && _workoutId != null)
            TextButton(
              onPressed: _skip,
              child: const Text('Omitir', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      floatingActionButton: finished
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.redAccent,
              onPressed: () => setState(() => _showForm = !_showForm),
              child: Icon(_showForm ? Icons.close : Icons.add, color: Colors.white),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_sets.isEmpty && !_showForm)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Text(
                      'Todavía no hay series. Pulsa + para agregar la primera.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                if (_showForm) _form(units),
                for (final set in _sets) _card(set, units),
              ],
            ),
    );
  }

  Widget _form(WeightUnitController units) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _exerciseId,
              dropdownColor: const Color(0xFF2C2C2C),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Ejercicio', labelStyle: TextStyle(color: Colors.white54)),
              items: [
                for (final exercise in _exercises)
                  if (TrainingService.liftKey((exercise['name'] ?? '').toString()) != null)
                    DropdownMenuItem(
                      value: exercise['id'].toString(),
                      child: Text(TrainingService.labelForLift(TrainingService.liftKey(exercise['name'].toString()))),
                    ),
              ],
              onChanged: (value) => setState(() => _exerciseId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_weightController, 'Peso (${units.suffix})')),
                const SizedBox(width: 8),
                Expanded(child: _field(_repsController, 'Reps', number: true)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_rpeController, 'RPE')),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '1RM estimado',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    child: Text(
                      _estimatedRm <= 0 ? '--' : units.format(_estimatedRm),
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Guardar serie',
                  onPressed: _saveSet,
                  icon: const Icon(Icons.save, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _card(Map<String, dynamic> set, WeightUnitController units) {
    final name = (set['exercises']?['name'] ?? '').toString();
    final key = TrainingService.liftKey(name);
    final done = set['status'] == 'completed';
    final weight = (set['target_weight'] as num?)?.toDouble() ?? (set['weight'] as num?)?.toDouble() ?? 0;
    final reps = set['target_reps'] ?? set['reps'] ?? '-';
    final rpe = set['target_rpe'] ?? set['rpe'];
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(TrainingService.imageForLift(key), width: 56, height: 56, fit: BoxFit.cover),
        ),
        title: Text(TrainingService.labelForLift(key), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${units.format(weight)} x $reps${rpe != null ? ' @ RPE $rpe' : ''}${done ? '\nFinalizada' : ''}',
          style: TextStyle(color: done ? Colors.greenAccent : Colors.white54),
        ),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.greenAccent)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Quitar serie',
                    onPressed: () async {
                      await _service.deletePlannedSet(set['id'].toString());
                      await _load();
                    },
                    icon: const Icon(Icons.close, color: Colors.white38),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
        onTap: done ? null : () => _record(set),
      ),
    );
  }
}
