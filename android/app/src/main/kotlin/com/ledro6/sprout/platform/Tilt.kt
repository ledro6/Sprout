package com.ledro6.sprout.platform

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.model.Sway
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Наклон телефона — источник параллакса узора, и он же слышит тряску.
 * Отсчёт — от медленно ползущей «привычной» точки, а не от вертикали: так
 * узор не упирается в край, как бы ни держали телефон. Датчик включён, только
 * пока фон на экране. Оси и знаки — как у iPhone: сила тяжести в долях `g`,
 * от экрана к глазу — минус.
 */
object Tilt : SensorEventListener {
    /** Общий сдвиг узора, dp. */
    var shiftX by mutableStateOf(0f)
        private set
    var shiftY by mutableStateOf(0f)
        private set

    /** Расхождение слоёв фигурок, огрублённое до полупункта, — пары x, y. */
    var lag: List<Float> by mutableStateOf(emptyList())
        private set

    /** Меняется в покое — и с ним жребий слоёв. */
    var era by mutableIntStateOf(0)
        private set

    var parallax = true
        set(value) {
            if (field == value) return
            field = value
            if (!value) rest()
        }

    private var manager: SensorManager? = null
    private var watchers = 0
    private var baseX = 0.0
    private var baseZ = 0.0
    private var based = false
    private val places = DoubleArray(Sway.eases.size * 2)
    private var placed = false
    private var calm = 0.0
    private var shaken = 0.0
    private var lastSample = 0L
    private var lastShake = 0L

    private const val GAIN = Metrics.PARALLAX / 0.3
    private const val BASE_EASE = 0.011
    private const val EASE = 0.12
    private const val SHAKE_FORCE = 1.5
    private const val SHAKE_SECONDS = 2.2
    private const val SHAKE_FADE = 2.0

    fun watch(context: Context) {
        watchers += 1
        if (watchers != 1) return
        val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        manager = sensors
        based = false
        shaken = 0.0
        lastSample = 0L
        val gravity = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gravity?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        sensors.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)?.let {
            sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    fun unwatch() {
        watchers = max(0, watchers - 1)
        if (watchers != 0) return
        runCatching { manager?.unregisterListener(this) }
        manager = null
        rest()
    }

    private fun rest() {
        based = false
        placed = false
        shiftX = 0f
        shiftY = 0f
        lag = emptyList()
        calm = 0.0
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_GRAVITY, Sensor.TYPE_ACCELEROMETER ->
                step(-event.values[0] / SensorManager.GRAVITY_EARTH.toDouble(), -event.values[2] / SensorManager.GRAVITY_EARTH.toDouble())
            Sensor.TYPE_LINEAR_ACCELERATION -> feel(event.values[0], event.values[1], event.values[2])
        }
    }

    private fun step(x: Double, z: Double) {
        if (!based) {
            baseX = x
            baseZ = z
            based = true
            return
        }
        val seenX = baseX
        val seenZ = baseZ
        baseX += (x - seenX) * BASE_EASE
        baseZ += (z - seenZ) * BASE_EASE
        if (!parallax) return
        val targetX = limit(-(x - seenX) * GAIN)
        val targetY = limit(-(z - seenZ) * GAIN)
        val nextX = shiftX + (targetX - shiftX) * EASE
        val nextY = shiftY + (targetY - shiftY) * EASE
        shiftX = nextX.toFloat()
        shiftY = nextY.toFloat()
        if (!placed) {
            for (i in Sway.eases.indices) {
                places[2 * i] = nextX
                places[2 * i + 1] = nextY
            }
            placed = true
        }
        Sway.settle(places, targetX, targetY)
        val fresh = List(places.size) { rough(Sway.hold(places[it] - if (it % 2 == 0) nextX else nextY)) }
        if (fresh != lag) lag = fresh
        if (fresh.all { it == 0f }) {
            calm += 1.0 / 50
            if (calm >= Sway.SHUFFLE_SECONDS) {
                calm = 0.0
                era += 1
            }
        } else {
            calm = 0.0
        }
    }

    private fun rough(value: Double): Float = ((value / 0.5).roundToInt() * 0.5).toFloat()

    private fun limit(value: Double): Double = min(max(value, -Metrics.PARALLAX), Metrics.PARALLAX)

    /** Трясут ли телефон: сила сверх 1.5 g, накопленная за 2.2 секунды. */
    private fun feel(x: Float, y: Float, z: Float) {
        val now = SystemClock.elapsedRealtime()
        val gap = if (lastSample == 0L) 0.0 else min(max((now - lastSample) / 1000.0, 0.0), 0.1)
        lastSample = now
        val force = sqrt((x * x + y * y + z * z).toDouble()) / SensorManager.GRAVITY_EARTH
        if (force <= SHAKE_FORCE) {
            shaken = max(0.0, shaken - gap * SHAKE_FADE)
            return
        }
        shaken += gap
        if (shaken < SHAKE_SECONDS) return
        shaken = 0.0
        if (now - lastShake < 1000) return
        lastShake = now
        if (Effects.frenzy()) Feel.frenzy()
    }
}
