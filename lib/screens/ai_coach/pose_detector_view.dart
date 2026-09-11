import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';
import 'package:flutter/foundation.dart';

class PoseDetectorView extends StatefulWidget {
  const PoseDetectorView({super.key});

  @override
  State<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  CameraController? _cameraController;
  int _cameraIndex = 0; // 0 para cámara trasera, 1 para frontal
  int _sensorOrientation = 0; // Para no saturar el teléfono

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras[_cameraIndex];
    _sensorOrientation = camera.sensorOrientation; // <-- Guardamos esto

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // Medio es mejor para la IA
      enableAudio: true, // Ponlo en true si quieres grabar audio en el set
    );

    await _cameraController?.initialize();
    if (!mounted) return;

    _cameraController?.startImageStream(_procesarImagenDeCamara);
    setState(() {});
  }

  Future<void> _procesarImagenDeCamara(CameraImage image) async {
  if (_isBusy || !_canProcess) return;
  _isBusy = true;

  try {
    final InputImageRotation? rotation = InputImageRotationValue.fromRawValue(_sensorOrientation);
    final InputImageFormat? format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (rotation == null || format == null) {
      _isBusy = false;
      return;
    }

    // Unificación de bytes para evitar fallos de memoria en Android YUV420
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
    final poses = await _poseDetector.processImage(inputImage);

    if (mounted) {
      setState(() {
        _posesDetectadas = poses.length;
        if (poses.isNotEmpty) {
          _customPaint = CustomPaint(
            painter: PosePainter(poses, Size(image.width.toDouble(), image.height.toDouble()), rotation),
            size: Size.infinite,
          );
        } else {
          _customPaint = null;
        }
      });
    }
  } catch (e) {
    debugPrint('Error en la detección: $e');
  } finally {
    _isBusy = false;
  }
}

int _posesDetectadas = 0;
  @override
  void dispose() {
    _canProcess = false;
    _poseDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
@override
Widget build(BuildContext context) {
  if (_cameraController == null || !_cameraController!.value.isInitialized) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
    );
  }

  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('IA Coach - Análisis de Forma'),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        
        // Capa de dibujo del esqueleto
        if (_customPaint != null) _customPaint!,

        // Panel de diagnóstico en tiempo real
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black87,
            child: Text(
              'Cuerpos detectados: $_posesDetectadas',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () async {
        // Lógica de grabación sin cambios...
      },
      backgroundColor: Colors.red,
      child: const Icon(Icons.videocam),
    ),
  );
}
}