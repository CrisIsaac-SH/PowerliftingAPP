import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';
import '../services/weight_unit_controller.dart';

class CoachProgramEditorScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;
  final String? programId;

  const CoachProgramEditorScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
    this.programId,
  });

  @override
  State<CoachProgramEditorScreen> createState() => _CoachProgramEditorScreenState();
}

class _DaySet {
  String? exerciseId;
  final weight = TextEditingController();
  final reps = TextEditingController();
  final rpe = TextEditingController();

  void dispose() {
    weight.dispose();
    reps.dispose();
    rpe.dispose();
  }
}

class _CoachProgramEditorScreenState extends State<CoachProgramEditorScreen> {
  final _service = TrainingService();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _days = <int, List<_DaySet>>{};
  final _selected = <int>{1, 3, 5};

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 28));
  String? _programId;
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;
  bool _saving = false;

  static const _labels = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};

  @override
  void initState() {
    super.initState();
    for (final day in _selected) {
      _days[day] = [_DaySet()];
    }
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    for (final sets in _days.values) {
      for (final set in sets) {
        set.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _exercises = await _service.fetchExercises();
      final program = widget.programId == null ? null : await _service.programById(widget.programId!);
      if (program != null) {
        _programId = program['id'].toString();
        _nameController.text = program['name']?.toString() ?? '';
        _notesController.text = program['coach_notes']?.toString() ?? '';
        _start = DateTime.tryParse(program['start_date'].toString()) ?? _start;
        _end = DateTime.tryParse(program['end_date'].toString()) ?? _end;
        final stored = await _service.loadProgramDays(_programId!);
        if (!mounted) return;
        final units = context.read<WeightUnitController>();
        for (final sets in _days.values) {
          for (final set in sets) {
            set.dispose();
          }
        }
        _days.clear();
        _selected
          ..clear()
          ..addAll(stored.keys);
        for (final entry in stored.entries) {
          _days[entry.key] = [
            for (final draft in entry.value)
              _DaySet()
                ..exerciseId = draft.exerciseId
                ..weight.text = draft.targetWeightKg == null ? '' : units.inputText(draft.targetWeightKg!)
                ..reps.text = draft.targetReps?.toString() ?? ''
                ..rpe.text = draft.targetRpe?.toString() ?? '',
          ];
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cargar el plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final coachId = Supabase.instance.client.auth.currentUser?.id;
    if (coachId == null) return;
    if (_nameController.text.trim().isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre y elige al menos un día')),
      );
      return;
    }
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha final tiene que ser posterior al inicio')),
      );
      return;
    }

    final units = context.read<WeightUnitController>();
    final days = <int, List<PlannedSetDraft>>{};
    for (final weekday in _selected) {
      final drafts = <PlannedSetDraft>[];
      for (final set in _days[weekday] ?? const <_DaySet>[]) {
        if (set.exerciseId == null) continue;
        final weight = double.tryParse(set.weight.text);
        final reps = int.tryParse(set.reps.text);
        final rpe = double.tryParse(set.rpe.text);
        drafts.add(PlannedSetDraft(
          exerciseId: set.exerciseId!,
          targetWeightKg: weight == null ? null : units.toKg(weight),
          targetReps: reps,
          targetRpe: rpe,
        ));
      }
      if (drafts.isNotEmpty) days[weekday] = drafts;
    }
    if (days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una serie con ejercicio')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_programId == null) {
        await _service.createProgram(
          coachId: coachId,
          athleteId: widget.athleteId,
          name: _nameController.text.trim(),
          start: _start,
          end: _end,
          days: days,
          coachNotes: _notesController.text.trim(),
        );
      } else {
        await _service.updateProgram(
          programId: _programId!,
          coachId: coachId,
          athleteId: widget.athleteId,
          name: _nameController.text.trim(),
          start: _start,
          end: _end,
          days: days,
          coachNotes: _notesController.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programa guardado'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el programa: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<WeightUnitController>();
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        title: Text('Plan de ${widget.athleteName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del programa',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Énfasis del coach (opcional)',
                    hintText: 'Ejemplo: priorizar sentadilla',
                    labelStyle: TextStyle(color: Colors.white54),
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateButton('Inicio', _start, () => _pickDate(start: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _dateButton('Fin', _end, () => _pickDate(start: false))),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in _labels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _selected.contains(entry.key),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selected.add(entry.key);
                              _days.putIfAbsent(entry.key, () => [_DaySet()]);
                            } else {
                              _selected.remove(entry.key);
                            }
                          });
                        },
                      ),
                  ],
                ),
                for (final weekday in _selected.toList()..sort()) ...[
                  const SizedBox(height: 16),
                  Text(_labels[weekday]!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  for (var i = 0; i < (_days[weekday]?.length ?? 0); i++) _setEditor(weekday, i, units),
                  TextButton.icon(
                    onPressed: () => setState(() => _days[weekday]!.add(_DaySet())),
                    icon: const Icon(Icons.add, color: Colors.redAccent),
                    label: const Text('Agregar serie', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando...' : 'Guardar programa'),
                ),
              ],
            ),
    );
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      child: Text('$label\n${TrainingService.ymd(date)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _setEditor(int weekday, int index, WeightUnitController units) {
    final set = _days[weekday]![index];
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: set.exerciseId,
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
              onChanged: (value) => setState(() => set.exerciseId = value),
            ),
            Row(
              children: [
                Expanded(child: _input(set.weight, 'Peso ${units.suffix}')),
                const SizedBox(width: 8),
                Expanded(child: _input(set.reps, 'Reps')),
                const SizedBox(width: 8),
                Expanded(child: _input(set.rpe, 'RPE')),
                IconButton(
                  onPressed: () {
                    setState(() {
                      set.dispose();
                      _days[weekday]!.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
    );
  }
}
