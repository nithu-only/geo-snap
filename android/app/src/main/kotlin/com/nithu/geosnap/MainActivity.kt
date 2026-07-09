package com.nithu.geosnap

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var locationTracker: FusedLocationTracker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val mediaStore = MediaStoreRepository(contentResolver)
        val watermarkProcessor = WatermarkProcessor(contentResolver, mediaStore)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "geo_snap/native_camera",
            NativeCameraFactory(this, flutterEngine.dartExecutor.binaryMessenger, watermarkProcessor),
        )

        locationTracker = FusedLocationTracker(this).also { tracker ->
            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "geo_snap/location_events",
            ).setStreamHandler(tracker)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "geo_snap/media_store",
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val filename = call.argument<String>("filename")
                        if (bytes == null || filename.isNullOrBlank()) {
                            result.error("bad_args", "Missing image bytes or filename.", null)
                        } else {
                            result.success(mediaStore.saveBytes(bytes, filename))
                        }
                    }
                    "listImages" -> result.success(mediaStore.listImages())
                    "readImage" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("bad_args", "Missing image URI.", null)
                        } else {
                            result.success(mediaStore.readImage(uri))
                        }
                    }
                    "deleteImage" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("bad_args", "Missing image URI.", null)
                        } else {
                            mediaStore.delete(uri)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("media_store_error", error.message, null)
            }
        }
    }

    override fun onDestroy() {
        locationTracker?.dispose()
        locationTracker = null
        super.onDestroy()
    }
}
