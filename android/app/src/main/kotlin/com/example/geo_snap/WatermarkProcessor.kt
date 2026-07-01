package com.example.geo_snap

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
    val mapBytes: ByteArray?,
) {
    companion object {
        fun from(arguments: Map<*, *>): CaptureMetadata {
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
                mapBytes = arguments["mapBytes"] as? ByteArray,
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
        val destination = mediaStore.createPending(filename)
        try {
            mediaStore.openOutput(destination).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 94, output)) {
                    throw IllegalStateException("Unable to encode final JPEG.")
                }
            }
            restoreExif(sourceExif, destination, bitmap, metadata)
            mediaStore.finishPending(destination)
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
        val canvas = Canvas(bitmap)
        val scale = max(bitmap.width / 1600f, 1f)
        val margin = 24f * scale
        val padding = 18f * scale
        val radius = 18f * scale
        val lineHeight = 34f * scale
        textPaint.textSize = 24f * scale
        titlePaint.textSize = 28f * scale

        val lines = ArrayList<String>(4)
        lines.add(if (metadata.showAddress) metadata.address else "GeoSnap")
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
        lines.add(timestampFormat(metadata.timestampPattern).format(Date(metadata.capturedAtMillis)))
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
        val panelWidth = min(
            bitmap.width - margin * 2,
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
        if (metadata.template == 2) {
            panelRect.set(left, top, left + 8f * scale, top + panelHeight)
            canvas.drawRoundRect(panelRect, radius, radius, accentPaint)
        }

        var textX = left + padding
        if (map != null) {
            mapSourceRect.set(0, 0, map.width, map.height)
            mapDestinationRect.set(textX, top + padding, textX + mapWidth, top + padding + mapHeight)
            canvas.drawBitmap(map, mapSourceRect, mapDestinationRect, null)
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
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
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
