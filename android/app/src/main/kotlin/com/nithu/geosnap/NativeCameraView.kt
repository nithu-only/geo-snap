package com.nithu.geosnap

import android.app.Activity
import android.content.Context
import android.location.Location
import android.os.SystemClock
import android.util.Log
import android.view.OrientationEventListener
import android.view.Surface
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class NativeCameraFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
    private val processor: WatermarkProcessor,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        return NativeCameraView(activity, messenger, viewId, processor, params)
    }
}

class NativeCameraView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    viewId: Int,
    private val processor: WatermarkProcessor,
    params: Map<*, *>?,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val container = FrameLayout(activity)
    private val previewView = PreviewView(activity).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    private val channel = MethodChannel(messenger, "geo_snap/camera_$viewId")
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val processingScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val captureInProgress = AtomicBoolean(false)
    private var provider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var preview: Preview? = null
    private var currentFlashMode: Int = ImageCapture.FLASH_MODE_OFF
    private var lensFacing: Int = CameraSelector.LENS_FACING_BACK
    private var currentDeviceRotation: Int = Surface.ROTATION_0
    private var camera: androidx.camera.core.Camera? = null

    private val orientationEventListener = object : OrientationEventListener(activity) {
        override fun onOrientationChanged(orientation: Int) {
            if (orientation == ORIENTATION_UNKNOWN) return
            val rotation = when {
                orientation >= 315 || orientation < 45 -> Surface.ROTATION_0
                orientation in 45..134 -> Surface.ROTATION_270
                orientation in 135..224 -> Surface.ROTATION_180
                else -> Surface.ROTATION_90
            }
            currentDeviceRotation = rotation
            imageCapture?.targetRotation = rotation
        }
    }

    init {
        params?.let {
            val flashIndex = it["flashMode"] as? Int ?: 0
            currentFlashMode = when (flashIndex) {
                1 -> ImageCapture.FLASH_MODE_ON
                2 -> ImageCapture.FLASH_MODE_AUTO
                else -> ImageCapture.FLASH_MODE_OFF
            }
            val lensIndex = it["cameraLens"] as? Int ?: 0
            lensFacing = if (lensIndex == 1) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
        }
        container.addView(previewView)
        channel.setMethodCallHandler(this)
        bindCamera()
        orientationEventListener.enable()
    }

    override fun getView(): View = container

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capture" -> {
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null || imageCapture == null || !captureInProgress.compareAndSet(false, true)) {
                    result.success(false)
                    return
                }
                try {
                    queueCapture(CaptureMetadata.from(arguments))
                    result.success(true)
                } catch (error: Exception) {
                    captureInProgress.set(false)
                    result.error("capture_error", error.message, null)
                }
            }
            "setFlashMode" -> {
                val flashIndex = call.argument<Int>("flashMode") ?: 0
                currentFlashMode = when (flashIndex) {
                    1 -> ImageCapture.FLASH_MODE_ON
                    2 -> ImageCapture.FLASH_MODE_AUTO
                    else -> ImageCapture.FLASH_MODE_OFF
                }
                imageCapture?.flashMode = currentFlashMode
                result.success(true)
            }
            "setCameraLens" -> {
                val lensIndex = call.argument<Int>("cameraLens") ?: 0
                lensFacing = if (lensIndex == 1) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
                bindCamera()
                result.success(true)
            }
            "setZoom" -> {
                val zoom = call.argument<Double>("zoom")?.toFloat() ?: 0f
                camera?.cameraControl?.setLinearZoom(zoom)
                result.success(true)
            }
            "focusAtPoint" -> {
                val x = call.argument<Double>("x")?.toFloat() ?: 0.5f
                val y = call.argument<Double>("y")?.toFloat() ?: 0.5f
                val width = previewView.width.toFloat()
                val height = previewView.height.toFloat()
                if (width > 0 && height > 0) {
                    val factory = previewView.meteringPointFactory
                    val point = factory.createPoint(x * width, y * height)
                    val action = androidx.camera.core.FocusMeteringAction.Builder(point, androidx.camera.core.FocusMeteringAction.FLAG_AF or androidx.camera.core.FocusMeteringAction.FLAG_AE)
                        .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
                        .build()
                    camera?.cameraControl?.startFocusAndMetering(action)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun bindCamera() {
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener(
            {
                try {
                    val cameraProvider = future.get()
                    provider = cameraProvider
                    preview = Preview.Builder().build().also {
                        it.surfaceProvider = previewView.surfaceProvider
                    }
                    val captureMode = if (currentFlashMode == ImageCapture.FLASH_MODE_OFF && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        ImageCapture.CAPTURE_MODE_ZERO_SHUTTER_LAG
                    } else {
                        ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY
                    }
                    imageCapture = ImageCapture.Builder()
                        .setCaptureMode(captureMode)
                        .setOutputFormat(ImageCapture.OUTPUT_FORMAT_JPEG)
                        .setJpegQuality(92)
                        .setFlashMode(currentFlashMode)
                        .build()
                    cameraProvider.unbindAll()
                    val cameraSelector = CameraSelector.Builder()
                        .requireLensFacing(lensFacing)
                        .build()
                    camera = cameraProvider.bindToLifecycle(
                        activity as LifecycleOwner,
                        cameraSelector,
                        preview,
                        imageCapture,
                    )
                    channel.invokeMethod("onCameraReady", null)
                } catch (error: Exception) {
                    channel.invokeMethod("onCameraError", error.message ?: "Camera unavailable.")
                }
            },
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun queueCapture(metadata: CaptureMetadata) {
        val startedAt = SystemClock.elapsedRealtime()
        val capture = imageCapture ?: throw IllegalStateException("Camera is not ready.")
        capture.targetRotation = currentDeviceRotation
        val source = File.createTempFile("capture_", ".jpg", activity.cacheDir)
        val gps = Location("GeoSnap").apply {
            latitude = metadata.latitude
            longitude = metadata.longitude
            altitude = metadata.altitude
            accuracy = metadata.accuracy.toFloat()
            time = metadata.capturedAtMillis
        }
        val output = ImageCapture.OutputFileOptions.Builder(source)
            .setMetadata(ImageCapture.Metadata().apply { location = gps })
            .build()

        capture.takePicture(
            output,
            cameraExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    Log.i(PERF_TAG, "shutter_jpeg_ms=${SystemClock.elapsedRealtime() - startedAt}")
                    captureInProgress.set(false)
                    notifyFlutter("onShutterTaken", null)
                    processingScope.launch {
                        try {
                            val uri = processor.process(source, metadata)
                            Log.i(PERF_TAG, "capture_to_saved_ms=${SystemClock.elapsedRealtime() - startedAt}")
                            notifyFlutter("onPhotoSaved", uri)
                        } catch (error: Exception) {
                            source.delete()
                            notifyFlutter("onPhotoError", error.message ?: "Unable to save photo.")
                        }
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    source.delete()
                    captureInProgress.set(false)
                    notifyFlutter("onPhotoError", exception.message ?: "Unable to capture photo.")
                }
            },
        )
    }

    private fun notifyFlutter(method: String, argument: Any?) {
        activity.runOnUiThread { channel.invokeMethod(method, argument) }
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        orientationEventListener.disable()
        preview?.let { provider?.unbind(it) }
        imageCapture?.let { provider?.unbind(it) }
        processingScope.cancel()
        cameraExecutor.shutdown()
        container.removeAllViews()
    }

    private companion object {
        const val PERF_TAG = "GeoSnapPerf"
    }
}
