import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';

import '../config/s3_config.dart';

class S3VideoService {
  S3VideoService._();

  static Minio _client() {
    return Minio(
      endPoint: S3Config.endPoint,
      accessKey: S3Config.resolvedAccessKey,
      secretKey: S3Config.resolvedSecretKey,
      region: S3Config.resolvedRegion,
      useSSL: true,
    );
  }

  static String? objectKeyFromStoredUrl(String stored) {
    if (stored.isEmpty) return null;
    if (!stored.startsWith('http://') && !stored.startsWith('https://')) {
      return stored;
    }

    final uri = Uri.tryParse(stored);
    if (uri == null) return null;
    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    return path.isEmpty ? null : path;
  }

  static Future<String> uploadSetVideo({
    required File file,
    required String userId,
  }) async {
    if (!S3Config.isConfigured) {
      throw StateError(
        'Configura S3 copiando s3.env.example.json a s3.env.json '
        'y corre la app con --dart-define-from-file=s3.env.json.',
      );
    }

    final extension = file.path.split('.').last.toLowerCase();
    final safeExt = extension.isEmpty ? 'mp4' : extension;
    final objectKey =
        'sets_videos/${userId}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    final minio = _client();
    await minio.fPutObject(
      S3Config.resolvedBucket,
      objectKey,
      file.path,
      metadata: {
        'Content-Type': safeExt == 'mov' ? 'video/quicktime' : 'video/mp4',
      },
    );

    return S3Config.publicUrlFor(objectKey);
  }

  static Future<String> resolvePlaybackUrl(String stored) async {
    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      if (!S3Config.isConfigured) return stored;
      final key = objectKeyFromStoredUrl(stored);
      if (key == null) return stored;
      try {
        return await _client().presignedGetObject(
          S3Config.resolvedBucket,
          key,
          expires: 3600,
        );
      } catch (e) {
        debugPrint('No se pudo firmar URL de S3, se usa la guardada: $e');
        return stored;
      }
    }

    if (!S3Config.isConfigured) {
      return S3Config.publicUrlFor(stored);
    }

    return _client().presignedGetObject(
      S3Config.resolvedBucket,
      stored,
      expires: 3600,
    );
  }

  static Future<void> deleteIfPossible(String? storedUrl) async {
    if (storedUrl == null || storedUrl.isEmpty || !S3Config.isConfigured) {
      return;
    }
    final key = objectKeyFromStoredUrl(storedUrl);
    if (key == null) return;
    try {
      await _client().removeObject(S3Config.resolvedBucket, key);
    } catch (e) {
      debugPrint('No se pudo borrar el video de S3: $e');
    }
  }
}
