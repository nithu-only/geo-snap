package com.nithu.geosnap

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import androidx.exifinterface.media.ExifInterface

class MainActivity : FlutterActivity() {
    private var locationTracker: FusedLocationTracker? = null
    private var tiltTracker: DeviceTiltTracker? = null
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        const val REQUEST_CODE_PICK_DIRECTORY = 1001
    }

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

        tiltTracker = DeviceTiltTracker(this).also { tracker ->
            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "geo_snap/device_tilt",
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
                        val saveFolder = call.argument<String>("saveFolder")
                        if (bytes == null || filename.isNullOrBlank()) {
                            result.error("bad_args", "Missing image bytes or filename.", null)
                        } else {
                            result.success(mediaStore.saveBytes(bytes, filename, saveFolder))
                        }
                    }
                    "listImages" -> {
                        val saveFolder = call.argument<String>("saveFolder")
                        val saveFolderUri = call.argument<String>("saveFolderUri")
                        if (!saveFolderUri.isNullOrBlank()) {
                            result.success(listImagesInTree(saveFolderUri))
                        } else {
                            result.success(mediaStore.listImages(saveFolder))
                        }
                    }
                    "pickDirectory" -> {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
                    }
                    "readImage" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("bad_args", "Missing image URI.", null)
                        } else {
                            result.success(mediaStore.readImage(uri))
                        }
                    }
                    "readThumbnail" -> {
                        val uri = call.argument<String>("uri")
                        val width = call.argument<Int>("width") ?: 250
                        val height = call.argument<Int>("height") ?: 250
                        if (uri.isNullOrBlank()) {
                            result.error("bad_args", "Missing image URI.", null)
                        } else {
                            try {
                                val parsedUri = android.net.Uri.parse(uri)
                                val bytes = getThumbnailBytes(parsedUri, width, height)
                                result.success(bytes)
                            } catch (error: Exception) {
                                result.error("read_error", error.message, null)
                            }
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DIRECTORY) {
            val res = pendingResult
            pendingResult = null
            if (resultCode == RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(treeUri, takeFlags)
                    var folderName = "Device Folder"
                    try {
                        val docUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(
                            treeUri,
                            android.provider.DocumentsContract.getTreeDocumentId(treeUri)
                        )
                        contentResolver.query(docUri, null, null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val nameIdx = cursor.getColumnIndex(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                                if (nameIdx != -1) {
                                    folderName = cursor.getString(nameIdx)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        // ignore fallback
                    }
                    res?.success(mapOf("uri" to treeUri.toString(), "label" to folderName))
                } else {
                    res?.success(null)
                }
            } else {
                res?.success(null)
            }
        }
    }

    private fun listImagesInTree(treeUriText: String): List<Map<String, Any>> {
        val treeUri = android.net.Uri.parse(treeUriText)
        val docId = android.provider.DocumentsContract.getTreeDocumentId(treeUri)
        val childrenUri = android.provider.DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        val projection = arrayOf(
            android.provider.DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            android.provider.DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val results = mutableListOf<Map<String, Any>>()
        try {
            contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndex(android.provider.DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndex(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val dateCol = cursor.getColumnIndex(android.provider.DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                if (idCol != -1 && nameCol != -1 && dateCol != -1) {
                    while (cursor.moveToNext()) {
                        val childDocId = cursor.getString(idCol)
                        val childUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(treeUri, childDocId)
                        
                        var latitude: Double? = null
                        var longitude: Double? = null
                        try {
                            contentResolver.openFileDescriptor(childUri, "r")?.use { fd ->
                                val exifInterface = ExifInterface(fd.fileDescriptor)
                                val latLong = exifInterface.latLong
                                if (latLong != null) {
                                    latitude = latLong[0]
                                    longitude = latLong[1]
                                }
                            }
                        } catch (e: Exception) {}

                        val itemMap = mutableMapOf<String, Any>(
                            "uri" to childUri.toString(),
                            "name" to (cursor.getString(nameCol) ?: "image.jpg"),
                            "dateMillis" to cursor.getLong(dateCol)
                        )
                        if (latitude != null && longitude != null) {
                            itemMap["latitude"] = latitude!!
                            itemMap["longitude"] = longitude!!
                        }
                        results.add(itemMap)
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        results.sortByDescending { it["dateMillis"] as? Long ?: 0L }
        return results
    }

    private fun getThumbnailBytes(uri: android.net.Uri, reqWidth: Int, reqHeight: Int): ByteArray {
        contentResolver.openInputStream(uri).use { input ->
            val options = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeStream(input, null, options)
            var inSampleSize = 1
            val height = options.outHeight
            val width = options.outWidth
            if (height > reqHeight || width > reqWidth) {
                val halfHeight = height / 2
                val halfWidth = width / 2
                while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                    inSampleSize *= 2
                }
            }
            options.inJustDecodeBounds = false
            options.inSampleSize = inSampleSize
            contentResolver.openInputStream(uri).use { input2 ->
                val bitmap = android.graphics.BitmapFactory.decodeStream(input2, null, options)
                if (bitmap != null) {
                    java.io.ByteArrayOutputStream().use { output ->
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, output)
                        bitmap.recycle()
                        return output.toByteArray()
                    }
                }
            }
        }
        throw java.io.IOException("Unable to generate thumbnail.")
    }

    override fun onDestroy() {
        locationTracker?.dispose()
        locationTracker = null
        tiltTracker?.dispose()
        tiltTracker = null
        super.onDestroy()
    }
}
