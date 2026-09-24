import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'lift_rules.dart';

enum PoseSide { left, right }

class ExercisePoseAnalysis {
  final PoseSide side;
  final double primaryAngle;
  final double secondaryAngle;
  final String statusMessage;
  final bool isValidForm;
  final PoseLandmark? trackingLandmark;
  final double confidence;
  final bool hasRequiredLandmarks;

  ExercisePoseAnalysis({
    required this.side,
    required this.primaryAngle,
    required this.secondaryAngle,
    required this.statusMessage,
    required this.isValidForm,
    this.trackingLandmark,
    required this.confidence,
    required this.hasRequiredLandmarks,
  });
}

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
    final double result =
        math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
        math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

    double angle = (result * (180 / math.pi)).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }

    return angle;
  }

  /// Suavizado exponencial (EMA) para reducir la sensibilidad y fluctuaciones de micro-movimientos
  static double suavizarValor(double nuevoValor, double valorAnterior, double factor) {
    if (valorAnterior == 0.0) return nuevoValor;
    return (nuevoValor * factor) + (valorAnterior * (1.0 - factor));
  }

  /// Evalúa la profundidad de la sentadilla (rompe la paralela)
  static bool esSentadillaProfunda(double anguloRodilla) {
    return anguloRodilla <= LiftThresholds.squatDepth;
  }

  /// Evalúa si en press de banca la barra alcanzó el pecho
  static bool esPressBancaEnPecho(double anguloCodo) {
    return anguloCodo <= LiftThresholds.benchDepth;
  }

  /// Evalúa si en press de banca se completó el bloqueo
  static bool esPressBancaBloqueo(double anguloCodo) {
    return anguloCodo >= LiftThresholds.benchLockout;
  }

  /// Evalúa si en peso muerto se alcanzó el bloqueo articular de cadera y rodillas
  static bool esBloqueoPesoMuerto(double anguloCadera, double anguloRodilla) {
    return anguloCadera >= LiftThresholds.deadliftLockout &&
        anguloRodilla >= LiftThresholds.deadliftLockout;
  }

  /// Determina automáticamente qué lado del cuerpo (izquierdo o derecho)
  /// está más visible para la cámara según la probabilidad (likelihood) de los puntos.
  static PoseSide obtenerLadoMasVisible(Pose pose, String ejercicio) {
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];

    double confDerecha = 0.0;
    double confIzquierda = 0.0;

    if (LiftThresholds.fromName(ejercicio) == LiftType.bench) {
      confDerecha = (rShoulder?.likelihood ?? 0) + (rElbow?.likelihood ?? 0);
      confIzquierda = (lShoulder?.likelihood ?? 0) + (lElbow?.likelihood ?? 0);
    } else {
      confDerecha = (rHip?.likelihood ?? 0) + (rKnee?.likelihood ?? 0);
      confIzquierda = (lHip?.likelihood ?? 0) + (lKnee?.likelihood ?? 0);
    }

    return confDerecha >= confIzquierda ? PoseSide.right : PoseSide.left;
  }

  /// Realiza el análisis biomecánico específico según el ejercicio (SQUAT, BENCH, DEADLIFT)
  /// Permite pasar un [ladoBloqueado] para evitar que el algoritmo alterne entre izquierda y derecha
  static ExercisePoseAnalysis analizarPoseParaEjercicio(
    Pose pose,
    String ejercicio, {
    PoseSide? ladoBloqueado,
  }) {
    final side = ladoBloqueado ?? obtenerLadoMasVisible(pose, ejercicio);

    switch (LiftThresholds.fromName(ejercicio)) {
      case LiftType.bench:
        return _analizarBenchPress(pose, side);
      case LiftType.deadlift:
        return _analizarDeadlift(pose, side);
      case LiftType.squat:
        return _analizarSquat(pose, side);
    }
  }

  static bool _cadenaVisible(List<PoseLandmark?> points) {
    if (points.any((point) => point == null)) return false;
    return points.every(
      (point) => point!.likelihood >= LiftThresholds.minLandmarkConfidence,
    );
  }

  static double _confianzaMedia(List<PoseLandmark> points) {
    final total = points.fold<double>(0, (sum, point) => sum + point.likelihood);
    return total / points.length;
  }

  static ExercisePoseAnalysis _analizarSquat(Pose pose, PoseSide side) {
    final isRight = side == PoseSide.right;
    final hip = pose.landmarks[isRight ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    final knee = pose.landmarks[isRight ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[isRight ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle];

    final isVisible = _cadenaVisible([hip, knee, ankle]);

    if (!isVisible) {
      return ExercisePoseAnalysis(
        side: side,
        primaryAngle: 180.0,
        secondaryAngle: 180.0,
        statusMessage: 'Buscando articulaciones...',
        isValidForm: false,
        trackingLandmark: hip ?? knee,
        confidence: 0.0,
        hasRequiredLandmarks: false,
      );
    }

    final anguloRodilla = calcularAngulo(hip!, knee!, ankle!);
    final isDeep = esSentadillaProfunda(anguloRodilla);

    return ExercisePoseAnalysis(
      side: side,
      primaryAngle: anguloRodilla,
      secondaryAngle: 0.0,
      statusMessage: LiftStatus.message(
        lift: LiftType.squat,
        angle: anguloRodilla,
      ),
      isValidForm: isDeep,
      trackingLandmark: hip, // La cadera define la trayectoria del descenso
      confidence: _confianzaMedia([hip!, knee!, ankle!]),
      hasRequiredLandmarks: true,
    );
  }

  static ExercisePoseAnalysis _analizarBenchPress(Pose pose, PoseSide side) {
    final isRight = side == PoseSide.right;
    final shoulder = pose.landmarks[isRight ? PoseLandmarkType.rightShoulder : PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[isRight ? PoseLandmarkType.rightElbow : PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[isRight ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist];

    final isVisible = _cadenaVisible([shoulder, elbow, wrist]);

    if (!isVisible) {
      return ExercisePoseAnalysis(
        side: side,
        primaryAngle: 180.0,
        secondaryAngle: 180.0,
        statusMessage: 'Buscando brazos...',
        isValidForm: false,
        trackingLandmark: wrist ?? elbow,
        confidence: 0.0,
        hasRequiredLandmarks: false,
      );
    }

    final anguloCodo = calcularAngulo(shoulder!, elbow!, wrist!);
    final isChest = esPressBancaEnPecho(anguloCodo);
    final isLockout = esPressBancaBloqueo(anguloCodo);

    return ExercisePoseAnalysis(
      side: side,
      primaryAngle: anguloCodo,
      secondaryAngle: 0.0,
      statusMessage: LiftStatus.message(
        lift: LiftType.bench,
        angle: anguloCodo,
      ),
      isValidForm: isChest || isLockout,
      trackingLandmark: wrist, // La muñeca representa el trayecto de la barra
      confidence: _confianzaMedia([shoulder!, elbow!, wrist!]),
      hasRequiredLandmarks: true,
    );
  }

  static ExercisePoseAnalysis _analizarDeadlift(Pose pose, PoseSide side) {
    final isRight = side == PoseSide.right;
    final shoulder = pose.landmarks[isRight ? PoseLandmarkType.rightShoulder : PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[isRight ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    final knee = pose.landmarks[isRight ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[isRight ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle];
    final wrist = pose.landmarks[isRight ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist];

    final isVisible = _cadenaVisible([shoulder, hip, knee, ankle]);

    if (!isVisible) {
      return ExercisePoseAnalysis(
        side: side,
        primaryAngle: 180.0,
        secondaryAngle: 180.0,
        statusMessage: 'Buscando postura...',
        isValidForm: false,
        trackingLandmark: wrist ?? hip,
        confidence: 0.0,
        hasRequiredLandmarks: false,
      );
    }

    final shoulderPoint = shoulder!;
    final hipPoint = hip!;
    final kneePoint = knee!;
    final anklePoint = ankle!;
    final anguloRodilla = calcularAngulo(hipPoint, kneePoint, anklePoint);
    final anguloCadera = calcularAngulo(shoulderPoint, hipPoint, kneePoint);
    final isLockout = esBloqueoPesoMuerto(anguloCadera, anguloRodilla);

    return ExercisePoseAnalysis(
      side: side,
      primaryAngle: anguloCadera,
      secondaryAngle: anguloRodilla,
      statusMessage: LiftStatus.message(
        lift: LiftType.deadlift,
        angle: anguloCadera,
        secondaryAngle: anguloRodilla,
      ),
      isValidForm: isLockout,
      trackingLandmark: (wrist != null &&
              wrist.likelihood >= LiftThresholds.minLandmarkConfidence)
          ? wrist
          : hip,
      confidence: _confianzaMedia([shoulderPoint, hipPoint, kneePoint, anklePoint]),
      hasRequiredLandmarks: true,
    );
  }
}