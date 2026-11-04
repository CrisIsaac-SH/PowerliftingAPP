import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachPlanWorkoutScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const CoachPlanWorkoutScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  State<CoachPlanWorkoutScreen> createState() => _CoachPlanWorkoutScreenState();
}

class _CoachPlanWorkoutScreenState extends State<CoachPlanWorkoutScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;

  Future<void> _generarRutinaIA() async {
    if (_promptController.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      // 1. Aquí irá la llamada a tu API de Gemini / IA en el futuro
      // Simularemos la respuesta de la IA creando un bloque de 3 días
      await Future.delayed(const Duration(seconds: 2)); 

      final supabase = Supabase.instance.client;
      final coachId = supabase.auth.currentUser!.id;

      // 2. Insertamos los días como "planned" en la base de datos del atleta
      final workoutsToInsert = [
        {
          'user_id': widget.athleteId,
          'coach_id': coachId,
          'status': 'planned',
          'day_label': 'Día 1: Empuje (Pecho/Tríceps)',
          'ai_prompt_used': _promptController.text,
        },
        {
          'user_id': widget.athleteId,
          'coach_id': coachId,
          'status': 'planned',
          'day_label': 'Día 2: Tirón (Espalda/Bíceps)',
          'ai_prompt_used': _promptController.text,
        },
        {
          'user_id': widget.athleteId,
          'coach_id': coachId,
          'status': 'planned',
          'day_label': 'Día 3: Pierna (Fuerza)',
          'ai_prompt_used': _promptController.text,
        },
      ];

      await supabase.from('workouts').insert(workoutsToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloque asignado con éxito'), backgroundColor: Colors.green),
        );
        _promptController.clear();
        Navigator.pop(context); // Regresa al home del coach
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        title: Text('Plan para ${widget.athleteName}'),
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asistente de Planificación IA',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe el bloque que deseas generar. Ejemplo: "Rutina de fuerza enfocada en Powerlifting de 4 días a la semana durante 1 mes."',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe tu instrucción para la IA...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generarRutinaIA,
                icon: _isGenerating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generando y asignando...' : 'Generar Bloque',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}