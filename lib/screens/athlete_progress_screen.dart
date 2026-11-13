import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/training_service.dart';
import '../widgets/progress_chart_card.dart';
import 'coach_program_editor_screen.dart';
import 'meets_screen.dart';
import 'workout_detail_screen.dart';

class AthleteProgressScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const AthleteProgressScreen({super.key, required this.athleteId, required this.athleteName});

  @override
  State<AthleteProgressScreen> createState() => _AthleteProgressScreenState();
}

class _AthleteProgressScreenState extends State<AthleteProgressScreen> {
  final _service = TrainingService();
  bool _loading = true;
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _programs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('workouts')
          .select('id, date, status')
          .eq('user_id', widget.athleteId)
          .order('date', ascending: false)
          .limit(12);
      final programs = await _service.programsFor(widget.athleteId);
      if (mounted) {
        setState(() {
          _workouts = List<Map<String, dynamic>>.from(rows);
          _programs = programs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([String? programId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoachProgramEditorScreen(
          athleteId: widget.athleteId,
          athleteName: widget.athleteName,
          programId: programId,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        title: Text(widget.athleteName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgressChartCard(userId: widget.athleteId, height: 260),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo programa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeetsScreen(
                          athleteId: widget.athleteId,
                          title: 'Competencias de ${widget.athleteName}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Competencias'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Programas', style: TextStyle(color: Colors.white70, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          if (_programs.isEmpty)
            const Text('Todavía no hay programas en fechas.', style: TextStyle(color: Colors.white54)),
          for (final program in _programs)
            Card(
              color: const Color(0xFF252525),
              child: ListTile(
                title: Text(program['name']?.toString() ?? 'Programa', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${program['start_date']} – ${program['end_date']}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.edit_outlined, color: Colors.white38),
                onTap: () => _openEditor(program['id'].toString()),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Entrenamientos', style: TextStyle(color: Colors.white70, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          if (_loading) const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          if (!_loading && _workouts.isEmpty)
            const Text('Este atleta todavía no tiene entrenamientos.', style: TextStyle(color: Colors.white54)),
          for (final workout in _workouts)
            Card(
              color: const Color(0xFF252525),
              child: ListTile(
                title: Text(workout['date']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                subtitle: Text(workout['status']?.toString() ?? 'completed', style: const TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutDetailScreen(
                        workoutId: workout['id'].toString(),
                        date: workout['date']?.toString() ?? '',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
