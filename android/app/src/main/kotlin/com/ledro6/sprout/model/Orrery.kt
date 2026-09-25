package com.ledro6.sprout.model

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Планетарий сада. Растение — планета, срок полива — год её орбиты. Наверху
 * луч полива: планета доходит до него, когда земля высыхает, и политая
 * проходит сквозь него на новый круг — ровно, без скачка.
 */
object Orrery {
    /** Половина светлого сектора вокруг луча — только рисунок. */
    const val GATE = 12.0 * PI / 180

    const val INNER = 0.3
    const val OUTER = 0.97

    /** Сколько дней сада видно вперёд. */
    const val REACH = 30.0

    data class Orbit(
        val id: String,
        val name: String,
        val period: Double,
        val moisture: Double,
        val radius: Double,
        val rank: Int,
    )

    data class Crossing(val id: String, val day: Double, val rank: Int)

    data class Parade(val day: Int, val ids: List<String>, val names: List<String>)

    data class Planet(val id: String, val name: String, val radius: Double, val angle: Double, val moisture: Double)

    data class Flash(val radius: Double, val strength: Double)

    /** Кадр: сейчас — живой сад, впереди — если поливать вовремя. */
    fun sky(orbits: List<Orbit>, ahead: Double, drift: Double = 0.0): List<Planet> = orbits.map { orbit ->
        val level = if (ahead > 0) moisture(orbit, ahead)
        else max(0.0, orbit.moisture - max(drift, 0.0) / orbit.period)
        Planet(orbit.id, orbit.name, orbit.radius, angle(level), level)
    }

    fun flashes(crossings: List<Crossing>, orbits: List<Orbit>, at: Double, span: Double = 1.0): List<Flash> {
        val radius = HashMap<String, Double>()
        for (orbit in orbits) radius.putIfAbsent(orbit.id, orbit.radius)
        return crossings.mapNotNull { crossing ->
            val since = at - crossing.day
            val place = radius[crossing.id]
            if (since < 0 || since >= span || place == null) null else Flash(place, 1 - since / span)
        }
    }

    /** По сроку от ближней к дальней; равные — по кличке. */
    fun orbits(plants: List<Plant>): List<Orbit> {
        val sorted = plants.filter { it.period > 0 }.sortedWith(
            compareBy<Plant> { it.period }.thenBy { it.name }.thenBy { it.id },
        )
        val last = max(sorted.size - 1, 1)
        return sorted.mapIndexed { rank, plant ->
            val step = if (sorted.size > 1) rank.toDouble() / last else 0.5
            Orbit(plant.id, plant.name, plant.period, plant.moisture, INNER + (OUTER - INNER) * step, rank)
        }
    }

    /** Угол по часовой стрелке от луча: только что политая — на нём. */
    fun angle(moisture: Double): Double = (1 - moisture.coerceIn(0.0, 1.0)) * 2 * PI

    /** Влажность через `days` дней сада, если поливать ровно тогда, когда земля высохла. */
    fun moisture(orbit: Orbit, days: Double): Double {
        if (days <= 0 || orbit.period <= 0) return orbit.moisture
        val dry = orbit.moisture * orbit.period
        if (days < dry) return orbit.moisture - days / orbit.period
        val into = (days - dry) % orbit.period
        return 1 - into / orbit.period
    }

    fun crossings(orbits: List<Orbit>, within: Double): List<Crossing> {
        val out = mutableListOf<Crossing>()
        for (orbit in orbits) {
            if (orbit.period <= 0) continue
            var day = orbit.moisture * orbit.period
            var turns = 0
            while (day <= within && turns < 1_000) {
                out.add(Crossing(orbit.id, day, orbit.rank))
                day += orbit.period
                turns += 1
            }
        }
        return out.sortedWith(compareBy<Crossing> { it.day }.thenBy { it.rank })
    }

    /** Самые большие парады — сначала многолюдные, из равных — ближние. */
    fun parades(orbits: List<Orbit>, within: Double = REACH, least: Int = 3): List<Parade> {
        val names = HashMap<String, String>()
        for (orbit in orbits) names.putIfAbsent(orbit.id, orbit.name)
        val byDay = LinkedHashMap<Int, MutableList<String>>()
        for (crossing in crossings(orbits, within)) {
            val day = crossing.day.roundedInt()
            if (day > within) continue
            byDay.getOrPut(day) { mutableListOf() }.add(crossing.id)
        }
        return byDay.filter { it.value.size >= least }
            .map { (day, ids) -> Parade(day, ids, ids.mapNotNull { names[it] }) }
            .sortedWith(compareByDescending<Parade> { it.ids.size }.thenBy { it.day })
    }
}

/**
 * Музыка сфер: каждый полив месяца — нота, ровно в миг, когда планета
 * проходит луч. Ближние орбиты поют выше; лад — пентатоника. Звук собирается
 * здесь, без звуковых библиотек: шкатулка с обертонами, стерео и зал.
 */
object Spheres {
    const val RATE = 44_100
    const val CHANNELS = 2
    const val SECONDS = 20.0
    const val TAIL = 3.0
    const val RING = 2.4

    data class Note(val at: Double, val pitch: Double, val pan: Double = 0.0)

    fun pitch(rank: Int, count: Int): Double {
        val scale = intArrayOf(0, 2, 4, 7, 9)
        val degrees = 12
        val from = if (count > 1) (count - 1 - rank).toDouble() / (count - 1) else 0.5
        val degree = (from * (degrees - 1)).roundedInt()
        val semitone = scale[degree % scale.size] + 12 * (degree / scale.size)
        return 220 * 2.0.pow(semitone / 12.0)
    }

    fun notes(crossings: List<Orrery.Crossing>, count: Int, days: Double = Orrery.REACH, seconds: Double = SECONDS): List<Note> =
        crossings.map {
            val side = if (count > 1) it.rank.toDouble() / (count - 1) * 2 - 1 else 0.0
            Note(it.day / days * seconds, pitch(it.rank, count), side * 0.45)
        }

    private class Partial(val ratio: Double, val level: Double, val decay: Double)

    private val partials = listOf(
        Partial(1.0, 1.0, 1.3), Partial(2.0, 0.36, 0.62), Partial(3.0, 0.13, 0.38), Partial(4.07, 0.06, 0.24),
    )

    private const val VOICE = 0.45

    /** Стерео чередованием: левый, правый, левый… */
    fun render(notes: List<Note>, seconds: Double = SECONDS): FloatArray {
        val frames = ((seconds + TAIL) * RATE).toInt()
        val left = DoubleArray(frames)
        val right = DoubleArray(frames)
        val attack = 0.008 * RATE
        val release = 0.4 * RATE
        for (note in notes) {
            val first = (note.at * RATE).toInt()
            if (first < 0 || first >= frames) continue
            val span = min((RING * RATE).toInt(), frames - first)
            val shorter = (440 / max(note.pitch, 1.0)).pow(0.3)
            val pan = note.pan.coerceIn(-1.0, 1.0)
            val toLeft = cos((pan + 1) * PI / 4)
            val toRight = sin((pan + 1) * PI / 4)
            for (partial in partials) {
                val step = 2 * PI * note.pitch * partial.ratio / RATE
                val c = cos(step)
                val s = sin(step)
                var x = 1.0
                var y = 0.0
                val fade = exp(-1 / (partial.decay * shorter * RATE))
                var level = partial.level * VOICE
                for (n in 0 until span) {
                    if (level <= 0.000_2) break
                    val into = n.toDouble()
                    val rest = (span - n).toDouble()
                    val edge = (if (into < attack) 0.5 - 0.5 * cos(PI * into / attack) else 1.0) *
                        (if (rest < release) 0.5 - 0.5 * cos(PI * rest / release) else 1.0)
                    val value = y * level * edge
                    left[first + n] += value * toLeft
                    right[first + n] += value * toRight
                    val nx = x * c - y * s
                    y = x * s + y * c
                    x = nx
                    level *= fade
                }
            }
        }
        pad(notes, left, right)
        hall(left, 0)
        hall(right, 23)
        limit(left, right)
        val out = FloatArray(frames * CHANNELS)
        val close = 0.05 * RATE
        for (n in 0 until frames) {
            val rest = (frames - n).toDouble()
            val edge = if (rest < close) rest / close else 1.0
            out[2 * n] = (left[n] * edge).toFloat()
            out[2 * n + 1] = (right[n] * edge).toFloat()
        }
        return out
    }

    private fun limit(left: DoubleArray, right: DoubleArray) {
        val ceiling = 0.9
        val back = exp(-1 / (0.3 * RATE))
        var held = 0.0
        for (n in left.indices) {
            held = max(max(abs(left[n]), abs(right[n])), held * back)
            if (held <= ceiling) continue
            left[n] *= ceiling / held
            right[n] *= ceiling / held
        }
    }

    private fun pad(notes: List<Note>, left: DoubleArray, right: DoubleArray) {
        val first = notes.minOfOrNull { it.at } ?: return
        if (first < 0) return
        val frames = left.size
        val start = (first * RATE).toInt()
        if (start >= frames) return
        val chord = listOf(110.0 to 0.07, 164.81 to 0.05, 220.0 to 0.04)
        val rise = 1.6 * RATE
        val fall = 2.6 * RATE
        for ((index, tone) in chord.withIndex()) {
            val step = 2 * PI * tone.first / RATE
            val c = cos(step)
            val s = sin(step)
            var x = 1.0
            var y = 0.0
            val slow = 2 * PI * (0.11 + 0.03 * index) / RATE
            val sc = cos(slow)
            val ss = sin(slow)
            var bx = 1.0
            var by = 0.0
            for (n in start until frames) {
                val swell = min((n - start) / rise, 1.0) * min((frames - n) / fall, 1.0)
                val value = y * tone.second * VOICE * swell * (0.8 + 0.2 * by)
                left[n] += value
                right[n] += value
                val nx = x * c - y * s
                y = x * s + y * c
                x = nx
                val nbx = bx * sc - by * ss
                by = bx * ss + by * sc
                bx = nbx
            }
        }
    }

    /** Зал Шрёдера: четыре гребня и два всепропускающих. */
    private fun hall(signal: DoubleArray, seed: Int) {
        val dry = signal.copyOf()
        val wet = DoubleArray(dry.size)
        for (delay in intArrayOf(1116, 1188, 1277, 1356).map { it + seed }) {
            val line = DoubleArray(delay)
            var index = 0
            var soft = 0.0
            for (n in dry.indices) {
                val out = line[index]
                soft = out * 0.75 + soft * 0.25
                line[index] = dry[n] + soft * 0.8
                index = (index + 1) % delay
                wet[n] += out
            }
        }
        for (delay in intArrayOf(556, 441).map { it + seed / 2 }) {
            val line = DoubleArray(delay)
            var index = 0
            for (n in wet.indices) {
                val held = line[index]
                val out = held - wet[n]
                line[index] = wet[n] + held * 0.5
                index = (index + 1) % delay
                wet[n] = out
            }
        }
        for (n in signal.indices) signal[n] = dry[n] * 0.85 + wet[n] * 0.07
    }

    /** 16 бит, стерео чередованием — для `AudioTrack`. */
    fun pcm(samples: FloatArray): ShortArray =
        ShortArray(samples.size) { (samples[it].coerceIn(-1f, 1f) * Short.MAX_VALUE).toInt().toShort() }

    /** WAV-файл — для проверок и на случай, если плеер попросит файл. */
    fun wav(samples: FloatArray): ByteArray {
        val bytes = samples.size * 2
        val buffer = ByteBuffer.allocate(44 + bytes).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray()).putInt(36 + bytes).put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(CHANNELS.toShort())
        buffer.putInt(RATE).putInt(RATE * 2 * CHANNELS).putShort((2 * CHANNELS).toShort()).putShort(16)
        buffer.put("data".toByteArray()).putInt(bytes)
        for (value in pcm(samples)) buffer.putShort(value)
        return buffer.array()
    }
}
