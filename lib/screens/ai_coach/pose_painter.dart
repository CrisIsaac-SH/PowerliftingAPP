import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_utils.dart'; // Importamos nuestra nueva matemática

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      // 1. Extraemos los puntos clave (Ejemplo para lado derecho del cuerpo)
      final cadera = pose.landmarks[PoseLandmarkType.rightHip];
      final rodilla = pose.landmarks[PoseLandmarkType.rightKnee];
      final tobillo = pose.landmarks[PoseLandmarkType.rightAnkle];

      // Color por defecto (Rojo = no hay profundidad)
      Color colorMovimiento = Colors.redAccent;
      double angulo = 180.0; // Estando de pie, el ángulo es casi 180 (recto)

      // 2. Calculamos el ángulo SI los puntos están visibles
      if (cadera != null && rodilla != null && tobillo != null) {
        // La probabilidad (likelihood) nos dice si la cámara está viendo esa parte bien
        if (cadera.likelihood > 0.8 && rodilla.likelihood > 0.8) {
          angulo = PoseMathUtils.calcularAngulo(cadera, rodilla, tobillo);
          
          // 3. Verificamos la profundidad
          if (PoseMathUtils.esSentadillaProfunda(angulo)) {
            colorMovimiento = Colors.greenAccent; // ¡Rompió la paralela!
          }
        }
      }

      // Pincel para dibujar
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..color = colorMovimiento;

      // 4. Dibujar los puntos del cuerpo
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
            Offset(
              _translateX(landmark.x, rotation, size, absoluteImageSize),
              _translateY(landmark.y, rotation, size, absoluteImageSize),
            ),
            2,
            paint);
      });

      // 5. Dibujar las líneas que conectan Cadera -> Rodilla -> Tobillo
      if (cadera != null && rodilla != null && tobillo != null) {
        canvas.drawLine(
            Offset(_translateX(cadera.x, rotation, size, absoluteImageSize), _translateX(cadera.y, rotation, size, absoluteImageSize)), // (Corrección visual más abajo)
            Offset(_translateX(rodilla.x, rotation, size, absoluteImageSize), _translateY(rodilla.y, rotation, size, absoluteImageSize)),
            paint);
            
        canvas.drawLine(
            Offset(_translateX(rodilla.x, rotation, size, absoluteImageSize), _translateY(rodilla.y, rotation, size, absoluteImageSize)),
            Offset(_translateX(tobillo.x, rotation, size, absoluteImageSize), _translateY(tobillo.y, rotation, size, absoluteImageSize)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }

  // Funciones _translateX y _translateY (Iguales a las que te pasé antes)
  double _translateX(double x, InputImageRotation rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg: return x * size.width / absoluteImageSize.height;
      case InputImageRotation.rotation270deg: return size.width - x * size.width / absoluteImageSize.height;
      default: return x * size.width / absoluteImageSize.width;
    }
  }

  double _translateY(double y, InputImageRotation rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg: return y * size.height / absoluteImageSize.width;
      default: return y * size.height / absoluteImageSize.height;
    }
  }
}