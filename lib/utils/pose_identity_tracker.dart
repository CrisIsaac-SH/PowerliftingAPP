import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'lift_rules.dart';

/// Elige a la misma persona entre las poses de un frame.
///
/// La primera vez se queda con el torso más visible. Después sigue al
/// cuerpo cuyo centro está más cerca del que ya estaba siguiendo, para que
/// alguien que entre al encuadre no robe el análisis.
class PoseIdentityTracker {
  double? _x;
  double? _y;

  static const _torso = <PoseLandmarkType>[
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  void reset() {
    _x = null;
    _y = null;
  }

  Pose select(List<Pose> poses) {
    if (poses.length == 1) {
      _remember(poses.first);
      return poses.first;
    }

    if (_x == null || _y == null) {
      final chosen = _mostVisible(poses);
      _remember(chosen);
      return chosen;
    }

    Pose? closest;
    var bestDistance = double.infinity;
    for (final pose in poses) {
      final center = _torsoCenter(pose);
      if (center == null) continue;
      final distance = _distance(center.$1, center.$2, _x!, _y!);
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = pose;
      }
    }

    final chosen = closest ?? _mostVisible(poses);
    _remember(chosen);
    return chosen;
  }

  void _remember(Pose pose) {
    final center = _torsoCenter(pose);
    if (center == null) return;
    _x = center.$1;
    _y = center.$2;
  }

  Pose _mostVisible(List<Pose> poses) {
    var best = poses.first;
    var bestScore = _visibility(best);
    for (final pose in poses.skip(1)) {
      final score = _visibility(pose);
      if (score > bestScore) {
        best = pose;
        bestScore = score;
      }
    }
    return best;
  }

  (double, double)? _torsoCenter(Pose pose) {
    var sumX = 0.0;
    var sumY = 0.0;
    var count = 0;
    for (final type in _torso) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < LiftThresholds.minLandmarkConfidence) {
        continue;
      }
      sumX += landmark.x;
      sumY += landmark.y;
      count++;
    }
    if (count == 0) return null;
    return (sumX / count, sumY / count);
  }

  double _visibility(Pose pose) {
    var score = 0.0;
    for (final type in _torso) {
      score += pose.landmarks[type]?.likelihood ?? 0;
    }
    return score;
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
