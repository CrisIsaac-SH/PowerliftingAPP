import 'package:supabase_flutter/supabase_flutter.dart';

class PlannedSetDraft {
  final String exerciseId;
  final double? targetWeightKg;
  final int? targetReps;
  final double? targetRpe;

  const PlannedSetDraft({
    required this.exerciseId,
    this.targetWeightKg,
    this.targetReps,
    this.targetRpe,
  });
}

class TrainingService {
  TrainingService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static String ymd(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static DateTime mondayOf(DateTime date) {
    final day = dateOnly(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static String? liftKey(String name) {
    final value = name.toLowerCase();
    if (value.contains('squat') || value.contains('sentadilla')) return 'squat';
    if (value.contains('bench') || value.contains('banca')) return 'bench';
    if (value.contains('deadlift') || value.contains('muerto')) return 'deadlift';
    return null;
  }

  static String imageForLift(String? key) {
    switch (key) {
      case 'bench':
        return 'assets/bench.jpeg';
      case 'deadlift':
        return 'assets/deadlift.jpeg';
      default:
        return 'assets/squat.jpeg';
    }
  }

  static String labelForLift(String? key) {
    switch (key) {
      case 'bench':
        return 'BENCH';
      case 'deadlift':
        return 'DEADLIFT';
      default:
        return 'SQUAT';
    }
  }

  Future<List<Map<String, dynamic>>> fetchExercises() async {
    final rows = await _supabase.from('exercises').select('id, name').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  String? exerciseIdFor(List<Map<String, dynamic>> exercises, String key) {
    for (final exercise in exercises) {
      if (liftKey((exercise['name'] ?? '').toString()) == key) {
        return exercise['id'].toString();
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> findWorkoutsOn(String userId, DateTime date) async {
    final rows = await _supabase
        .from('workouts')
        .select()
        .eq('user_id', userId)
        .eq('date', ymd(date))
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> setsOf(String workoutId) async {
    final rows = await _supabase
        .from('sets')
        .select(
          'id, workout_id, exercise_id, weight, reps, rpe, status, target_weight, target_reps, target_rpe, video_url, exercises(name)',
        )
        .eq('workout_id', workoutId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createWorkout({
    required String userId,
    required DateTime date,
    required String origin,
    String status = 'in_progress',
    String? programId,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'date': ymd(date),
      'status': status,
      'origin': origin,
      'is_customized': false,
    };
    if (programId != null) payload['program_id'] = programId;
    final row = await _supabase.from('workouts').insert(payload).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> addPlannedSet({
    required String workoutId,
    required String exerciseId,
    double? weightKg,
    int? reps,
    double? rpe,
    bool markCustomized = false,
  }) async {
    await _supabase.from('sets').insert({
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'weight': weightKg,
      'reps': reps,
      'rpe': rpe,
      'status': 'planned',
      'target_weight': weightKg,
      'target_reps': reps,
      'target_rpe': rpe,
    });
    if (markCustomized) {
      await _supabase.from('workouts').update({'is_customized': true}).eq('id', workoutId);
    }
  }

  Future<void> deletePlannedSet(String setId) async {
    await _supabase.from('sets').delete().eq('id', setId).eq('status', 'planned');
  }

  Future<void> skipWorkout(String workoutId) async {
    await _supabase.from('workouts').update({'status': 'skipped'}).eq('id', workoutId);
  }

  Future<void> completeWorkoutIfDone(String workoutId) async {
    final sets = await setsOf(workoutId);
    if (sets.isEmpty) return;
    final pending = sets.any((set) => set['status'] == 'planned');
    if (pending) return;
    await _supabase.from('workouts').update({
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', workoutId);
  }

  Future<Map<String, dynamic>?> weeklyGoal(String athleteId, DateTime date) async {
    final row = await _supabase
        .from('weekly_goals')
        .select('id, target_sessions, week_start, weekly_lift_goals(target_weight_kg, exercise_id, exercises(name))')
        .eq('athlete_id', athleteId)
        .eq('week_start', ymd(mondayOf(date)))
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> upsertSessionGoal({
    required String athleteId,
    required DateTime weekStart,
    required int targetSessions,
    required String createdBy,
  }) async {
    await _supabase.from('weekly_goals').upsert({
      'athlete_id': athleteId,
      'week_start': ymd(weekStart),
      'target_sessions': targetSessions,
      'created_by': createdBy,
    }, onConflict: 'athlete_id,week_start');
  }

  Future<List<Map<String, dynamic>>> workoutsBetween({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _supabase
        .from('workouts')
        .select('id, date, status, origin, sets(weight, reps, status, exercises(name))')
        .eq('user_id', userId)
        .gte('date', ymd(start))
        .lte('date', ymd(end))
        .order('date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveCheckin({
    required String athleteId,
    required DateTime date,
    required double sleepHours,
    required int soreness,
    required String feeling,
  }) async {
    await _supabase.from('daily_checkins').upsert({
      'athlete_id': athleteId,
      'checkin_date': ymd(date),
      'sleep_hours': sleepHours,
      'soreness': soreness,
      'feeling': feeling,
    }, onConflict: 'athlete_id,checkin_date');
  }

  Future<List<Map<String, dynamic>>> meetsFor(String athleteId) async {
    final rows = await _supabase
        .from('meets')
        .select('id, name, meet_date')
        .eq('athlete_id', athleteId)
        .order('meet_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addMeet({
    required String athleteId,
    required String name,
    required DateTime date,
    required String createdBy,
  }) async {
    await _supabase.from('meets').insert({
      'athlete_id': athleteId,
      'name': name,
      'meet_date': ymd(date),
      'created_by': createdBy,
    });
  }

  Future<void> deleteMeet(String meetId) async {
    await _supabase.from('meets').delete().eq('id', meetId);
  }

  Future<List<Map<String, dynamic>>> programsFor(String athleteId) async {
    final rows = await _supabase
        .from('training_programs')
        .select('id, name, start_date, end_date, status, coach_notes')
        .eq('athlete_id', athleteId)
        .order('start_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> programById(String programId) async {
    final row = await _supabase
        .from('training_programs')
        .select('id, name, start_date, end_date, status, coach_id, athlete_id, coach_notes')
        .eq('id', programId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> saveGeneratedWorkout({
    required String userId,
    required DateTime date,
    required List<Map<String, dynamic>> generatedSets,
    String? notes,
  }) async {
    final exercises = await fetchExercises();
    final workout = await createWorkout(userId: userId, date: date, origin: 'ai');
    if (notes != null && notes.isNotEmpty) {
      await _supabase.from('workouts').update({'notes': notes}).eq('id', workout['id']);
    }
    for (final set in generatedSets) {
      final key = (set['exercise'] ?? '').toString();
      final exerciseId = exerciseIdFor(exercises, key);
      if (exerciseId == null) continue;
      final weight = (set['target_weight_kg'] as num?)?.toDouble();
      final reps = (set['target_reps'] as num?)?.toInt();
      final rpe = (set['target_rpe'] as num?)?.toDouble();
      await addPlannedSet(
        workoutId: workout['id'].toString(),
        exerciseId: exerciseId,
        weightKg: weight,
        reps: reps,
        rpe: rpe,
      );
    }
    return workout;
  }

  Future<Map<String, dynamic>> requestGeneratedWorkout({DateTime? date}) async {
    final response = await _supabase.functions.invoke(
      'generate-workout',
      body: {'date': ymd(date ?? DateTime.now())},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    if (data is Map && data['sets'] is List) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('La función no devolvió una rutina válida');
  }

  Future<void> createProgram({
    required String coachId,
    required String athleteId,
    required String name,
    required DateTime start,
    required DateTime end,
    required Map<int, List<PlannedSetDraft>> days,
    String? coachNotes,
  }) async {
    final program = await _supabase.from('training_programs').insert({
      'coach_id': coachId,
      'athlete_id': athleteId,
      'name': name,
      'start_date': ymd(start),
      'end_date': ymd(end),
      'status': 'active',
      'coach_notes': coachNotes,
    }).select('id').single();

    final programId = program['id'].toString();
    await _writeTemplates(programId, days);
    await _materialize(
      programId: programId,
      athleteId: athleteId,
      start: dateOnly(start),
      end: dateOnly(end),
      days: days,
    );
    await _writeGoalsFromDays(
      athleteId: athleteId,
      createdBy: coachId,
      start: dateOnly(start),
      end: dateOnly(end),
      days: days,
    );
  }

  Future<Map<String, dynamic>?> activeProgram(String athleteId) async {
    final row = await _supabase
        .from('training_programs')
        .select('id, name, start_date, end_date, status, coach_id, athlete_id')
        .eq('athlete_id', athleteId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<int, List<PlannedSetDraft>>> loadProgramDays(String programId) async {
    final templates = await _supabase
        .from('program_day_templates')
        .select('id, weekday, template_sets(exercise_id, set_number, target_weight_kg, target_reps, target_rpe)')
        .eq('program_id', programId);
    final days = <int, List<PlannedSetDraft>>{};
    for (final template in List<Map<String, dynamic>>.from(templates)) {
      final weekday = template['weekday'] as int;
      final sets = List<Map<String, dynamic>>.from(template['template_sets'] ?? []);
      sets.sort((a, b) => (a['set_number'] as int).compareTo(b['set_number'] as int));
      days[weekday] = sets
          .map(
            (set) => PlannedSetDraft(
              exerciseId: set['exercise_id'].toString(),
              targetWeightKg: (set['target_weight_kg'] as num?)?.toDouble(),
              targetReps: (set['target_reps'] as num?)?.toInt(),
              targetRpe: (set['target_rpe'] as num?)?.toDouble(),
            ),
          )
          .toList();
    }
    return days;
  }

  Future<void> updateProgram({
    required String programId,
    required String coachId,
    required String athleteId,
    required String name,
    required DateTime start,
    required DateTime end,
    required Map<int, List<PlannedSetDraft>> days,
    String? coachNotes,
  }) async {
    await _supabase.from('training_programs').update({
      'name': name,
      'start_date': ymd(start),
      'end_date': ymd(end),
      'coach_notes': coachNotes,
    }).eq('id', programId);

    await _supabase.from('program_day_templates').delete().eq('program_id', programId);
    await _writeTemplates(programId, days);
    await _replaceFuturePlanned(
      programId: programId,
      athleteId: athleteId,
      start: dateOnly(start),
      end: dateOnly(end),
      days: days,
    );
    await _writeGoalsFromDays(
      athleteId: athleteId,
      createdBy: coachId,
      start: dateOnly(start),
      end: dateOnly(end),
      days: days,
    );
  }

  Future<void> _writeTemplates(String programId, Map<int, List<PlannedSetDraft>> days) async {
    for (final entry in days.entries) {
      if (entry.value.isEmpty) continue;
      final template = await _supabase.from('program_day_templates').insert({
        'program_id': programId,
        'weekday': entry.key,
      }).select('id').single();
      final templateId = template['id'].toString();
      final byExercise = <String, int>{};
      final rows = <Map<String, dynamic>>[];
      for (final set in entry.value) {
        final number = (byExercise[set.exerciseId] ?? 0) + 1;
        byExercise[set.exerciseId] = number;
        rows.add({
          'template_id': templateId,
          'exercise_id': set.exerciseId,
          'set_number': number,
          'target_weight_kg': set.targetWeightKg,
          'target_reps': set.targetReps,
          'target_rpe': set.targetRpe,
        });
      }
      if (rows.isNotEmpty) {
        await _supabase.from('template_sets').insert(rows);
      }
    }
  }

  Future<void> _materialize({
    required String programId,
    required String athleteId,
    required DateTime start,
    required DateTime end,
    required Map<int, List<PlannedSetDraft>> days,
  }) async {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final drafts = days[cursor.weekday];
      if (drafts != null && drafts.isNotEmpty) {
        final alreadyPlanned = await _supabase
            .from('workouts')
            .select('id')
            .eq('program_id', programId)
            .eq('date', ymd(cursor))
            .limit(1);
        if (List<Map<String, dynamic>>.from(alreadyPlanned).isEmpty) {
          final workout = await createWorkout(
            userId: athleteId,
            date: cursor,
            origin: 'coach',
            status: 'planned',
            programId: programId,
          );
          for (final draft in drafts) {
            await addPlannedSet(
              workoutId: workout['id'].toString(),
              exerciseId: draft.exerciseId,
              weightKg: draft.targetWeightKg,
              reps: draft.targetReps,
              rpe: draft.targetRpe,
            );
          }
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  Future<void> _replaceFuturePlanned({
    required String programId,
    required String athleteId,
    required DateTime start,
    required DateTime end,
    required Map<int, List<PlannedSetDraft>> days,
  }) async {
    final today = dateOnly(DateTime.now());
    final rows = await _supabase
        .from('workouts')
        .select('id, date, status, is_customized')
        .eq('program_id', programId);
    for (final workout in List<Map<String, dynamic>>.from(rows)) {
      final status = workout['status']?.toString();
      final customized = workout['is_customized'] == true;
      final date = DateTime.tryParse(workout['date'].toString());
      if (date == null) continue;
      final day = dateOnly(date);
      final open = status == 'planned' && !customized && !day.isBefore(today);
      if (!open) continue;
      await _supabase.from('sets').delete().eq('workout_id', workout['id']).eq('status', 'planned');
      final drafts = days[day.weekday] ?? const <PlannedSetDraft>[];
      final outside = day.isBefore(start) || day.isAfter(end) || drafts.isEmpty;
      if (outside) {
        await _supabase.from('workouts').delete().eq('id', workout['id']);
        continue;
      }
      for (final draft in drafts) {
        await addPlannedSet(
          workoutId: workout['id'].toString(),
          exerciseId: draft.exerciseId,
          weightKg: draft.targetWeightKg,
          reps: draft.targetReps,
          rpe: draft.targetRpe,
        );
      }
    }
    await _materialize(
      programId: programId,
      athleteId: athleteId,
      start: start.isBefore(today) ? today : start,
      end: end,
      days: days,
    );
  }

  Future<void> _writeGoalsFromDays({
    required String athleteId,
    required String createdBy,
    required DateTime start,
    required DateTime end,
    required Map<int, List<PlannedSetDraft>> days,
  }) async {
    var week = mondayOf(start);
    final last = mondayOf(end);
    while (!week.isAfter(last)) {
      final weekEnd = week.add(const Duration(days: 6));
      var sessions = 0;
      final heaviest = <String, double>{};
      var cursor = week.isBefore(start) ? start : week;
      final limit = weekEnd.isAfter(end) ? end : weekEnd;
      while (!cursor.isAfter(limit)) {
        final drafts = days[cursor.weekday] ?? const <PlannedSetDraft>[];
        if (drafts.isNotEmpty) sessions++;
        for (final draft in drafts) {
          final weight = draft.targetWeightKg ?? 0;
          if (weight > (heaviest[draft.exerciseId] ?? 0)) {
            heaviest[draft.exerciseId] = weight;
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      if (sessions > 0) {
        await upsertSessionGoal(
          athleteId: athleteId,
          weekStart: week,
          targetSessions: sessions,
          createdBy: createdBy,
        );
        final goal = await weeklyGoal(athleteId, week);
        final goalId = goal?['id']?.toString();
        if (goalId != null) {
          await _supabase.from('weekly_lift_goals').delete().eq('weekly_goal_id', goalId);
          if (heaviest.isNotEmpty) {
            await _supabase.from('weekly_lift_goals').insert([
              for (final entry in heaviest.entries)
                {
                  'weekly_goal_id': goalId,
                  'exercise_id': entry.key,
                  'target_weight_kg': entry.value,
                },
            ]);
          }
        }
      }
      week = week.add(const Duration(days: 7));
    }
  }
}
