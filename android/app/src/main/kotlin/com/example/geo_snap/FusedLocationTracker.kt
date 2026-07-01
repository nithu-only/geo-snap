package com.example.geo_snap

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.plugin.common.EventChannel

class FusedLocationTracker(private val activity: Activity) : EventChannel.StreamHandler {
    private val client: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(activity)
    private var eventSink: EventChannel.EventSink? = null

    private val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1_000L)
        .setMinUpdateIntervalMillis(500L)
        .setMinUpdateDistanceMeters(0f)
        .build()

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            eventSink?.success(
                mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                    "altitude" to if (location.hasAltitude()) location.altitude else 0.0,
                    "timeMillis" to location.time,
                ),
            )
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (!hasLocationPermission()) {
            events.error("location_permission", "Location permission is not granted.", null)
            return
        }
        client.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                callback.onLocationResult(LocationResult.create(listOf(location)))
            }
        }
        client.requestLocationUpdates(request, callback, Looper.getMainLooper())
    }

    override fun onCancel(arguments: Any?) {
        client.removeLocationUpdates(callback)
        eventSink = null
    }

    fun dispose() {
        client.removeLocationUpdates(callback)
        eventSink = null
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED || ActivityCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }
}
