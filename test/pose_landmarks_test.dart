import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:powerliftingapp/utils/pose_math_utils.dart';

void main() {
  PoseLandmark punto(
    PoseLandmarkType type,
    double x,
    double y,
    double likelihood,
  ) {
    return PoseLandmark(
      type: type,
      x: x,
      y: y,
      z: 0,
      likelihood: likelihood,
    );
  }

  Pose poseSentadilla({required double ankleLikelihood}) {
    return Pose(
      landmarks: {
        PoseLandmarkType.rightHip: punto(PoseLandmarkType.rightHip, 0, 0, 0.9),
        PoseLandmarkType.rightKnee: punto(PoseLandmarkType.rightKnee, 0, 10, 0.9),
        PoseLandmarkType.rightAnkle: punto(
          PoseLandmarkType.rightAnkle,
          10,
          10,
          ankleLikelihood,
        ),
      },
    );
  }

  group('cadena visible del ejercicio', () {
    test('sentadilla no mide si el tobillo no tiene confianza', () {
      final analysis = PoseMathUtils.analizarPoseParaEjercicio(
        poseSentadilla(ankleLikelihood: 0.4),
        'SQUAT',
        ladoBloqueado: PoseSide.right,
      );

      expect(analysis.hasRequiredLandmarks, isFalse);
      expect(analysis.isValidForm, isFalse);
      expect(analysis.primaryAngle, 180);
      expect(analysis.statusMessage, 'Buscando articulaciones...');
    });

    test('sentadilla mide el ángulo de rodilla si cadera, rodilla y tobillo son claros', () {
      final analysis = PoseMathUtils.analizarPoseParaEjercicio(
        poseSentadilla(ankleLikelihood: 0.8),
        'sentadilla',
        ladoBloqueado: PoseSide.right,
      );

      expect(analysis.hasRequiredLandmarks, isTrue);
      expect(analysis.primaryAngle, closeTo(90, 0.1));
    });

    test('banca no mide si la muñeca es dudosa', () {
      final analysis = PoseMathUtils.analizarPoseParaEjercicio(
        Pose(
          landmarks: {
            PoseLandmarkType.leftShoulder: punto(PoseLandmarkType.leftShoulder, 0, 0, 0.9),
            PoseLandmarkType.leftElbow: punto(PoseLandmarkType.leftElbow, 0, 10, 0.9),
            PoseLandmarkType.leftWrist: punto(PoseLandmarkType.leftWrist, 10, 10, 0.5),
          },
        ),
        'banca',
        ladoBloqueado: PoseSide.left,
      );

      expect(analysis.hasRequiredLandmarks, isFalse);
      expect(analysis.statusMessage, 'Buscando brazos...');
    });

    test('peso muerto no inventa un bloqueo si falta el hombro', () {
      final analysis = PoseMathUtils.analizarPoseParaEjercicio(
        Pose(
          landmarks: {
            PoseLandmarkType.rightHip: punto(PoseLandmarkType.rightHip, 0, 0, 0.95),
            PoseLandmarkType.rightKnee: punto(PoseLandmarkType.rightKnee, 0, 10, 0.95),
            PoseLandmarkType.rightAnkle: punto(PoseLandmarkType.rightAnkle, 0, 20, 0.95),
          },
        ),
        'peso muerto',
        ladoBloqueado: PoseSide.right,
      );

      expect(analysis.hasRequiredLandmarks, isFalse);
      expect(analysis.isValidForm, isFalse);
      expect(analysis.statusMessage, 'Buscando postura...');
    });
  });
}
