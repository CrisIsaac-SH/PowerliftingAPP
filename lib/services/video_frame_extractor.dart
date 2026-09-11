import 'package:flutter/services.dart';

class VideoFrameExtractor {
  static const _channel = MethodChannel('powerliftingapp/video_frames');

  static Future<Uint8List?> extractJpeg({
    required String videoPath,
    required int timeMs,
    int maxHeight = 640,
    int quality = 70,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>('extractFrame', {
      'path': videoPath,
      'timeMs': timeMs,
      'maxHeight': maxHeight,
      'quality': quality,
    });
    return result;
  }
}
