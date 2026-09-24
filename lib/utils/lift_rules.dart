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

  /// Codo extendido: cierra la repetición y muestra el bloqueo en pantalla.
  static const double benchLockout = 150;

  /// El peso muerto abre la fase al bajar de este ángulo de cadera.
  static const double deadliftPhase = 120;

  /// Cadera y rodilla deben llegar aquí para el bloqueo del peso muerto.
  static const double deadliftLockout = 160;

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

/// Texto que acompaña al ángulo. Usa los mismos cortes que el color de la traza.
class LiftStatus {
  const LiftStatus._();

  static String message({
    required LiftType lift,
    required double angle,
    double secondaryAngle = 180,
  }) {
    switch (lift) {
      case LiftType.squat:
        if (angle <= LiftThresholds.squatDepth) {
          return '¡PARALELA ROTA (VÁLIDA)!';
        }
        if (angle < LiftThresholds.squatStart) {
          return 'Descendiendo (Falta profundidad)';
        }
        return 'De pie / Inicio';
      case LiftType.bench:
        if (angle <= LiftThresholds.benchDepth) {
          return '¡PECHO ALCANZADO (ROM COMPLETO)!';
        }
        if (angle >= LiftThresholds.benchLockout) {
          return 'Bloqueo completo (Arriba)';
        }
        if (angle < LiftThresholds.benchStart) {
          return 'En recorrido...';
        }
        return 'Arriba / Inicio';
      case LiftType.deadlift:
        if (angle >= LiftThresholds.deadliftLockout &&
            secondaryAngle >= LiftThresholds.deadliftLockout) {
          return '¡BLOQUEO COMPLETO (VÁLIDO)!';
        }
        if (angle < LiftThresholds.deadliftPhase) {
          return 'Posición inicial / Suelo';
        }
        return 'En tracción...';
    }
  }
}
