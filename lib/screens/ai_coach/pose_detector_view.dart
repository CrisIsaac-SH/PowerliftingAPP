import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';
import '../../utils/pose_math_utils.dart';

class PoseDetectorView extends StatefulWidget {
  final String exercise;

  const PoseDetectorView({
    super.key,
    this.exercise = 'SQUAT',
  });

  @override
  State<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _cameraIndex = 0; // 0 = trasera, 1 = frontal
  bool _canProcess = true;
  bool _isBusy = false;
  bool _isRecordingVideo = false;
  bool _isExiting = false;

  // Estado de detección
  bool _cuerpoDetectado = false;
  ExercisePoseAnalysis? _ultimoAnalisis;
  CustomPaint? _customPaint;

  // Sistema de Bloqueo / Fijación de Traza (Antisensibilidad)
  bool _isLocked = false;
  PoseSide? _lockedSide;
  final Map<PoseLandmarkType, Offset> _smoothedOffsets = {};
  double _smoothedAngle = 0.0;

  // Traza de movimiento (historial de coordenadas)
  final List<Offset> _trajectoryPoints = [];

  // Contador de repeticiones y biomecánica
  int _repsContadas = 0;
  int _repsValidas = 0;
  bool _enFaseDescenso = false;
  bool _alcanzoProfundidad = false;
  int _framesEnProfundidad = 0;
  DateTime? _tiempoInicioRep;
  double _mejorAngulo = 999.0;
  double _anguloActual = 0.0;

  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      if (_cameraIndex >= _cameras.length) {
        _cameraIndex = 0;
      }

      final camera = _cameras[_cameraIndex];

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (e) {
        debugPrint('No se pudo bloquear la orientación de captura: $e');
      }

      _cameraController = controller;
      await _iniciarGrabacionConAnalisis(controller);
      if (!mounted) {
        await _liberarCamara();
        return;
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error al inicializar la cámara: $e');
    }
  }

  Future<void> _iniciarGrabacionConAnalisis(CameraController controller) async {
    try {
      await controller.startVideoRecording(onAvailable: _procesarImagenDeCamara);
      _isRecordingVideo = true;
    } catch (e) {
      debugPrint('No se pudo iniciar la grabación, se continúa solo con análisis: $e');
      _isRecordingVideo = false;
      try {
        await controller.startImageStream(_procesarImagenDeCamara);
      } catch (streamError) {
        debugPrint('Tampoco se pudo iniciar el stream de análisis: $streamError');
      }
    }
  }

  Future<void> _liberarCamara({bool descartarGrabacion = true}) async {
    final controller = _cameraController;
    _cameraController = null;
    _isRecordingVideo = false;
    if (controller == null) return;

    try {
      if (controller.value.isRecordingVideo) {
        final file = await controller.stopVideoRecording();
        if (descartarGrabacion) {
          try {
            await File(file.path).delete();
          } catch (_) {}
        }
      } else if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('Error al detener cámara: $e');
    }

    await controller.dispose();
  }

  Future<String?> _detenerGrabacionYObtenerRuta() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) {
      _isRecordingVideo = false;
      return null;
    }

    try {
      final file = await controller.stopVideoRecording();
      _isRecordingVideo = false;
      return file.path;
    } catch (e) {
      debugPrint('Error al detener la grabación: $e');
      _isRecordingVideo = false;
      return null;
    }
  }

  Future<void> _cambiarCamara() async {
    if (_cameras.length < 2) return;

    setState(() {
      _customPaint = null;
      _cuerpoDetectado = false;
      _isLocked = false;
      _lockedSide = null;
      _smoothedOffsets.clear();
      _smoothedAngle = 0.0;
    });

    await _liberarCamara();

    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _iniciarCamara();
  }

  void _toggleBloqueoTraza() {
    setState(() {
      if (_isLocked) {
        _isLocked = false;
        _lockedSide = null;
      } else {
        if (_ultimoAnalisis != null && _ultimoAnalisis!.hasRequiredLandmarks) {
          _isLocked = true;
          _lockedSide = _ultimoAnalisis!.side;
        }
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLocked
              ? '🔒 Traza corporal BLOQUEADA. Movimientos estabilizados.'
              : '🔓 Traza DESBLOQUEADA. Reajustando seguimiento.',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: _isLocked ? Colors.cyan.shade800 : Colors.orange.shade800,
      ),
    );
  }

  InputImageRotation? _getImageRotation(CameraDescription camera) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController?.value.deviceOrientation ?? DeviceOrientation.portraitUp];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (camera.sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (camera.sensorOrientation - rotationCompensation + 360) % 360;
      }
      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    return null;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = _getImageRotation(camera);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = plane.bytes;
    } else {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane p in image.planes) {
        allBytes.putUint8List(p.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _procesarImagenDeCamara(CameraImage image) async {
    if (_isBusy || !_canProcess || _cameraController == null) return;
    _isBusy = true;

    try {
      final camera = _cameras[_cameraIndex];
      final inputImage = _inputImageFromCameraImage(image, camera);

      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);

      if (!mounted) return;

      if (poses.isNotEmpty) {
        final posePrincipal = poses.first;
        final imageSize = inputImage.metadata!.size;
        final rotation = inputImage.metadata!.rotation;
        final lensDir = camera.lensDirection;

        // Si la traza está bloqueada, forzamos el lado previamente fijado
        final analisisCrudo = PoseMathUtils.analizarPoseParaEjercicio(
          posePrincipal,
          widget.exercise,
          ladoBloqueado: _isLocked ? _lockedSide : null,
        );

        // Suavizado temporal del ángulo para eliminar micro-fluctuaciones
        final factorSuavizadoAngulo = _isLocked ? 0.35 : 0.50;
        _smoothedAngle = PoseMathUtils.suavizarValor(
          analisisCrudo.primaryAngle,
          _smoothedAngle,
          factorSuavizadoAngulo,
        );

        final analisis = ExercisePoseAnalysis(
          side: analisisCrudo.side,
          primaryAngle: _smoothedAngle,
          secondaryAngle: analisisCrudo.secondaryAngle,
          statusMessage: analisisCrudo.statusMessage,
          isValidForm: analisisCrudo.isValidForm,
          trackingLandmark: analisisCrudo.trackingLandmark,
          confidence: analisisCrudo.confidence,
          hasRequiredLandmarks: analisisCrudo.hasRequiredLandmarks,
        );

        _cuerpoDetectado = analisis.hasRequiredLandmarks;
        _ultimoAnalisis = analisis;
        _anguloActual = _smoothedAngle;

        // Suavizado temporal de las coordenadas de cada articulación (Anti-Jitter)
        final factorCoords = _isLocked ? 0.40 : 0.65;
        posePrincipal.landmarks.forEach((type, landmark) {
          if (landmark.likelihood > 0.40) {
            final rawX = _traducirCoordenadaX(landmark.x, imageSize, rotation, lensDir);
            final rawY = _traducirCoordenadaY(landmark.y, imageSize, rotation);

            final prev = _smoothedOffsets[type];
            if (prev == null) {
              _smoothedOffsets[type] = Offset(rawX, rawY);
            } else {
              _smoothedOffsets[type] = Offset(
                (rawX * factorCoords) + (prev.dx * (1.0 - factorCoords)),
                (rawY * factorCoords) + (prev.dy * (1.0 - factorCoords)),
              );
            }
          }
        });

        // Actualizar máquina de estados de repeticiones con debounce e histeresis
        if (analisis.hasRequiredLandmarks) {
          _actualizarContadorReps(analisis);

          // Registrar punto para la traza del movimiento (Bar Path con Noise Gate)
          if (analisis.trackingLandmark != null) {
            final trackType = analisis.trackingLandmark!.type;
            final smoothedPoint = _smoothedOffsets[trackType];

            if (smoothedPoint != null) {
              // Noise Gate: Ignora temblores menores a 3.5 píxeles cuando se está quieto
              if (_trajectoryPoints.isEmpty ||
                  (_trajectoryPoints.last - smoothedPoint).distance >= 3.5) {
                _trajectoryPoints.add(smoothedPoint);
                if (_trajectoryPoints.length > 35) {
                  _trajectoryPoints.removeAt(0);
                }
              }
            }
          }
        }

        _customPaint = CustomPaint(
          painter: PosePainter(
            poses: poses,
            absoluteImageSize: inputImage.metadata!.size,
            rotation: inputImage.metadata!.rotation,
            lensDirection: camera.lensDirection,
            exercise: widget.exercise,
            trajectoryPoints: List.from(_trajectoryPoints),
            analysis: analisis,
            isLocked: _isLocked,
            smoothedOffsets: Map.from(_smoothedOffsets),
          ),
          size: Size.infinite,
        );
      } else {
        _cuerpoDetectado = false;
        _customPaint = null;
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error en la detección: $e');
    } finally {
      _isBusy = false;
    }
  }

  void _actualizarContadorReps(ExercisePoseAnalysis analisis) {
    final angle = analisis.primaryAngle;
    final ex = widget.exercise.toUpperCase();
    final now = DateTime.now();

    if (ex.contains('BENCH') || ex.contains('BANCA')) {
      // PRESS DE BANCA
      if (angle < _mejorAngulo) _mejorAngulo = angle;

      if (angle < 120 && !_enFaseDescenso) {
        _enFaseDescenso = true;
        _tiempoInicioRep = now;
        _framesEnProfundidad = 0;
      }
      if (_enFaseDescenso && angle <= 92) {
        _framesEnProfundidad++;
        if (_framesEnProfundidad >= 2) {
          _alcanzoProfundidad = true;
        }
      }
      if (_enFaseDescenso && angle >= 150) {
        final duracion = _tiempoInicioRep != null
            ? now.difference(_tiempoInicioRep!).inMilliseconds
            : 1000;

        // Debounce: repetición debe durar al menos 900ms para evitar micro-movimientos
        if (duracion >= 900) {
          _repsContadas++;
          if (_alcanzoProfundidad) _repsValidas++;
        }
        _enFaseDescenso = false;
        _alcanzoProfundidad = false;
        _framesEnProfundidad = 0;
      }
    } else if (ex.contains('DEADLIFT') || ex.contains('MUERTO')) {
      // PESO MUERTO
      if (angle < 120 && !_enFaseDescenso) {
        _enFaseDescenso = true;
        _tiempoInicioRep = now;
      }
      if (_enFaseDescenso && analisis.isValidForm) {
        _alcanzoProfundidad = true;
      }
      if (_enFaseDescenso && _alcanzoProfundidad && angle < 120) {
        final duracion = _tiempoInicioRep != null
            ? now.difference(_tiempoInicioRep!).inMilliseconds
            : 1000;

        if (duracion >= 900) {
          _repsContadas++;
          _repsValidas++;
        }
        _enFaseDescenso = false;
        _alcanzoProfundidad = false;
      }
    } else {
      // SENTADILLA (SQUAT)
      if (angle < _mejorAngulo) _mejorAngulo = angle;

      if (angle < 128 && !_enFaseDescenso) {
        _enFaseDescenso = true;
        _tiempoInicioRep = now;
        _framesEnProfundidad = 0;
      }
      if (_enFaseDescenso && angle <= 88) {
        _framesEnProfundidad++;
        if (_framesEnProfundidad >= 2) {
          _alcanzoProfundidad = true;
        }
      }
      if (_enFaseDescenso && angle >= 148) {
        final duracion = _tiempoInicioRep != null
            ? now.difference(_tiempoInicioRep!).inMilliseconds
            : 1000;

        if (duracion >= 900) {
          _repsContadas++;
          if (_alcanzoProfundidad) _repsValidas++;
        }
        _enFaseDescenso = false;
        _alcanzoProfundidad = false;
        _framesEnProfundidad = 0;
      }
    }
  }

  double _traducirCoordenadaX(
    double x,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection lensDirection,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return lensDirection == CameraLensDirection.front
            ? screenWidth - (x * screenWidth / (Platform.isIOS ? imageSize.width : imageSize.height))
            : x * screenWidth / (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return lensDirection == CameraLensDirection.front
            ? x * screenWidth / (Platform.isIOS ? imageSize.width : imageSize.height)
            : screenWidth - (x * screenWidth / (Platform.isIOS ? imageSize.width : imageSize.height));
      default:
        return lensDirection == CameraLensDirection.front
            ? screenWidth - (x * screenWidth / imageSize.width)
            : x * screenWidth / imageSize.width;
    }
  }

  double _traducirCoordenadaY(
    double y,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * screenHeight / (Platform.isIOS ? imageSize.height : imageSize.width);
      default:
        return y * screenHeight / imageSize.height;
    }
  }

  String _obtenerCalificacionTecnica() {
    if (_repsContadas == 0) return 'Sin repeticiones completadas';
    final porcentaje = (_repsValidas / _repsContadas) * 100;
    if (porcentaje >= 90) return '¡Excelente técnica y ROM completo!';
    if (porcentaje >= 60) return 'Buen trabajo, cuida la profundidad en algunas reps';
    return 'Falta romper la paralela o bloqueo completo';
  }

  // --- MODAL DE PREVIEW DEL EJERCICIO ANTES DE GUARDAR ---
  void _mostrarPreviewModal() {
    final puntosCopia = List<Offset>.from(_trajectoryPoints);
    final mejorAnguloFinal = _mejorAngulo == 999.0 ? _anguloActual : _mejorAngulo;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra indicadora superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.cyanAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'PREVIEW DEL EJERCICIO: ${widget.exercise}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isLocked ? Colors.cyan.withAlpha(40) : Colors.green.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isLocked ? Colors.cyanAccent : Colors.greenAccent,
                      ),
                    ),
                    child: Text(
                      _isLocked ? '🔒 Traza Bloqueada' : '✓ Traza Rastreada',
                      style: TextStyle(
                        color: _isLocked ? Colors.cyanAccent : Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Miniatura gráfica de la Trayectoria (Bar Path / Body Motion)
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: TrajectoryMiniPreviewPainter(
                            points: puntosCopia,
                            isDeep: _repsValidas > 0,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 12,
                        child: Text(
                          puntosCopia.isEmpty
                              ? 'Traza estática'
                              : 'Curva de Bar Path / Trayectoria registrada',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tabla de métricas resumidas
              Row(
                children: [
                  Expanded(
                    child: _buildPreviewCard(
                      title: 'TOTAL REPS',
                      value: '$_repsContadas',
                      subtitle: 'detectadas',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPreviewCard(
                      title: 'VÁLIDAS',
                      value: '$_repsValidas',
                      subtitle: 'con ROM',
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPreviewCard(
                      title: 'MEJOR ÁNGULO',
                      value: '${mejorAnguloFinal.toStringAsFixed(0)}°',
                      subtitle: 'profundidad',
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Evaluación de técnica
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _obtenerCalificacionTecnica(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botones de acción del Modal
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Continuar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx); // Cierra bottom sheet
                        _confirmarYSalir(mejorAnguloFinal, puntosCopia);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 178, 16, 16),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        'VINCULAR A LA SERIE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Future<void> _confirmarYSalir(double mejorAnguloFinal, List<Offset> puntos) async {
    if (_isExiting) return;
    _isExiting = true;
    final videoPath = await _detenerGrabacionYObtenerRuta();
    if (!mounted) return;

    Navigator.pop(context, {
      'ai_metrics': {
        'exercise': widget.exercise,
        'reps_detected': _repsContadas,
        'valid_reps': _repsValidas,
        'best_angle': mejorAnguloFinal,
        'body_detected': _cuerpoDetectado,
        'technique_evaluation': _obtenerCalificacionTecnica(),
        'trajectory_points': puntos.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'is_locked': _isLocked,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'video_path': ?videoPath,
    });
  }

  Future<void> _salirSinGuardar() async {
    if (_isExiting) return;
    _isExiting = true;
    await _liberarCamara();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _canProcess = false;
    _poseDetector.close();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isRecordingVideo) {
        controller.stopVideoRecording().whenComplete(() => controller.dispose());
      } else {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _salirSinGuardar();
      },
      child: _buildCameraBody(),
    );
  }

  Widget _buildVistaPreviaCamara() {
    final controller = _cameraController!;
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // En iOS CameraPreview ya queda derecho. En Android, al grabar CameraX
    // entrega el buffer del sensor (apaisado) y hay que rotarlo a vertical.
    if (!Platform.isAndroid || !controller.value.isRecordingVideo) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: CameraPreview(controller),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    // Trasera: sentido contrario al sensor. Frontal: el del sensor (si no, queda al revés).
    final cameraDesc = _cameras[_cameraIndex];
    final rawTurns = (cameraDesc.sensorOrientation ~/ 90) % 4;
    final isFront = cameraDesc.lensDirection == CameraLensDirection.front;
    final sensorTurns = isFront ? rawTurns : (4 - rawTurns) % 4;
    final rotated = sensorTurns % 2 == 1;

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: rotated ? previewSize.height : previewSize.width,
        height: rotated ? previewSize.width : previewSize.height,
        child: RotatedBox(
          quarterTurns: sensorTurns,
          child: SizedBox(
            width: previewSize.width,
            height: previewSize.height,
            child: controller.buildPreview(),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBody() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _salirSinGuardar,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                'Iniciando cámara con IA...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Preview de la cámara (corrige la rotación de CameraX al grabar)
          Positioned.fill(child: _buildVistaPreviaCamara()),

          // 2. Capa de dibujo de trazas del cuerpo y articulaciones
          ?_customPaint,

          // 3. Barra Superior
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _salirSinGuardar,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isLocked ? Colors.cyanAccent : Colors.redAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRecordingVideo) ...[
                        const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        Icons.fitness_center,
                        color: _isLocked ? Colors.cyanAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.exercise.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                    tooltip: 'Cambiar cámara',
                    onPressed: _cambiarCamara,
                  ),
                ),
              ],
            ),
          ),

          // 4. Badge Dinámico de Detección de Cuerpo y Estado de Bloqueo
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _cuerpoDetectado
                    ? (_isLocked ? Colors.cyan.shade900.withAlpha(220) : Colors.green.withAlpha(220))
                    : Colors.amber.shade900.withAlpha(220),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _cuerpoDetectado
                        ? (_isLocked ? Colors.cyanAccent.withAlpha(120) : Colors.greenAccent.withAlpha(100))
                        : Colors.orangeAccent.withAlpha(80),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isLocked
                        ? Icons.lock
                        : (_cuerpoDetectado ? Icons.accessibility_new : Icons.person_search),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLocked
                              ? '🔒 TRAZA BLOQUEADA (ALTA ESTABILIDAD)'
                              : (_cuerpoDetectado
                                  ? '¡CUERPO REGISTRADO Y RASTREADO!'
                                  : 'BUSCANDO ATLETA...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          _isLocked
                              ? 'Filtro anti-vibración activo en ${widget.exercise}'
                              : (_cuerpoDetectado
                                  ? 'Puedes pulsar "Fijar Traza" para anclar la postura'
                                  : 'Ubica tu cuerpo completo en el encuadre'),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Botón para Fijar/Desfijar Traza
                  if (_cuerpoDetectado)
                    TextButton.icon(
                      onPressed: _toggleBloqueoTraza,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black38,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        _isLocked ? Icons.lock_open : Icons.lock_outline,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: Text(
                        _isLocked ? 'Desbloquear' : 'Bloquear Traza',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 5. Panel Inferior HUD con Métricas y Botón de Preview / Guardado
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withAlpha(240),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        label: 'REPETICIONES',
                        value: '$_repsContadas',
                        color: Colors.white,
                        icon: Icons.repeat,
                      ),
                      Container(height: 36, width: 1, color: Colors.white24),
                      _buildMetricItem(
                        label: 'ÁNGULO',
                        value: '${_anguloActual.toStringAsFixed(0)}°',
                        color: _ultimoAnalisis?.isValidForm == true
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        icon: Icons.architecture,
                      ),
                      Container(height: 36, width: 1, color: Colors.white24),
                      _buildMetricItem(
                        label: 'VÁLIDAS',
                        value: '$_repsValidas',
                        color: Colors.greenAccent,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _repsContadas = 0;
                            _repsValidas = 0;
                            _mejorAngulo = 999.0;
                            _trajectoryPoints.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: 'Reiniciar contador',
                      ),
                      const SizedBox(width: 8),
                      // Botón que abre el PREVIEW antes de guardar
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _mostrarPreviewModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 178, 16, 16),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.preview_outlined, size: 20),
                          label: const Text(
                            'VER PREVIEW Y FINALIZAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Painter para la miniatura gráfica de la trayectoria (Bar Path Preview)
class TrajectoryMiniPreviewPainter extends CustomPainter {
  final List<Offset> points;
  final bool isDeep;

  TrajectoryMiniPreviewPainter({required this.points, required this.isDeep});

  @override
  void paint(Canvas canvas, Size size) {
    // Cuadrícula de fondo
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      final centerText = TextPainter(
        text: const TextSpan(
          text: 'Comienza tu movimiento para ver la traza',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      centerText.paint(
        canvas,
        Offset((size.width - centerText.width) / 2, (size.height - centerText.height) / 2),
      );
      return;
    }

    // Normalizar puntos para que calcen proporcionalmente en la vista previa
    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final spanX = (maxX - minX).clamp(20.0, 1000.0);
    final spanY = (maxY - minY).clamp(20.0, 1000.0);

    final padding = 20.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    final mappedPoints = points.map((p) {
      final normX = padding + ((p.dx - minX) / spanX) * drawW;
      final normY = padding + ((p.dy - minY) / spanY) * drawH;
      return Offset(normX, normY);
    }).toList();

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = isDeep ? Colors.greenAccent : Colors.cyanAccent;

    for (int i = 0; i < mappedPoints.length - 1; i++) {
      canvas.drawLine(mappedPoints[i], mappedPoints[i + 1], linePaint);
    }

    // Punto de inicio (verde)
    final startPaint = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(mappedPoints.first, 5, startPaint);

    // Punto final / actual (rojo/cian)
    final endPaint = Paint()..color = Colors.cyanAccent;
    canvas.drawCircle(mappedPoints.last, 5, endPaint);
  }

  @override
  bool shouldRepaint(covariant TrajectoryMiniPreviewPainter oldDelegate) => true;
}