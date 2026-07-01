package com.example.geotag_camera

import android.app.Activity
import android.content.Context
import android.location.Location
import android.os.SystemClock
import android.util.Log
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
        return NativeCameraView(activity, messenger, viewId, processor)
    }
}

class NativeCameraView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    viewId: Int,
    private val processor: WatermarkProcessor,
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
    private val channel = MethodChannel(messenger, "geotag_camera/camera_$viewId")
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val processingScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val captureInProgress = AtomicBoolean(false)
    private var provider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var preview: Preview? = null

    init {
        container.addView(previewView)
        channel.setMethodCallHandler(this)
        bindCamera()
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
                    imageCapture = ImageCapture.Builder()
                        .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                        .setOutputFormat(ImageCapture.OUTPUT_FORMAT_JPEG)
                        .setJpegQuality(94)
                        .build()
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        activity as LifecycleOwner,
                        CameraSelector.DEFAULT_BACK_CAMERA,
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
        capture.targetRotation = previewView.display?.rotation ?: Surface.ROTATION_0
        val source = File.createTempFile("capture_", ".jpg", activity.cacheDir)
        val gps = Location("GeoTag Camera").apply {
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
                    processingScope.launch {
                        try {
                            val uri = processor.process(source, metadata)
                            Log.i(PERF_TAG, "capture_to_saved_ms=${SystemClock.elapsedRealtime() - startedAt}")
                            notifyFlutter("onPhotoSaved", uri)
                        } catch (error: Exception) {
                            source.delete()
                            notifyFlutter("onPhotoError", error.message ?: "Unable to save photo.")
                        } finally {
                            captureInProgress.set(false)
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
        preview?.let { provider?.unbind(it) }
        imageCapture?.let { provider?.unbind(it) }
        processingScope.cancel()
        cameraExecutor.shutdown()
        container.removeAllViews()
    }

    private companion object {
        const val PERF_TAG = "GeoTagPerf"
    }
}
