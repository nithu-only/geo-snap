package com.nithu.geosnap

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.location.Location
import android.net.Uri
import android.provider.DocumentsContract
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

data class CaptureMetadata(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val accuracy: Double,
    val capturedAtMillis: Long,
    val address: String,
    val template: Int,
    val position: Int,
    val timestampPattern: String,
    val showAddress: Boolean,
    val showCoordinates: Boolean,
    val showAccuracy: Boolean,
    val showMapPreview: Boolean,
    val showAltitude: Boolean,
    val showTimestamp: Boolean,
    val mapBytes: ByteArray?,
    val addressHeader: String?,
    val addressBody: String?,
    val saveFolder: String?,
    val saveFolderUri: String?,
) {
    companion object {
        fun from(arguments: Map<*, *>) : CaptureMetadata {
            return CaptureMetadata(
                latitude = (arguments["latitude"] as Number).toDouble(),
                longitude = (arguments["longitude"] as Number).toDouble(),
                altitude = (arguments["altitude"] as? Number)?.toDouble() ?: 0.0,
                accuracy = (arguments["accuracy"] as Number).toDouble(),
                capturedAtMillis = (arguments["capturedAtMillis"] as Number).toLong(),
                address = arguments["address"] as? String ?: "Location unavailable",
                template = (arguments["template"] as Number).toInt(),
                position = (arguments["position"] as Number).toInt(),
                timestampPattern = arguments["timestampPattern"] as String,
                showAddress = arguments["showAddress"] as Boolean,
                showCoordinates = arguments["showCoordinates"] as Boolean,
                showAccuracy = arguments["showAccuracy"] as Boolean,
                showMapPreview = arguments["showMapPreview"] as Boolean,
                showAltitude = arguments["showAltitude"] as? Boolean ?: true,
                showTimestamp = arguments["showTimestamp"] as? Boolean ?: true,
                mapBytes = arguments["mapBytes"] as? ByteArray,
                addressHeader = arguments["addressHeader"] as? String,
                addressBody = arguments["addressBody"] as? String,
                saveFolder = arguments["saveFolder"] as? String,
                saveFolderUri = arguments["saveFolderUri"] as? String,
            )
        }
    }
}

class WatermarkProcessor(
    private val resolver: ContentResolver,
    private val mediaStore: MediaStoreRepository,
) {
    private val panelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(188, 0, 0, 0)
        style = Paint.Style.FILL
    }
    private val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(255, 198, 41)
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(225, 232, 235)
        typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL)
    }
    private val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD)
    }
    private val panelRect = RectF()
    private val mapSourceRect = Rect()
    private val mapDestinationRect = RectF()
    private val filenameFormat = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US)
    private var dateFormatPattern = ""
    private var dateFormat = SimpleDateFormat("dd-MMM-yyyy hh:mm a", Locale.ENGLISH)

    fun process(source: File, metadata: CaptureMetadata): String {
        val sourceExif = ExifInterface(source)
        val decoded = BitmapFactory.decodeFile(
            source.absolutePath,
            BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inMutable = true
            },
        ) ?: throw IllegalStateException("Unable to decode captured JPEG.")
        val bitmap = orientBitmap(decoded, sourceExif)
        drawWatermark(bitmap, metadata)

        val filename = "IMG_${filenameFormat.format(Date(metadata.capturedAtMillis))}.jpg"
        val destination = if (!metadata.saveFolderUri.isNullOrBlank()) {
            val treeUri = Uri.parse(metadata.saveFolderUri)
            val rootDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, DocumentsContract.getTreeDocumentId(treeUri))
            DocumentsContract.createDocument(resolver, rootDocUri, "image/jpeg", filename)
                ?: throw IllegalStateException("Unable to create document in picked folder.")
        } else {
            mediaStore.createPending(filename, metadata.saveFolder)
        }
        try {
            mediaStore.openOutput(destination).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 94, output)) {
                    throw IllegalStateException("Unable to encode final JPEG.")
                }
            }
            restoreExif(sourceExif, destination, bitmap, metadata)
            if (metadata.saveFolderUri.isNullOrBlank()) {
                mediaStore.finishPending(destination)
            }
            return destination.toString()
        } catch (error: Exception) {
            resolver.delete(destination, null, null)
            throw error
        } finally {
            if (bitmap !== decoded) {
                bitmap.recycle()
            }
            if (!decoded.isRecycled) {
                decoded.recycle()
            }
            source.delete()
        }
    }

    private fun drawWatermark(bitmap: Bitmap, metadata: CaptureMetadata) {
        val isLandscape = bitmap.width > bitmap.height
        val refDimension = if (isLandscape) bitmap.height else bitmap.width
        val scale = max(refDimension / 1600f, 1f)
        val margin = 24f * scale
        val padding = 18f * scale
        val radius = 18f * scale

        if (metadata.template == 2) {
            drawGpsMapCameraWatermark(bitmap, metadata, scale, margin, padding, radius)
            return
        }
        if (metadata.template == 3) {
            drawMinimalWatermark(bitmap, metadata, scale, margin, padding)
            return
        }

        val canvas = Canvas(bitmap)
        val lineHeight = 34f * scale
        textPaint.textSize = 24f * scale
        titlePaint.textSize = 28f * scale

        val lines = ArrayList<String>()
        if (metadata.showAddress) {
            lines.add(metadata.addressHeader ?: metadata.address)
        } else {
            lines.add("GeoSnap")
        }
        if (metadata.showCoordinates) {
            lines.add(
                String.format(
                    Locale.US,
                    "Lat %.6f  Long %.6f",
                    metadata.latitude,
                    metadata.longitude,
                ),
            )
        }
        if (metadata.showAltitude) {
            lines.add(String.format(Locale.US, "Alt: %.1fm", metadata.altitude))
        }
        if (metadata.showTimestamp) {
            lines.add(timestampFormat(metadata.timestampPattern).format(Date(metadata.capturedAtMillis)))
        }
        if (metadata.showAccuracy) {
            lines.add("Accuracy: ${metadata.accuracy.toInt()}m")
        }

        val map = if (
            metadata.showMapPreview && metadata.template != 0 && metadata.mapBytes != null
        ) {
            BitmapFactory.decodeByteArray(metadata.mapBytes, 0, metadata.mapBytes.size)
        } else {
            null
        }
        val mapWidth = if (map == null) 0f else 220f * scale
        val mapHeight = if (map == null) 0f else 120f * scale
        val widestText = lines.maxOf { titlePaint.measureText(it) }
        val maxPanelWidth = if (isLandscape) bitmap.width * 0.6f else bitmap.width - margin * 2
        val panelWidth = min(
            maxPanelWidth,
            max(430f * scale, widestText + padding * 2 + if (map == null) 0f else mapWidth + padding),
        )
        val panelHeight = max(lines.size * lineHeight + padding * 2, mapHeight + padding * 2)
        val left = when (metadata.position) {
            1, 3 -> bitmap.width - panelWidth - margin
            else -> margin
        }
        val top = when (metadata.position) {
            2, 3 -> bitmap.height - panelHeight - margin
            else -> margin
        }

        panelRect.set(left, top, left + panelWidth, top + panelHeight)
        canvas.drawRoundRect(panelRect, radius, radius, panelPaint)

        var textX = left + padding
        if (map != null) {
            mapSourceRect.set(0, 0, map.width, map.height)
            mapDestinationRect.set(textX, top + padding, textX + mapWidth, top + padding + mapHeight)
            canvas.drawBitmap(map, mapSourceRect, mapDestinationRect, null)
            drawLocationPin(canvas, mapDestinationRect, scale)
            textX += mapWidth + padding
        }
        val maxTextWidth = left + panelWidth - padding - textX
        lines.forEachIndexed { index, value ->
            val paint = if (index == 0 && metadata.template != 0) titlePaint else textPaint
            val display = ellipsize(value, paint, maxTextWidth)
            val baseline = top + padding - paint.fontMetrics.top + index * lineHeight
            canvas.drawText(display, textX, baseline, paint)
        }
        map?.recycle()
    }

    private fun drawGpsMapCameraWatermark(
        bitmap: Bitmap,
        metadata: CaptureMetadata,
        scale: Float,
        margin: Float,
        padding: Float,
        radius: Float
    ) {
        val canvas = Canvas(bitmap)
        
        val textPaintLocal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(225, 232, 235)
            textSize = 22f * scale
            typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL)
        }
        val titlePaintLocal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 26f * scale
            typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD)
        }

        val lines = ArrayList<String>()
        
        if (metadata.showAddress) {
            lines.add(metadata.addressHeader ?: metadata.address)
        } else {
            lines.add("GeoSnap")
        }

        if (metadata.showAddress && !metadata.addressBody.isNullOrBlank()) {
            lines.add(metadata.addressBody)
        }

        val coordParts = ArrayList<String>()
        if (metadata.showCoordinates) {
            coordParts.add(String.format(Locale.US, "Lat %.6f° Long %.6f°", metadata.latitude, metadata.longitude))
        }
        if (metadata.showAltitude) {
            coordParts.add(String.format(Locale.US, "Alt %.1fm", metadata.altitude))
        }
        if (metadata.showAccuracy) {
            coordParts.add(String.format(Locale.US, "Accuracy: %.0fm", metadata.accuracy))
        }
        if (coordParts.isNotEmpty()) {
            lines.add(coordParts.joinToString("   "))
        }

        if (metadata.showTimestamp) {
            val sdf = SimpleDateFormat("EEEE, dd/MM/yyyy hh:mm a", Locale.US)
            val formattedDate = sdf.format(Date(metadata.capturedAtMillis))
            val tz = java.util.TimeZone.getDefault()
            val offsetMillis = tz.getOffset(metadata.capturedAtMillis)
            val offsetHours = Math.abs(offsetMillis / 3600000)
            val offsetMinutes = Math.abs((offsetMillis % 3600000) / 60000)
            val sign = if (offsetMillis >= 0) "+" else "-"
            val tzOffsetStr = String.format("GMT %s%02d:%02d", sign, offsetHours, offsetMinutes)
            val finalTimestamp = "$formattedDate $tzOffsetStr"
            lines.add(finalTimestamp)
        }

        val map = if (metadata.showMapPreview && metadata.mapBytes != null) {
            try {
                BitmapFactory.decodeByteArray(metadata.mapBytes, 0, metadata.mapBytes.size)
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }

        val mapSize = if (map == null) 0f else 180f * scale
        val mapWidth = mapSize
        val mapHeight = mapSize

        val widestText = lines.mapIndexed { index, s ->
            val paint = if (index == 0) titlePaintLocal else textPaintLocal
            paint.measureText(s)
        }.maxOrNull() ?: 0f

        val isLandscape = bitmap.width > bitmap.height
        val maxPanelWidth = if (isLandscape) bitmap.width * 0.6f else bitmap.width - margin * 2
        val panelWidth = min(
            maxPanelWidth,
            max(450f * scale, widestText + padding * 2 + if (map == null) 0f else mapWidth + padding)
        )

        val lineHeight = 36f * scale
        val textBlockHeight = lines.size * lineHeight
        val panelHeight = max(textBlockHeight + padding * 2, mapHeight + padding * 2)

        val left = when (metadata.position) {
            1, 3 -> bitmap.width - panelWidth - margin
            else -> margin
        }
        val top = when (metadata.position) {
            2, 3 -> bitmap.height - panelHeight - margin
            else -> margin
        }

        panelRect.set(left, top, left + panelWidth, top + panelHeight)
        canvas.drawRoundRect(panelRect, radius, radius, panelPaint)

        var textX = left + padding
        if (map != null) {
            val mapRadius = 12f * scale
            mapSourceRect.set(0, 0, map.width, map.height)
            val mapTop = top + (panelHeight - mapHeight) / 2
            mapDestinationRect.set(textX, mapTop, textX + mapWidth, mapTop + mapHeight)

            canvas.save()
            val mapClipPath = android.graphics.Path().apply {
                addRoundRect(mapDestinationRect, mapRadius, mapRadius, android.graphics.Path.Direction.CW)
            }
            canvas.clipPath(mapClipPath)
            canvas.drawBitmap(map, mapSourceRect, mapDestinationRect, null)
            canvas.restore()

            val mapBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(40, 255, 255, 255)
                style = Paint.Style.STROKE
                strokeWidth = 1f * scale
            }
            canvas.drawRoundRect(mapDestinationRect, mapRadius, mapRadius, mapBorderPaint)

            drawLocationPin(canvas, mapDestinationRect, scale)

            textX += mapWidth + padding
        }

        val textStartTop = top + (panelHeight - textBlockHeight) / 2
        val maxTextWidth = left + panelWidth - padding - textX

        lines.forEachIndexed { index, value ->
            val paint = if (index == 0) titlePaintLocal else textPaintLocal
            val display = ellipsize(value, paint, maxTextWidth)
            val baseline = textStartTop - paint.fontMetrics.top + index * lineHeight
            canvas.drawText(display, textX, baseline, paint)
        }

        map?.recycle()
    }

    private fun drawMinimalWatermark(
        bitmap: Bitmap,
        metadata: CaptureMetadata,
        scale: Float,
        margin: Float,
        padding: Float
    ) {
        val canvas = Canvas(bitmap)
        val lineHeight = 34f * scale

        val alignRight = (metadata.position == 1 || metadata.position == 3)
        
        val textPaintLocal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(240, 240, 240)
            textSize = 24f * scale
            typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL)
            textAlign = if (alignRight) Paint.Align.RIGHT else Paint.Align.LEFT
            setShadowLayer(4f * scale, 2f * scale, 2f * scale, Color.argb(200, 0, 0, 0))
        }
        val titlePaintLocal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 28f * scale
            typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD)
            textAlign = if (alignRight) Paint.Align.RIGHT else Paint.Align.LEFT
            setShadowLayer(4f * scale, 2f * scale, 2f * scale, Color.argb(200, 0, 0, 0))
        }

        val lines = ArrayList<String>()
        if (metadata.showAddress) {
            lines.add(metadata.addressHeader ?: metadata.address)
        } else {
            lines.add("GeoSnap")
        }
        if (metadata.showCoordinates) {
            lines.add(
                String.format(
                    Locale.US,
                    "Lat %.6f  Long %.6f",
                    metadata.latitude,
                    metadata.longitude,
                ),
            )
        }
        if (metadata.showAltitude) {
            lines.add(String.format(Locale.US, "Alt: %.1fm", metadata.altitude))
        }
        if (metadata.showTimestamp) {
            lines.add(timestampFormat(metadata.timestampPattern).format(Date(metadata.capturedAtMillis)))
        }
        if (metadata.showAccuracy) {
            lines.add("Accuracy: ${metadata.accuracy.toInt()}m")
        }

        val x = if (alignRight) bitmap.width - margin else margin
        val textBlockHeight = lines.size * lineHeight

        lines.forEachIndexed { index, value ->
            val paint = if (index == 0) titlePaintLocal else textPaintLocal
            val baseline = if (metadata.position >= 2) {
                val topOfBlock = bitmap.height - margin - textBlockHeight
                topOfBlock - paint.fontMetrics.top + index * lineHeight
            } else {
                margin - paint.fontMetrics.top + index * lineHeight
            }
            canvas.drawText(value, x, baseline, paint)
        }
    }

    private fun drawLocationPin(canvas: Canvas, rect: RectF, scale: Float) {
        val cx = rect.centerX()
        val cy = rect.centerY()

        val pinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(220, 50, 47)
            style = Paint.Style.FILL
        }
        val pinInnerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(80, 10, 10)
            style = Paint.Style.FILL
        }
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 0, 0, 0)
            style = Paint.Style.FILL
        }

        val shadowRadius = 4f * scale
        canvas.drawOval(cx - shadowRadius, cy - shadowRadius / 2, cx + shadowRadius, cy + shadowRadius / 2, shadowPaint)

        val pinHeight = 24f * scale
        val pinWidth = 14f * scale
        val pinPath = android.graphics.Path().apply {
            moveTo(cx, cy)
            cubicTo(cx - pinWidth / 2, cy - pinHeight * 0.4f, cx - pinWidth, cy - pinHeight * 0.7f, cx - pinWidth / 2, cy - pinHeight)
            cubicTo(cx - pinWidth / 4, cy - pinHeight - pinWidth / 2, cx + pinWidth / 4, cy - pinHeight - pinWidth / 2, cx + pinWidth / 2, cy - pinHeight)
            cubicTo(cx + pinWidth, cy - pinHeight * 0.7f, cx + pinWidth / 2, cy - pinHeight * 0.4f, cx, cy)
            close()
        }
        canvas.drawPath(pinPath, pinPaint)

        val dotY = cy - pinHeight * 0.85f
        val dotRadius = 3f * scale
        canvas.drawCircle(cx, dotY, dotRadius, pinInnerPaint)
    }

    private fun timestampFormat(pattern: String): SimpleDateFormat {
        if (dateFormatPattern != pattern) {
            dateFormatPattern = pattern
            dateFormat = SimpleDateFormat(pattern, Locale.ENGLISH)
        }
        return dateFormat
    }

    private fun ellipsize(value: String, paint: Paint, width: Float): String {
        if (paint.measureText(value) <= width) {
            return value
        }
        val suffix = "..."
        val count = paint.breakText(value, true, max(0f, width - paint.measureText(suffix)), null)
        return value.take(max(0, count)) + suffix
    }

    private fun orientBitmap(bitmap: Bitmap, exif: ExifInterface): Bitmap {
        val degrees = when (
            exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (degrees == 0f) {
            return bitmap
        }
        val matrix = Matrix().apply { postRotate(degrees) }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        bitmap.recycle()
        val mutable = rotated.copy(Bitmap.Config.ARGB_8888, true)
        rotated.recycle()
        return mutable
    }

    private fun restoreExif(
        source: ExifInterface,
        destination: Uri,
        bitmap: Bitmap,
        metadata: CaptureMetadata,
    ) {
        resolver.openFileDescriptor(destination, "rw")?.use { descriptor ->
            val target = ExifInterface(descriptor.fileDescriptor)
            exifTags.forEach { tag ->
                source.getAttribute(tag)?.let { target.setAttribute(tag, it) }
            }
            target.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
            target.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, bitmap.width.toString())
            target.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, bitmap.height.toString())
            val gps = Location("GeoSnap").apply {
                latitude = metadata.latitude
                longitude = metadata.longitude
                altitude = metadata.altitude
                accuracy = metadata.accuracy.toFloat()
                time = metadata.capturedAtMillis
            }
            target.setGpsInfo(gps)
            target.saveAttributes()
        } ?: throw IllegalStateException("Unable to update final EXIF metadata.")
    }

    private companion object {
        val exifTags = arrayOf(
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_LENS_MAKE,
            ExifInterface.TAG_LENS_MODEL,
        )
    }
}
