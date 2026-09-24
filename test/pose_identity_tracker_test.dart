import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:powerliftingapp/utils/pose_identity_tracker.dart';

void main() {
  Pose persona({
    required double x,
    required double confidence,
  }) {
    PoseLandmark punto(PoseLandmarkType type) {
      return PoseLandmark(
        type: type,
        x: x,
        y: 100,
        z: 0,
        likelihood: confidence,
      );
    }

    return Pose(
      landmarks: {
        for (final type in [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ])
          type: punto(type),
      },
    );
  }

  group('PoseIdentityTracker', () {
    test('al empezar elige el torso más visible, no el primero de la lista', () {
      final tracker = PoseIdentityTracker();
      final elegido = tracker.select([
        persona(x: 0, confidence: 0.7),
        persona(x: 400, confidence: 0.95),
      ]);

      expect(elegido.landmarks[PoseLandmarkType.leftHip]!.x, 400);
    });

    test('si entra otra persona, sigue a la que ya estaba en cuadro', () {
      final tracker = PoseIdentityTracker();
      final atleta = persona(x: 100, confidence: 0.9);
      tracker.select([atleta]);

      final elegido = tracker.select([
        persona(x: 700, confidence: 0.99),
        persona(x: 120, confidence: 0.8),
      ]);

      expect(elegido.landmarks[PoseLandmarkType.leftHip]!.x, 120);
    });

    test('si el atleta sale y queda otra persona, pasa a seguirla', () {
      final tracker = PoseIdentityTracker();
      tracker.select([persona(x: 100, confidence: 0.9)]);

      final elegido = tracker.select([
        persona(x: 650, confidence: 0.9),
      ]);

      expect(elegido.landmarks[PoseLandmarkType.leftHip]!.x, 650);
    });
  });
}
