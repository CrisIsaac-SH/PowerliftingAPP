import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/lift_rules.dart';
import '../../utils/lift_visuals.dart';
import '../../utils/pose_math_utils.dart';

class PlaybackPosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final String exercise;
  final ExercisePoseAnalysis? analysis;
  final List<Offset> trajectoryImagePoints;

  PlaybackPosePainter({
    required this.poses,
    required this.imageSize,
    required this.exercise,
    this.analysis,
    this.trajectoryImagePoints = const [],
  });

  Offset _map(double x, double y, Size canvas) {
    if (imageSize.width == 0 || imageSize.height == 0) return Offset.zero;
    return Offset(
      x / imageSize.width * canvas.width,
      y / imageSize.height * canvas.height,
    );
  }

  Offset _mapLandmark(PoseLandmark landmark, Size canvas) {
    return _map(landmark.x, landmark.y, canvas);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _dibujarTrayectoria(canvas, size);

    for (final pose in poses) {
      _dibujarEsqueleto(canvas, size, pose);
      _dibujarTrazasEjercicio(canvas, size, pose);
      _dibujarPuntos(canvas, size, pose);
      _dibujarEtiqueta(canvas, size, pose);
    }
  }

  void _dibujarTrayectoria(Canvas canvas, Size size) {
    if (trajectoryImagePoints.length < 2) return;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < trajectoryImagePoints.length - 1; i++) {
      final progress = (i + 1) / trajectoryImagePoints.length;
      final alpha = (progress * 240).toInt().clamp(40, 255);
      paintLine.color = Colors.tealAccent.withAlpha(alpha);
      canvas.drawLine(
        _map(trajectoryImagePoints[i].dx, trajectoryImagePoints[i].dy, size),
        _map(trajectoryImagePoints[i + 1].dx, trajectoryImagePoints[i + 1].dy, size),
        paintLine,
      );
    }
  }

  void _dibujarEsqueleto(Canvas canvas, Size size, Pose pose) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withAlpha(110);

    void link(PoseLandmarkType a, PoseLandmarkType b) {
      _conectar(canvas, size, pose, a, b, paint);
    }

    link(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    link(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    link(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    link(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    link(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    link(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    link(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    link(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    link(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    link(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    link(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    link(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  void _dibujarTrazasEjercicio(Canvas canvas, Size size, Pose pose) {
    if (analysis == null || !analysis!.hasRequiredLandmarks) return;

    final lift = LiftThresholds.fromName(exercise);
    final tone = LiftVisuals.tone(
      lift: lift,
      angle: analysis!.primaryAngle,
      isValidForm: analysis!.isValidForm,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..color = _colorDeTono(tone);

    for (final link in LiftVisuals.activeLinks(lift, analysis!.side)) {
      _conectar(canvas, size, pose, link.$1, link.$2, paint);
    }
  }

  Color _colorDeTono(LiftTraceTone tone) {
    switch (tone) {
      case LiftTraceTone.valid:
        return Colors.greenAccent;
      case LiftTraceTone.inRange:
        return Colors.amberAccent;
      case LiftTraceTone.extended:
        return Colors.redAccent;
    }
  }

  void _dibujarPuntos(Canvas canvas, Size size, Pose pose) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.deepPurpleAccent;

    pose.landmarks.forEach((type, landmark) {
      if (landmark.likelihood > 0.45) {
        final offset = _mapLandmark(landmark, size);
        canvas.drawCircle(offset, 4.5, fill);
        canvas.drawCircle(offset, 4.5, border);
      }
    });
  }

  void _dibujarEtiqueta(Canvas canvas, Size size, Pose pose) {
    if (analysis == null || !analysis!.hasRequiredLandmarks) return;

    final type = LiftVisuals.labelJoint(
      LiftThresholds.fromName(exercise),
      analysis!.side,
    );

    final landmark = pose.landmarks[type];
    if (landmark == null || landmark.likelihood < 0.45) return;

    final pos = _mapLandmark(landmark, size) + const Offset(15, -10);
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${analysis!.primaryAngle.toStringAsFixed(0)}°\n',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: analysis!.statusMessage,
            style: TextStyle(
              color: analysis!.isValidForm ? Colors.greenAccent : Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx - 6, pos.dy - 4, painter.width + 12, painter.height + 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black87);
    canvas.drawRRect(
      bg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = analysis!.isValidForm ? Colors.greenAccent : Colors.white24,
    );
    painter.paint(canvas, pos);
  }

  void _conectar(
    Canvas canvas,
    Size size,
    Pose pose,
    PoseLandmarkType a,
    PoseLandmarkType b,
    Paint paint,
  ) {
    final p1 = pose.landmarks[a];
    final p2 = pose.landmarks[b];
    if (p1 == null || p2 == null || p1.likelihood <= 0.40 || p2.likelihood <= 0.40) {
      return;
    }
    canvas.drawLine(_mapLandmark(p1, size), _mapLandmark(p2, size), paint);
  }

  @override
  bool shouldRepaint(covariant PlaybackPosePainter oldDelegate) => true;
}
