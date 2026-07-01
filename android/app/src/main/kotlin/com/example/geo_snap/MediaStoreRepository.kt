package com.example.geo_snap

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.OutputStream

class MediaStoreRepository(private val resolver: ContentResolver) {
    private val relativePath = Environment.DIRECTORY_PICTURES + "/GeoSnap/"
    private val collection =
        MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    fun createPending(filename: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        return resolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create MediaStore entry.")
    }

    fun openOutput(uri: Uri): OutputStream {
        return resolver.openOutputStream(uri, "w")
            ?: throw IllegalStateException("Unable to open MediaStore output stream.")
    }

    fun finishPending(uri: Uri) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.IS_PENDING, 0)
        }
        resolver.update(uri, values, null, null)
    }

    fun saveBytes(bytes: ByteArray, filename: String): String {
        val uri = createPending(filename)
        try {
            openOutput(uri).use { it.write(bytes) }
            finishPending(uri)
            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    fun listImages(): List<Map<String, Any>> {
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
        )
        val results = mutableListOf<Map<String, Any>>()
        val selection = "${MediaStore.Images.Media.RELATIVE_PATH}=?"
        val selectionArgs = arrayOf(relativePath)
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        resolver.query(collection, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                results.add(
                    mapOf(
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "name" to (cursor.getString(nameColumn) ?: "image.jpg"),
                        "dateMillis" to cursor.getLong(dateColumn) * 1_000L,
                    ),
                )
            }
        }
        return results
    }

    fun readImage(uriText: String): ByteArray {
        return resolver.openInputStream(Uri.parse(uriText))?.use { it.readBytes() }
            ?: throw IllegalStateException("Unable to read image.")
    }

    fun delete(uriText: String) {
        resolver.delete(Uri.parse(uriText), null, null)
    }
}
