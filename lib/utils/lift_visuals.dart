import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'lift_rules.dart';
import 'pose_math_utils.dart';

/// Cómo se pinta la traza del ejercicio respecto a los mismos umbrales
/// que usa el contador. Verde = forma válida, ámbar = ya entró al recorrido,
/// rojo = todavía en la postura extendida o inicial.
enum LiftTraceTone { valid, inRange, extended }

class LiftVisuals {
  const LiftVisuals._();

  static LiftTraceTone tone({
    required LiftType lift,
    required double angle,
    required bool isValidForm,
  }) {
    if (isValidForm) return LiftTraceTone.valid;

    final inRange = switch (lift) {
      LiftType.squat => angle < LiftThresholds.squatStart,
      LiftType.bench => angle < LiftThresholds.benchStart,
      LiftType.deadlift => angle < LiftThresholds.deadliftPhase,
    };
    return inRange ? LiftTraceTone.inRange : LiftTraceTone.extended;
  }

  /// Articulación cuyo ángulo se muestra en pantalla.
  /// En peso muerto el ángulo principal es el de la cadera, no el de la rodilla.
  static PoseLandmarkType labelJoint(LiftType lift, PoseSide side) {
    final right = side == PoseSide.right;
    switch (lift) {
      case LiftType.bench:
        return right ? PoseLandmarkType.rightElbow : PoseLandmarkType.leftElbow;
      case LiftType.deadlift:
        return right ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip;
      case LiftType.squat:
        return right ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee;
    }
  }

  /// Segmentos que se resaltan durante el levantamiento.
  static List<(PoseLandmarkType, PoseLandmarkType)> activeLinks(
    LiftType lift,
    PoseSide side,
  ) {
    final right = side == PoseSide.right;
    switch (lift) {
      case LiftType.bench:
        final shoulder = right ? PoseLandmarkType.rightShoulder : PoseLandmarkType.leftShoulder;
        final elbow = right ? PoseLandmarkType.rightElbow : PoseLandmarkType.leftElbow;
        final wrist = right ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist;
        return [(shoulder, elbow), (elbow, wrist)];
      case LiftType.deadlift:
        final shoulder = right ? PoseLandmarkType.rightShoulder : PoseLandmarkType.leftShoulder;
        final hip = right ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip;
        final knee = right ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee;
        final ankle = right ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle;
        return [(shoulder, hip), (hip, knee), (knee, ankle)];
      case LiftType.squat:
        final hip = right ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip;
        final knee = right ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee;
        final ankle = right ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle;
        return [(hip, knee), (knee, ankle)];
    }
  }
}
