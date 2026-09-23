import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:powerliftingapp/utils/lift_rules.dart';
import 'package:powerliftingapp/utils/lift_visuals.dart';
import 'package:powerliftingapp/utils/pose_math_utils.dart';

void main() {
  group('LiftVisuals.tone', () {
    test('verde cuando la forma ya es válida, sin importar el ángulo', () {
      expect(
        LiftVisuals.tone(lift: LiftType.squat, angle: 70, isValidForm: true),
        LiftTraceTone.valid,
      );
      expect(
        LiftVisuals.tone(lift: LiftType.deadlift, angle: 170, isValidForm: true),
        LiftTraceTone.valid,
      );
    });

    test('sentadilla y banca usan su propio inicio, no un corte de 125', () {
      expect(
        LiftVisuals.tone(lift: LiftType.squat, angle: 126, isValidForm: false),
        LiftTraceTone.inRange,
      );
      expect(
        LiftVisuals.tone(lift: LiftType.squat, angle: 140, isValidForm: false),
        LiftTraceTone.extended,
      );

      expect(
        LiftVisuals.tone(lift: LiftType.bench, angle: 119, isValidForm: false),
        LiftTraceTone.inRange,
      );
      expect(
        LiftVisuals.tone(lift: LiftType.bench, angle: 124, isValidForm: false),
        LiftTraceTone.extended,
      );
    });

    test('peso muerto marca recorrido por debajo de 120 y extensión por encima', () {
      expect(
        LiftVisuals.tone(lift: LiftType.deadlift, angle: 100, isValidForm: false),
        LiftTraceTone.inRange,
      );
      expect(
        LiftVisuals.tone(lift: LiftType.deadlift, angle: 140, isValidForm: false),
        LiftTraceTone.extended,
      );
    });
  });

  group('LiftVisuals articulaciones', () {
    test('la etiqueta cae en rodilla, codo o cadera según el levantamiento', () {
      expect(
        LiftVisuals.labelJoint(LiftType.squat, PoseSide.left),
        PoseLandmarkType.leftKnee,
      );
      expect(
        LiftVisuals.labelJoint(LiftType.bench, PoseSide.right),
        PoseLandmarkType.rightElbow,
      );
      expect(
        LiftVisuals.labelJoint(LiftType.deadlift, PoseSide.left),
        PoseLandmarkType.leftHip,
      );
    });

    test('cada ejercicio resalta su cadena y no la de otro', () {
      final squat = LiftVisuals.activeLinks(LiftType.squat, PoseSide.right);
      expect(squat, [
        (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
        (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
      ]);

      final bench = LiftVisuals.activeLinks(LiftType.bench, PoseSide.left);
      expect(bench.first.$1, PoseLandmarkType.leftShoulder);
      expect(bench.last.$2, PoseLandmarkType.leftWrist);

      final deadlift = LiftVisuals.activeLinks(LiftType.deadlift, PoseSide.right);
      expect(deadlift.first.$1, PoseLandmarkType.rightShoulder);
      expect(deadlift.last.$2, PoseLandmarkType.rightAnkle);
    });
  });
}
