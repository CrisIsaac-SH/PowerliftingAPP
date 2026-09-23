import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/lift_rules.dart';
import '../../utils/lift_visuals.dart';
import '../../utils/pose_math_utils.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final String exercise;
  final List<Offset> trajectoryPoints;
  final ExercisePoseAnalysis? analysis;
  final bool isLocked;
  final Map<PoseLandmarkType, Offset>? smoothedOffsets;

  PosePainter({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.lensDirection,
    required this.exercise,
    this.trajectoryPoints = const [],
    this.analysis,
    this.isLocked = false,
    this.smoothedOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    // 1. Dibujar la traza de trayectoria del movimiento (Bar Path / Body Trail)
    _dibujarTrayectoria(canvas, size);

    for (final pose in poses) {
      // 2. Dibujar el esqueleto base completo (Brazos, torso, piernas)
      _dibujarEsqueletoBase(canvas, size, pose);

      // 3. Resaltar las trazas biomecánicas específicas según el ejercicio
      _dibujarTrazasEjercicio(canvas, size, pose);

      // 4. Dibujar los puntos articulares (Landmarks)
      _dibujarPuntosArticulares(canvas, size, pose);

      // 5. Dibujar indicador de ángulo y estado en tiempo real sobre la articulación activa
      _dibujarEtiquetaAngulo(canvas, size, pose);
    }
  }

  void _dibujarTrayectoria(Canvas canvas, Size size) {
    if (trajectoryPoints.length < 2) return;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < trajectoryPoints.length - 1; i++) {
      final p1 = trajectoryPoints[i];
      final p2 = trajectoryPoints[i + 1];

      // Efecto desvanecido (los puntos más recientes son más brillantes)
      final double progress = (i + 1) / trajectoryPoints.length;
      final int alpha = (progress * 240).toInt().clamp(40, 255);

      paintLine.color = (isLocked ? Colors.cyanAccent : Colors.tealAccent).withAlpha(alpha);
      canvas.drawLine(p1, p2, paintLine);

      // Punto en cada nodo de la traza
      final pointPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(p2, 3.0, pointPaint);
    }
  }

  void _dibujarEsqueletoBase(Canvas canvas, Size size, Pose pose) {
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = (isLocked ? Colors.cyanAccent : Colors.white).withAlpha(100);

    // Torso
    _conectar(canvas, size, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, basePaint);

    // Brazos
    _conectar(canvas, size, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, basePaint);

    // Piernas
    _conectar(canvas, size, pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, basePaint);

    // Pies
    _conectar(canvas, size, pose, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, basePaint);
    _conectar(canvas, size, pose, PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex, basePaint);
  }

  void _dibujarTrazasEjercicio(Canvas canvas, Size size, Pose pose) {
    if (analysis == null || !analysis!.hasRequiredLandmarks) return;

    final lift = LiftThresholds.fromName(exercise);
    final tone = LiftVisuals.tone(
      lift: lift,
      angle: analysis!.primaryAngle,
      isValidForm: analysis!.isValidForm,
    );

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..color = _colorDeTono(tone);

    for (final link in LiftVisuals.activeLinks(lift, analysis!.side)) {
      _conectar(canvas, size, pose, link.$1, link.$2, activePaint);
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

  void _dibujarPuntosArticulares(Canvas canvas, Size size, Pose pose) {
    final jointBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white;

    final jointFill = Paint()
      ..style = PaintingStyle.fill
      ..color = isLocked ? Colors.cyan : Colors.deepPurpleAccent;

    pose.landmarks.forEach((type, landmark) {
      if (landmark.likelihood > 0.45) {
        final offset = _obtenerOffset(type, landmark, size);
        canvas.drawCircle(offset, 4.5, jointFill);
        canvas.drawCircle(offset, 4.5, jointBorder);
      }
    });
  }

  void _dibujarEtiquetaAngulo(Canvas canvas, Size size, Pose pose) {
    if (analysis == null || !analysis!.hasRequiredLandmarks) return;

    final typeClave = LiftVisuals.labelJoint(
      LiftThresholds.fromName(exercise),
      analysis!.side,
    );

    final landmarkClave = pose.landmarks[typeClave];
    if (landmarkClave == null || landmarkClave.likelihood < 0.45) return;

    final offsetPunto = _obtenerOffset(typeClave, landmarkClave, size);
    final pos = Offset(offsetPunto.dx + 15, offsetPunto.dy - 10);

    final angleText = '${analysis!.primaryAngle.toStringAsFixed(0)}°';
    final statusText = analysis!.statusMessage;
    final lockBadge = isLocked ? ' [🔒 FIJO]' : '';

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$angleText$lockBadge\n',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextSpan(
          text: statusText,
          style: TextStyle(
            color: analysis!.isValidForm ? Colors.greenAccent : Colors.orangeAccent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx - 6, pos.dy - 4, textPainter.width + 12, textPainter.height + 8),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = Colors.black87;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = analysis!.isValidForm
          ? Colors.greenAccent
          : (isLocked ? Colors.cyanAccent : Colors.white24);

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);
    textPainter.paint(canvas, pos);
  }

  void _conectar(
    Canvas canvas,
    Size size,
    Pose pose,
    PoseLandmarkType point1Type,
    PoseLandmarkType point2Type,
    Paint paint,
  ) {
    final point1 = pose.landmarks[point1Type];
    final point2 = pose.landmarks[point2Type];

    if (point1 != null && point2 != null && point1.likelihood > 0.40 && point2.likelihood > 0.40) {
      final p1 = _obtenerOffset(point1Type, point1, size);
      final p2 = _obtenerOffset(point2Type, point2, size);
      canvas.drawLine(p1, p2, paint);
    }
  }

  Offset _obtenerOffset(PoseLandmarkType type, PoseLandmark landmark, Size size) {
    if (smoothedOffsets != null && smoothedOffsets!.containsKey(type)) {
      return smoothedOffsets![type]!;
    }
    return Offset(_translateX(landmark.x, size), _translateY(landmark.y, size));
  }

  double _translateX(double x, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return lensDirection == CameraLensDirection.front
            ? size.width - (x * size.width / (Platform.isIOS ? absoluteImageSize.width : absoluteImageSize.height))
            : x * size.width / (Platform.isIOS ? absoluteImageSize.width : absoluteImageSize.height);
      case InputImageRotation.rotation270deg:
        return lensDirection == CameraLensDirection.front
            ? x * size.width / (Platform.isIOS ? absoluteImageSize.width : absoluteImageSize.height)
            : size.width - (x * size.width / (Platform.isIOS ? absoluteImageSize.width : absoluteImageSize.height));
      default:
        return lensDirection == CameraLensDirection.front
            ? size.width - (x * size.width / absoluteImageSize.width)
            : x * size.width / absoluteImageSize.width;
    }
  }

  double _translateY(double y, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * size.height / (Platform.isIOS ? absoluteImageSize.height : absoluteImageSize.width);
      default:
        return y * size.height / absoluteImageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }
}