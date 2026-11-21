package com.nithu.geosnap

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

class DeviceTiltTracker(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        ?: sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var eventSink: EventChannel.EventSink? = null
    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private var lastEmitTime = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (rotationSensor != null) {
            sensorManager?.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        if (now - lastEmitTime < 33) return // ~30 fps updates for fluid and battery-efficient rendering
        lastEmitTime = now

        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientation)
            val pitch = Math.toDegrees(orientation[1].toDouble())
            val roll = Math.toDegrees(orientation[2].toDouble())
            eventSink?.success(mapOf("roll" to roll, "pitch" to pitch))
        } else {
            val ax = event.values[0].toDouble()
            val ay = event.values[1].toDouble()
            val az = event.values[2].toDouble()
            val roll = Math.toDegrees(Math.atan2(-ax, Math.sqrt(ay * ay + az * az)))
            val pitch = Math.toDegrees(Math.atan2(ay, Math.sqrt(ax * ax + az * az)))
            eventSink?.success(mapOf("roll" to roll, "pitch" to pitch))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun dispose() {
        sensorManager?.unregisterListener(this)
        eventSink = null
    }
}
