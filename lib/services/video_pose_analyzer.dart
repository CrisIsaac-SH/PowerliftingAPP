import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/pose_math_utils.dart';
import 'video_frame_extractor.dart';

class PosePlaybackFrame {
  final int timeMs;
  final List<Pose> poses;
  final Size imageSize;
  final ExercisePoseAnalysis? analysis;
  final List<Offset> trajectory;
  final int reps;
  final int validReps;

  PosePlaybackFrame({
    required this.timeMs,
    required this.poses,
    required this.imageSize,
    required this.analysis,
    required this.trajectory,
    required this.reps,
    required this.validReps,
  });
}

class VideoPoseAnalyzer {
  VideoPoseAnalyzer._();

  static Future<File> ensureLocalVideo(String playbackUrl, {bool Function()? isCancelled}) async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/set_videos');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final key = playbackUrl.hashCode.toUnsigned(32).toRadixString(16);
    final file = File('${cacheDir.path}/$key.mp4');
    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(playbackUrl));
      request.followRedirects = true;
      final response = await request.close();
      if (isCancelled?.call() == true) {
        throw StateError('cancelado');
      }
      if (response.statusCode >= 400) {
        throw HttpException('No se pudo descargar el video (${response.statusCode})');
      }
      final sink = file.openWrite();
      await response.pipe(sink);
      return file;
    } catch (e) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> analyze({
    required String videoPath,
    required Duration duration,
    required String exercise,
    required void Function(PosePlaybackFrame frame, double progress) onFrame,
    bool Function()? isCancelled,
  }) async {
    final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    final tempDir = await getTemporaryDirectory();
    final counter = _PlaybackRepCounter();
    PoseSide? lockedSide;
    final trajectory = <Offset>[];

    final totalMs = duration.inMilliseconds <= 0 ? 1000 : duration.inMilliseconds;
    final intervalMs = totalMs > 24000 ? 200 : 140;
    final steps = (totalMs / intervalMs).ceil().clamp(1, 180);

    try {
      for (int i = 0; i < steps; i++) {
        if (isCancelled?.call() == true) return;

        final timeMs = (i * intervalMs).clamp(0, totalMs);
        final bytes = await VideoFrameExtractor.extractJpeg(
          videoPath: videoPath,
          timeMs: timeMs,
          quality: 70,
          maxHeight: 640,
        );
        if (bytes == null || bytes.isEmpty) {
          onFrame(
            PosePlaybackFrame(
              timeMs: timeMs,
              poses: const [],
              imageSize: Size.zero,
              analysis: null,
              trajectory: List.from(trajectory),
              reps: counter.reps,
              validReps: counter.validReps,
            ),
            (i + 1) / steps,
          );
          continue;
        }

        final codec = await instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        final imageSize = Size(
          frameInfo.image.width.toDouble(),
          frameInfo.image.height.toDouble(),
        );
        frameInfo.image.dispose();
        codec.dispose();

        final frameFile = File('${tempDir.path}/pose_frame_$timeMs.jpg');
        await frameFile.writeAsBytes(bytes, flush: true);

        List<Pose> poses = const [];
        try {
          poses = await detector.processImage(InputImage.fromFilePath(frameFile.path));
        } catch (e) {
          debugPrint('Error al analizar frame $timeMs: $e');
        } finally {
          try {
            await frameFile.delete();
          } catch (_) {}
        }

        ExercisePoseAnalysis? analysis;
        if (poses.isNotEmpty) {
          analysis = PoseMathUtils.analizarPoseParaEjercicio(
            poses.first,
            exercise,
            ladoBloqueado: lockedSide,
          );
          if (analysis.hasRequiredLandmarks) {
            lockedSide ??= analysis.side;
            counter.update(analysis, timeMs, exercise);
            final track = analysis.trackingLandmark;
            if (track != null && track.likelihood > 0.40) {
              final point = Offset(track.x, track.y);
              if (trajectory.isEmpty || (trajectory.last - point).distance >= 6) {
                trajectory.add(point);
                if (trajectory.length > 40) trajectory.removeAt(0);
              }
            }
          }
        }

        onFrame(
          PosePlaybackFrame(
            timeMs: timeMs,
            poses: poses,
            imageSize: imageSize,
            analysis: analysis,
            trajectory: List.from(trajectory),
            reps: counter.reps,
            validReps: counter.validReps,
          ),
          (i + 1) / steps,
        );
      }
    } finally {
      await detector.close();
    }
  }
}

class _PlaybackRepCounter {
  int reps = 0;
  int validReps = 0;
  bool descending = false;
  bool reachedDepth = false;
  int depthFrames = 0;
  int? startMs;

  void update(ExercisePoseAnalysis analysis, int timeMs, String exercise) {
    final angle = analysis.primaryAngle;
    final ex = exercise.toUpperCase();

    bool startDescent(double threshold) {
      if (angle < threshold && !descending) {
        descending = true;
        startMs = timeMs;
        depthFrames = 0;
        return true;
      }
      return false;
    }

    void finishRep(double lockoutAngle, {required bool requireDepth}) {
      if (descending && angle >= lockoutAngle) {
        final duration = startMs != null ? timeMs - startMs! : 1000;
        if (duration >= 700) {
          reps++;
          if (!requireDepth || reachedDepth) validReps++;
        }
        descending = false;
        reachedDepth = false;
        depthFrames = 0;
      }
    }

    if (ex.contains('BENCH') || ex.contains('BANCA')) {
      startDescent(120);
      if (descending && angle <= 92) {
        depthFrames++;
        if (depthFrames >= 2) reachedDepth = true;
      }
      finishRep(150, requireDepth: true);
    } else if (ex.contains('DEADLIFT') || ex.contains('MUERTO')) {
      startDescent(120);
      if (descending && analysis.isValidForm) reachedDepth = true;
      if (descending && reachedDepth && angle < 120) {
        final duration = startMs != null ? timeMs - startMs! : 1000;
        if (duration >= 700) {
          reps++;
          validReps++;
        }
        descending = false;
        reachedDepth = false;
      }
    } else {
      startDescent(128);
      if (descending && angle <= 88) {
        depthFrames++;
        if (depthFrames >= 2) reachedDepth = true;
      }
      finishRep(148, requireDepth: true);
    }
  }
}
