import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var frameGenerator: AVAssetImageGenerator?
  private var currentVideoPath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VideoFrameExtractor") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "powerliftingapp/video_frames",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "extractFrame" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Falta la ruta del video", details: nil))
        return
      }

      let timeMs = (args["timeMs"] as? NSNumber)?.int64Value ?? 0
      let maxHeight = (args["maxHeight"] as? NSNumber)?.intValue ?? 640
      let quality = (args["quality"] as? NSNumber)?.floatValue ?? 70

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let data = try self?.extractFrame(
            path: path,
            timeMs: timeMs,
            maxHeight: maxHeight,
            quality: quality
          )
          DispatchQueue.main.async {
            result(data)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "extract_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func extractFrame(path: String, timeMs: Int64, maxHeight: Int, quality: Float) throws -> FlutterStandardTypedData? {
    if frameGenerator == nil || currentVideoPath != path {
      let asset = AVAsset(url: URL(fileURLWithPath: path))
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.requestedTimeToleranceBefore = .zero
      generator.requestedTimeToleranceAfter = .zero
      frameGenerator = generator
      currentVideoPath = path
    }

    guard let generator = frameGenerator else { return nil }
    let time = CMTime(value: timeMs, timescale: 1000)
    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
    var image = UIImage(cgImage: cgImage)

    if Int(image.size.height) > maxHeight, image.size.height > 0 {
      let ratio = CGFloat(maxHeight) / image.size.height
      let newSize = CGSize(width: image.size.width * ratio, height: CGFloat(maxHeight))
      UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
      image.draw(in: CGRect(origin: .zero, size: newSize))
      image = UIGraphicsGetImageFromCurrentImageContext() ?? image
      UIGraphicsEndImageContext()
    }

    guard let jpeg = image.jpegData(compressionQuality: CGFloat(quality / 100.0)) else {
      return nil
    }
    return FlutterStandardTypedData(bytes: jpeg)
  }
}
