import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseMathUtils {
  /// Calcula el ángulo entre tres puntos anatómicos usando la función arco tangente (atan2)
  /// [firstPoint] ej: Cadera
  /// [midPoint] ej: Rodilla (Este es el vértice del ángulo)
  /// [lastPoint] ej: Tobillo
  static double calcularAngulo(
    PoseLandmark firstPoint,
    PoseLandmark midPoint,
    PoseLandmark lastPoint,
  ) {
    // atan2 nos da el ángulo en radianes
    final double result =
        math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
        math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

    // Convertimos de radianes a grados
    double angle = result * (180 / math.pi);

    // Nos aseguramos de que el ángulo sea un valor absoluto y no mayor a 180 grados
    angle = angle.abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }

    return angle;
  }

  /// Evalúa la profundidad de la sentadilla.
  /// En el Powerlifting, la cadera debe romper el paralelo con la rodilla.
  static bool esSentadillaProfunda(double anguloRodilla) {
    // Este valor depende un poco del ángulo de la cámara, pero típicamente 
    // cuando la cadera baja de la rodilla, el ángulo se cierra a unos 70 - 90 grados.
    // Ajustaremos este valor empíricamente cuando lo pruebes.
    return anguloRodilla < 85.0; 
  }
}