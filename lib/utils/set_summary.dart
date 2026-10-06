import 'dart:math' as math;

import 'lift_rules.dart';
import 'rep_counter.dart';

/// Resumen numérico del set, calculado a partir de las repeticiones cerradas.
///
/// En sentadilla y banca, un ángulo menor es más profundidad. En peso muerto,
/// un ángulo mayor es un bloqueo más completo. La fatiga es la primera
/// repetición que queda al menos [fatigueMarginDegrees] peor que la mejor
/// vista hasta entonces.
class SetSummary {
  const SetSummary._();

  static const double fatigueMarginDegrees = 4;

  static double? bestAngle(LiftType lift, List<CompletedRep> reps) {
    if (reps.isEmpty) return null;
    if (lift == LiftType.deadlift) {
      return reps.map((rep) => rep.maxAngle).reduce(math.max);
    }
    return reps.map((rep) => rep.minAngle).reduce(math.min);
  }

  static Map<String, dynamic>? fromReps(LiftType lift, List<CompletedRep> reps) {
    if (reps.isEmpty) return null;

    final deeperIsLower = lift != LiftType.deadlift;
    var best = reps.first;
    var worst = reps.first;
    var bestMetric = _metric(best, deeperIsLower);
    var worstMetric = bestMetric;

    for (final rep in reps.skip(1)) {
      final metric = _metric(rep, deeperIsLower);
      final isBetter = deeperIsLower ? metric < bestMetric : metric > bestMetric;
      final isWorse = deeperIsLower ? metric > worstMetric : metric < worstMetric;
      if (isBetter) {
        bestMetric = metric;
        best = rep;
      }
      if (isWorse) {
        worstMetric = metric;
        worst = rep;
      }
    }

    final values = reps.map((rep) => _metric(rep, deeperIsLower)).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        values.length;

    int? fatigueOnset;
    var bestSoFar = _metric(reps.first, deeperIsLower);
    for (final rep in reps.skip(1)) {
      final metric = _metric(rep, deeperIsLower);
      final worseBy = deeperIsLower ? metric - bestSoFar : bestSoFar - metric;
      if (worseBy >= fatigueMarginDegrees) {
        fatigueOnset = rep.repNumber;
        break;
      }
      final improves = deeperIsLower ? metric < bestSoFar : metric > bestSoFar;
      if (improves) bestSoFar = metric;
    }

    return {
      'best_rep': best.repNumber,
      'worst_rep': worst.repNumber,
      'depth_spread': (math.sqrt(variance) * 10).round() / 10.0,
      'fatigue_onset_rep': ?fatigueOnset,
    };
  }

  /// Texto corto para el diálogo de confirmación y el detalle de la serie.
  static List<String> describir(List<dynamic>? repetitions, {int max = 6}) {
    if (repetitions == null || repetitions.isEmpty) return const [];
    final lineas = <String>[];
    final limite = math.min(max, repetitions.length);
    for (var i = 0; i < limite; i++) {
      final item = repetitions[i];
      if (item is Map) lineas.add(_linea(Map<String, dynamic>.from(item)));
    }
    if (repetitions.length > max) {
      lineas.add('… y ${repetitions.length - max} más');
    }
    return lineas;
  }

  static String? lineaResumen(Map<String, dynamic>? summary) {
    if (summary == null) return null;
    final mejor = summary['best_rep'];
    final peor = summary['worst_rep'];
    if (mejor == null || peor == null) return null;
    final fatiga = summary['fatigue_onset_rep'];
    final base = 'Mejor rep $mejor · peor rep $peor';
    if (fatiga == null) return base;
    return '$base · la profundidad baja desde la rep $fatiga';
  }

  static double _metric(CompletedRep rep, bool deeperIsLower) {
    return deeperIsLower ? rep.minAngle : rep.maxAngle;
  }

  static String _linea(Map<String, dynamic> rep) {
    final numero = rep['rep_number'];
    final valida = rep['valid'] == true;
    if (rep['knee_angle'] != null) {
      final bloqueo = (rep['max_angle'] as num?)?.toStringAsFixed(0) ?? '—';
      return 'Rep $numero: bloqueo $bloqueo°';
    }
    final profundidad = (rep['min_angle'] as num?)?.toStringAsFixed(0) ?? '—';
    if (!valida || rep['invalid_reason'] == 'depth') {
      return 'Rep $numero: $profundidad° · sin profundidad';
    }
    final torso = rep['torso_angle'];
    if (torso is num) {
      return 'Rep $numero: $profundidad° · torso ${torso.toStringAsFixed(0)}°';
    }
    return 'Rep $numero: $profundidad°';
  }
}
