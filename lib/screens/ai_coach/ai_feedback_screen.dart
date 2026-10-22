import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiFeedbackScreen extends StatefulWidget {
  const AiFeedbackScreen({super.key});

  @override
  State<AiFeedbackScreen> createState() => _AiFeedbackScreenState();
}

class _AiFeedbackScreenState extends State<AiFeedbackScreen> {
  bool _isLoading = true;
  List<dynamic> _analyzedSets = [];
  
  @override
  void initState() {
    super.initState();
    _fetchAiFeedback();
  }

  Future<void> _fetchAiFeedback() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Obtenemos los sets que tienen datos en ai_metrics
      final response = await Supabase.instance.client
          .from('sets')
          .select('id, weight, reps, rpe, ai_metrics, exercises(name), workouts!inner(user_id, date)')
          .eq('workouts.user_id', user.id)
          .not('ai_metrics', 'is', null)
          .order('created_at', ascending: false);

      // Filtramos localmente para asegurar que contengan la clave openai_analysis
      final filteredSets = response.where((setRow) {
        final metrics = setRow['ai_metrics'] as Map<String, dynamic>?;
        return metrics != null && metrics.containsKey('openai_analysis');
      }).toList();

      if (mounted) {
        setState(() {
          _analyzedSets = filteredSets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar análisis: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBulletPoints(List<dynamic> items, IconData icon, Color iconColor) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF180A0A),
        title: const Text('Análisis de Técnica IA', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _analyzedSets.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay análisis de IA registrados.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _analyzedSets.length,
                  itemBuilder: (context, index) {
                    final setRow = _analyzedSets[index];
                    final exerciseName = setRow['exercises']?['name'] ?? 'Ejercicio desconocido';
                    final weight = setRow['weight'];
                    final reps = setRow['reps'];
                    final date = setRow['workouts']?['date'] ?? '';
                    
                    final metrics = setRow['ai_metrics'] as Map<String, dynamic>;
                    final analysis = metrics['openai_analysis'] as Map<String, dynamic>? ?? {};
                    
                    final summary = analysis['summary'] ?? 'Sin resumen';
                    final strengths = analysis['strengths'] as List<dynamic>? ?? [];
                    final issues = analysis['issues'] as List<dynamic>? ?? [];
                    final recommendations = analysis['recommendations'] as List<dynamic>? ?? [];

                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF1E1E1E), width: 1),
                      ),
                      child: ExpansionTile(
                        iconColor: Colors.blueAccent,
                        collapsedIconColor: Colors.white54,
                        title: Text(
                          '$exerciseName - ${weight}kg x $reps',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          date,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.toString(),
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontStyle: FontStyle.italic,
                                    fontSize: 15
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                if (strengths.isNotEmpty) ...[
                                  const Text('Fortalezas', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  _buildBulletPoints(strengths, Icons.check_circle_outline, Colors.green),
                                  const SizedBox(height: 12),
                                ],

                                if (issues.isNotEmpty) ...[
                                  const Text('Puntos de Mejora', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  _buildBulletPoints(issues, Icons.warning_amber_rounded, Colors.orangeAccent),
                                  const SizedBox(height: 12),
                                ],

                                if (recommendations.isNotEmpty) ...[
                                  const Text('Recomendaciones', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  _buildBulletPoints(recommendations, Icons.lightbulb_outline, Colors.blueAccent),
                                ],
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}