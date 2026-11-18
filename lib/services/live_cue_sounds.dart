import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Reproduce el acierto de una repetición válida y la alerta de mala posición.
class LiveCueSounds {
  final AudioPlayer _success = AudioPlayer();
  final AudioPlayer _alert = AudioPlayer();
  Future<void> _successQueue = Future<void>.value();
  Future<void> _alertQueue = Future<void>.value();
  bool _ready = false;
  bool _closed = false;

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  /// Carga los dos clips antes de abrir la cámara.
  Future<void> prepare() async {
    try {
      await _configure(_success, 'sounds/success.wav');
      await _configure(_alert, 'sounds/alert.wav');
      _ready = true;
    } catch (e) {
      debugPrint('No se pudieron preparar los sonidos en vivo: $e');
    }
  }

  Future<void> _configure(AudioPlayer player, String asset) {
    return _configurePlayer(player, asset).timeout(const Duration(seconds: 4));
  }

  Future<void> _configurePlayer(AudioPlayer player, String asset) async {
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(_context);
    await player.setVolume(1);
    await player.setSource(AssetSource(asset));
  }

  void playSuccess() => _enqueue(success: true, asset: 'sounds/success.wav', player: _success);

  void playAlert() => _enqueue(success: false, asset: 'sounds/alert.wav', player: _alert);

  void _enqueue({
    required bool success,
    required String asset,
    required AudioPlayer player,
  }) {
    final previous = success ? _successQueue : _alertQueue;
    final next = previous
        .then((_) {}, onError: (Object _, StackTrace _) {})
        .then((_) => _play(player, asset));
    if (success) {
      _successQueue = next;
    } else {
      _alertQueue = next;
    }
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    if (_closed) return;
    try {
      if (!_ready) {
        await player.play(AssetSource(asset));
        return;
      }
      await player.stop();
      if (_closed) return;
      await player.resume();
    } catch (e) {
      debugPrint('No se pudo reproducir $asset: $e');
    }
  }

  void close() {
    _closed = true;
    unawaited(_success.dispose());
    unawaited(_alert.dispose());
  }
}
