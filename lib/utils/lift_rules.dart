/// Tipo de levantamiento que usa el análisis y el contador.
///
/// Los números de esta clase son los umbrales vigentes, reunidos en un solo
/// lugar para que la cámara en vivo y la reproducción del video coincidan.
/// Afinarlos es un paso aparte: aquí solo se centralizan.
enum LiftType { squat, bench, deadlift }

class LiftThresholds {
  const LiftThresholds._();

  /// Duración mínima de una repetición. Por debajo de esto se descarta
  /// (micro-movimiento) y se cierra la fase igualmente.
  static const int minRepDurationMs = 900;

  /// Fotogramas seguidos en el fondo antes de dar la profundidad por válida.
  static const int depthFramesRequired = 2;

  static const double squatStart = 128;
  static const double squatDepth = 88;
  static const double squatLockout = 148;

  static const double benchStart = 120;
  static const double benchDepth = 92;
  static const double benchLockout = 150;

  /// El peso muerto abre y cierra la fase al cruzar este ángulo de cadera.
  /// El bloqueo en sí lo marca [ExercisePoseAnalysis.isValidForm].
  static const double deadliftPhase = 120;

  static LiftType fromName(String exercise) {
    final name = exercise.toUpperCase();
    if (name.contains('BENCH') || name.contains('BANCA')) {
      return LiftType.bench;
    }
    if (name.contains('DEADLIFT') || name.contains('MUERTO')) {
      return LiftType.deadlift;
    }
    return LiftType.squat;
  }
}
