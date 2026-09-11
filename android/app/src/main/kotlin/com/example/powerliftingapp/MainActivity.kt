package com.example.powerliftingapp

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "powerliftingapp/video_frames"
    private var retriever: MediaMetadataRetriever? = null
    private var currentPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "extractFrame") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                val timeMs = call.argument<Number>("timeMs")?.toLong() ?: 0L
                val maxHeight = call.argument<Number>("maxHeight")?.toInt() ?: 640
                val quality = call.argument<Number>("quality")?.toInt() ?: 70

                if (path.isNullOrEmpty()) {
                    result.error("bad_args", "Falta la ruta del video", null)
                    return@setMethodCallHandler
                }

                try {
                    result.success(extractFrame(path, timeMs, maxHeight, quality))
                } catch (e: Exception) {
                    result.error("extract_failed", e.message, null)
                }
            }
    }

    private fun extractFrame(path: String, timeMs: Long, maxHeight: Int, quality: Int): ByteArray? {
        if (retriever == null || currentPath != path) {
            retriever?.release()
            retriever = MediaMetadataRetriever().also {
                it.setDataSource(path)
            }
            currentPath = path
        }

        val bitmap = retriever?.getFrameAtTime(
            timeMs * 1000,
            MediaMetadataRetriever.OPTION_CLOSEST,
        ) ?: return null

        val scaled = if (bitmap.height > maxHeight && bitmap.height > 0) {
            val ratio = maxHeight.toFloat() / bitmap.height
            val width = (bitmap.width * ratio).toInt().coerceAtLeast(1)
            Bitmap.createScaledBitmap(bitmap, width, maxHeight, true).also {
                if (it != bitmap) bitmap.recycle()
            }
        } else {
            bitmap
        }

        val stream = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(40, 100), stream)
        if (scaled != bitmap) {
            scaled.recycle()
        } else {
            bitmap.recycle()
        }
        return stream.toByteArray()
    }

    override fun onDestroy() {
        retriever?.release()
        retriever = null
        currentPath = null
        super.onDestroy()
    }
}
