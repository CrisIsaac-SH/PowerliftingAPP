import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weekly_block_model.dart';
import '../screens/workout.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // --- MÉTODOS DEL ENTRENADOR ---

  /// Crea un nuevo bloque semanal y sus días asociados
  Future<void> createWeeklyBlockWithWorkouts({
    required String coachId,
    required String athleteId,
    required String title,
    String? coachNotes,
    required List<String> dayLabels, // Ej: ['Día 1', 'Día 2', 'Día 3']
  }) async {
    // 1. Insertar el bloque
    final blockResponse = await _supabase.from('weekly_blocks').insert({
      'coach_id': coachId,
      'athlete_id': athleteId,
      'title': title,
      'coach_notes': coachNotes,
      'status': 'planned',
    }).select().single();

    final String blockId = blockResponse['id'];

    // 2. Insertar los workouts planificados para ese bloque
    final List<Map<String, dynamic>> workoutsToInsert = dayLabels.map((day) {
      return {
        'user_id': athleteId,
        'weekly_block_id': blockId,
        'day_label': day,
        'status': 'planned',
        // La fecha queda en null hasta que el atleta lo inicie
      };
    }).toList();

    await _supabase.from('workouts').insert(workoutsToInsert);
  }

  // --- MÉTODOS DEL ATLETA ---

  /// Obtiene el bloque activo del atleta con sus notas y workouts
  Future<Map<String, dynamic>?> getActiveWeeklyBlock(String athleteId) async {
    final blockResponse = await _supabase
        .from('weekly_blocks')
        .select('*, workouts(*)')
        .eq('athlete_id', athleteId)
        .eq('status', 'planned')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return blockResponse; 
    // Esto devolverá un mapa con los datos del bloque y una lista anidada de sus 'workouts'
  }

  /// Cambia el estado del workout a completado y estampa la fecha actual
  Future<void> startWorkoutDay(String workoutId) async {
    await _supabase.from('workouts').update({
      'status': 'completed',
      'date': DateTime.now().toIso8601String(),
    }).eq('id', workoutId);
  }
}