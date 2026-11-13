import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'athlete_progress_screen.dart';

class CoachTrainScreen extends StatefulWidget {
  const CoachTrainScreen({super.key});

  @override
  State<CoachTrainScreen> createState() => _CoachTrainScreenState();
}

class _CoachTrainScreenState extends State<CoachTrainScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _athletes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final coachId = supabase.auth.currentUser?.id;
      if (coachId == null) return;
      final links = await supabase.from('coach_athletes').select('athlete_id').eq('coach_id', coachId);
      final ids = links.map((row) => row['athlete_id'].toString()).toList();
      if (ids.isEmpty) {
        if (mounted) setState(() { _athletes = []; _loading = false; });
        return;
      }
      final profiles = await supabase.from('profiles').select('id, full_name').inFilter('id', ids);
      if (mounted) {
        setState(() {
          _athletes = List<Map<String, dynamic>>.from(profiles);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar atletas: $e')));
        setState(() => _loading = false);
      }
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : RefreshIndicator(
              color: Colors.redAccent,
              onRefresh: _load,
              child: _athletes.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Vincula atletas desde Inicio para ver su avance y crear planes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _athletes.length,
                      itemBuilder: (context, index) {
                        final athlete = _athletes[index];
                        final name = athlete['full_name']?.toString() ?? 'Atleta';
                        return Card(
                          color: const Color(0xFF252525),
                          child: ListTile(
                            leading: const Icon(Icons.insights, color: Colors.redAccent),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Ver avance y crear plan', style: TextStyle(color: Colors.white54)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AthleteProgressScreen(
                                    athleteId: athlete['id'].toString(),
                                    athleteName: name,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
