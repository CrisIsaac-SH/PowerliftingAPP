import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/s3_video_service.dart';
import '../services/video_pose_analyzer.dart';
import 'ai_coach/playback_pose_painter.dart';

class SetVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String exercise;

  const SetVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.exercise = 'SQUAT',
  });

  @override
  State<SetVideoPlayerScreen> createState() => _SetVideoPlayerScreenState();
}

class _SetVideoPlayerScreenState extends State<SetVideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;
  bool _showAi = true;
  bool _analyzing = false;
  bool _cancelled = false;
  double _analyzeProgress = 0;
  final List<PosePlaybackFrame> _frames = [];
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final playbackUrl = await S3VideoService.resolvePlaybackUrl(widget.videoUrl);
      final localFile = await VideoPoseAnalyzer.ensureLocalVideo(
        playbackUrl,
        isCancelled: () => _cancelled,
      );

      if (!mounted || _cancelled) return;

      final controller = VideoPlayerController.file(localFile);
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_onVideoTick);

      if (!mounted || _cancelled) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
        _analyzing = true;
      });
      await controller.play();

      await VideoPoseAnalyzer.analyze(
        videoPath: localFile.path,
        duration: controller.value.duration,
        exercise: widget.exercise,
        isCancelled: () => _cancelled,
        onFrame: (frame, progress) {
          if (!mounted || _cancelled) return;
          _frames.add(frame);
          setState(() => _analyzeProgress = progress);
        },
      );

      if (mounted && !_cancelled) {
        setState(() => _analyzing = false);
      }
    } catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _error = _controller == null ? 'No se pudo reproducir el video: $e' : null;
        _loading = false;
        _analyzing = false;
      });
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (!mounted || controller == null || !_showAi || _frames.isEmpty) return;

    final ms = controller.value.position.inMilliseconds;
    final index = _indiceFrame(ms);
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  int _indiceFrame(int timeMs) {
    var best = -1;
    for (var i = 0; i < _frames.length; i++) {
      if (_frames[i].timeMs <= timeMs) {
        best = i;
      } else {
        break;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _cancelled = true;
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final frame = (_showAi && _currentIndex >= 0 && _currentIndex < _frames.length)
        ? _frames[_currentIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF180A0A),
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Text(
                _showAi ? 'Con IA' : 'Sin IA',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _showAi,
                activeThumbColor: Colors.greenAccent,
                onChanged: (value) => setState(() => _showAi = value),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.redAccent),
                  SizedBox(height: 16),
                  Text('Preparando video...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : controller == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        if (_analyzing && _showAi)
                          LinearProgressIndicator(
                            value: _analyzeProgress <= 0 ? null : _analyzeProgress,
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white12,
                          ),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio == 0
                                  ? 16 / 9
                                  : controller.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(controller),
                                  if (_showAi && frame != null && frame.poses.isNotEmpty)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: PlaybackPosePainter(
                                            poses: frame.poses,
                                            imageSize: frame.imageSize,
                                            exercise: widget.exercise,
                                            analysis: frame.analysis,
                                            trajectoryImagePoints: frame.trajectory,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_showAi && frame != null)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      right: 10,
                                      child: _HudAnalisis(frame: frame),
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (controller.value.isPlaying) {
                                          controller.pause();
                                        } else {
                                          controller.play();
                                        }
                                      });
                                    },
                                    child: AnimatedOpacity(
                                      opacity: controller.value.isPlaying ? 0 : 1,
                                      duration: const Duration(milliseconds: 200),
                                      child: const CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 28,
                                        child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: VideoProgressIndicator(
                                      controller,
                                      allowScrubbing: true,
                                      colors: const VideoProgressColors(
                                        playedColor: Colors.redAccent,
                                        bufferedColor: Colors.white24,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_analyzing && _showAi)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Text(
                              'Reanalizando técnica… ${(_analyzeProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _HudAnalisis extends StatelessWidget {
  final PosePlaybackFrame frame;

  const _HudAnalisis({required this.frame});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _dato('REPS', '${frame.reps}'),
          _dato('VÁLIDAS', '${frame.validReps}'),
          _dato(
            'ÁNGULO',
            frame.analysis == null ? '--' : '${frame.analysis!.primaryAngle.toStringAsFixed(0)}°',
          ),
        ],
      ),
    );
  }

  Widget _dato(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.8)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
