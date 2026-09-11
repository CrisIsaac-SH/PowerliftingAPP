/// Configuración de AWS S3. Las claves NUNCA van en este archivo.
///
/// Copia `s3.env.example.json` a `s3.env.json` (está en .gitignore) y corre:
/// `flutter run --dart-define-from-file=s3.env.json`
class S3Config {
  static const String bucket = String.fromEnvironment('S3_BUCKET');
  static const String region = String.fromEnvironment(
    'S3_REGION',
    defaultValue: 'us-east-1',
  );
  static const String accessKey = String.fromEnvironment('S3_ACCESS_KEY');
  static const String secretKey = String.fromEnvironment('S3_SECRET_KEY');

  static String get resolvedBucket => bucket;
  static String get resolvedRegion => region;
  static String get resolvedAccessKey => accessKey;
  static String get resolvedSecretKey => secretKey;

  static bool get isConfigured =>
      resolvedBucket.isNotEmpty &&
      resolvedAccessKey.isNotEmpty &&
      resolvedSecretKey.isNotEmpty;

  static String get endPoint => 's3.$resolvedRegion.amazonaws.com';

  static String publicUrlFor(String objectKey) {
    return 'https://$resolvedBucket.s3.$resolvedRegion.amazonaws.com/$objectKey';
  }
}
