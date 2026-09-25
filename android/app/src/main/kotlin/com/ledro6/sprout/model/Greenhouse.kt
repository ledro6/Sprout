package com.ledro6.sprout.model

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Как растение в AR живёт влажностью — те же числа, что у iPhone
 * (Greenhouse.swift): провисание, желтизна листа, тёмная мокрая земля,
 * распускание при появлении. Здесь одна арифметика; рисует `ar/Figure`.
 */
object Greenhouse {
    const val POT_RADIUS = 0.082f
    const val POT_INNER = 0.068f
    const val SOIL = 0.112f
    const val RIM = 0.133f
    const val WITHER_STEPS = 4

    /** Провисание 0…1: с половины влажности, плавной ступенькой. */
    fun sag(moisture: Double): Float {
        val dry = ((0.5 - moisture) / 0.5).coerceIn(0.0, 1.0)
        return (dry * dry * (3 - 2 * dry)).toFloat()
    }

    /** Желтизна — с порога тревоги, не больше семи десятых: сухой лист ещё зелёный. */
    fun wilt(moisture: Double): Double {
        val dry = ((Thirst.WARN_BELOW - moisture) / Thirst.WARN_BELOW).coerceIn(0.0, 1.0)
        return 0.7 * dry
    }

    /** Ступень увядания 0…1: рисунок меняется ступенями, а не каждый кадр. */
    fun wither(moisture: Double): Float {
        val share = wilt(moisture) / 0.7
        return ((share * WITHER_STEPS).roundToInt().toDouble() / WITHER_STEPS).toFloat()
    }

    private val wetShade = Channels(112.0, 104.0, 98.0)

    /** Мокрая земля темнее: множитель цвета земли. */
    fun wetTint(moisture: Double): Channels = Channels.mix(Channels(255.0, 255.0, 255.0), wetShade, moisture)

    /** Распускание: быстро, с лёгким перелётом, к единице. */
    fun unfurl(t: Double): Double {
        if (t <= 0) return 0.0
        if (t >= 1) return 1.0
        return 1 - exp(-6 * t) * cos(7.5 * t)
    }

    /** Цвет влажности на табличке: голубой, оранжевый, красный — плавно. */
    fun ringColor(moisture: Double): Channels {
        val calm = Channels(71.0, 181.0, 228.0)
        val warn = Channels(255.0, 149.0, 0.0)
        val alarm = Channels(255.0, 59.0, 48.0)
        if (moisture >= Thirst.WARN_BELOW) return calm
        if (moisture >= Thirst.ALARM_BELOW) {
            return Channels.mix(warn, calm, (moisture - Thirst.ALARM_BELOW) / (Thirst.WARN_BELOW - Thirst.ALARM_BELOW))
        }
        return Channels.mix(alarm, warn, moisture / Thirst.ALARM_BELOW)
    }

    /** Цвет из 0…255 sRGB — в линейный 0…1, как его ждёт материал glTF. */
    fun linear(channel: Double): Double {
        val c = (channel / 255).coerceIn(0.0, 1.0)
        return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    /** Увядший цвет — как `Picture.withered`: к соломенному той же светлоты. */
    fun withered(colour: Channels, amount: Double): Channels {
        if (amount <= 0) return colour
        val straw = doubleArrayOf(0.86, 0.72, 0.36)
        val strawLight = straw[0] * 0.3 + straw[1] * 0.59 + straw[2] * 0.11
        val c = doubleArrayOf(colour.red / 255, colour.green / 255, colour.blue / 255)
        val light = c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11
        val out = DoubleArray(3) { i ->
            val dry = straw[i] * (light / strawLight) * 0.92
            ((c[i] * (1 - amount) + dry * amount).coerceIn(0.0, 1.0)) * 255
        }
        return Channels(out[0], out[1], out[2])
    }

    /**
     * Во сколько раз сдвинуть линейный цвет материала, чтобы средний цвет
     * `from` стал `to`. Узор текстуры остаётся — меняется только краска.
     */
    fun shift(from: Channels, to: Channels): FloatArray = floatArrayOf(
        ratio(from.red, to.red), ratio(from.green, to.green), ratio(from.blue, to.blue),
    )

    private fun ratio(from: Double, to: Double): Float {
        val a = linear(from)
        val b = linear(to)
        if (a < 1e-4) return 1f
        return (b / a).coerceIn(0.05, 4.0).toFloat()
    }
}

/** Роль материала модели — какую краску «по фото» он берёт. */
enum class Role { POT, SOIL, LEAF, FLOWER, OTHER;

    companion object {
        fun of(raw: String): Role = entries.firstOrNull { it.name.equals(raw, ignoreCase = true) } ?: OTHER
    }
}

/**
 * Краска материала в эту минуту: своя модель «по фото» перекрашивает
 * листья, цветы и горшок; сухость желтит лист; вода темнит землю.
 * Ответ — множитель к исходному `baseColorFactor` материала, линейный RGB.
 */
object Paint {
    fun factor(role: Role, mean: Channels, traits: Traits?, wilts: Boolean, wets: Boolean, moisture: Double): FloatArray {
        var colour = mean
        val out = floatArrayOf(1f, 1f, 1f)
        val target = when (role) {
            Role.LEAF -> traits?.leaf
            Role.FLOWER -> traits?.flower
            Role.POT -> traits?.pot
            else -> null
        }
        if (target != null) {
            multiply(out, Greenhouse.shift(colour, target))
            colour = target
        }
        if (wilts) {
            val amount = Greenhouse.wither(moisture).toDouble()
            if (amount > 0) multiply(out, Greenhouse.shift(colour, Greenhouse.withered(colour, amount)))
        }
        if (wets) {
            val wet = Greenhouse.wetTint(moisture)
            val soaked = Channels(colour.red * wet.red / 255, colour.green * wet.green / 255, colour.blue * wet.blue / 255)
            multiply(out, Greenhouse.shift(colour, soaked))
        }
        return out
    }

    private fun multiply(into: FloatArray, by: FloatArray) {
        for (i in 0 until 3) into[i] *= by[i]
    }
}

/**
 * Поза детали — как на iPhone: размер, крен вокруг своей оси, подъём с
 * наклоном и поворот вокруг вертикали, потом место. Кватернион (x, y, z, w).
 */
object Pose {
    fun axis(x: Float, y: Float, z: Float, angle: Float): FloatArray {
        val s = sin(angle / 2)
        return floatArrayOf(x * s, y * s, z * s, cos(angle / 2))
    }

    fun times(a: FloatArray, b: FloatArray): FloatArray = floatArrayOf(
        a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
        a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
        a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
        a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
    )

    /** yaw · (rise − lean) · roll — тот же порядок, что `Bed.orientation`. */
    fun orientation(yaw: Float, rise: Float, roll: Float, lean: Float = 0f): FloatArray =
        times(times(axis(0f, 1f, 0f, yaw), axis(0f, 0f, 1f, rise - lean)), axis(1f, 0f, 0f, roll))

    /** Матрица 4×4 по столбцам — для `TransformManager` Filament. */
    fun matrix(base: FloatArray, q: FloatArray, scale: Float, into: FloatArray = FloatArray(16)): FloatArray {
        val (x, y, z, w) = q.toList()
        into[0] = (1 - 2 * (y * y + z * z)) * scale
        into[1] = (2 * (x * y + z * w)) * scale
        into[2] = (2 * (x * z - y * w)) * scale
        into[3] = 0f
        into[4] = (2 * (x * y - z * w)) * scale
        into[5] = (1 - 2 * (x * x + z * z)) * scale
        into[6] = (2 * (y * z + x * w)) * scale
        into[7] = 0f
        into[8] = (2 * (x * z + y * w)) * scale
        into[9] = (2 * (y * z - x * w)) * scale
        into[10] = (1 - 2 * (x * x + y * y)) * scale
        into[11] = 0f
        into[12] = base[0]
        into[13] = base[1]
        into[14] = base[2]
        into[15] = 1f
        return into
    }

    /** Повернуть точку кватернионом — для проверок. */
    fun rotate(q: FloatArray, p: FloatArray): FloatArray {
        val m = matrix(floatArrayOf(0f, 0f, 0f), q, 1f)
        return floatArrayOf(
            m[0] * p[0] + m[4] * p[1] + m[8] * p[2],
            m[1] * p[0] + m[5] * p[1] + m[9] * p[2],
            m[2] * p[0] + m[6] * p[1] + m[10] * p[2],
        )
    }
}

/** Как расставить сад: низкие ближе, от середины к краям, по четыре в ряд. */
object Plot {
    const val GAP = 0.06f

    /** Место каждого — (вбок, вглубь) в метрах от центра первого ряда. */
    fun layout(spreads: List<Float>, heights: List<Float>, perRow: Int = 4): List<Pair<Float, Float>> {
        val count = min(spreads.size, heights.size)
        if (count == 0) return emptyList()
        val order = (0 until count).sortedWith(compareBy<Int> { heights[it] }.thenBy { it })
        val spots = MutableList(count) { 0f to 0f }
        var depth = 0f
        var start = 0
        while (start < count) {
            val row = order.subList(start, min(start + perRow, count))
            val deep = row.maxOf { max(spreads[it], 0.08f) * 2 + GAP }
            val arranged = ArrayDeque<Int>()
            row.forEachIndexed { index, plant -> if (index % 2 == 0) arranged.addLast(plant) else arranged.addFirst(plant) }
            val total = arranged.sumOf { (max(spreads[it], 0.08f) * 2 + GAP).toDouble() }.toFloat()
            var x = -total / 2
            for (plant in arranged) {
                val width = max(spreads[plant], 0.08f) * 2 + GAP
                spots[plant] = (x + width / 2) to (depth + deep / 2)
                x += width
            }
            depth += deep
            start += perRow
        }
        return spots
    }
}

/** Сколько растений тянет телефон в AR — по памяти, как `Rig` на iPhone. */
object Rig {
    fun plants(totalMemoryBytes: Long, lowRam: Boolean, hot: Boolean): Int {
        val gigabytes = totalMemoryBytes / 1_073_741_824.0
        var tier = when {
            lowRam -> 0
            gigabytes >= 7 -> 2
            gigabytes >= 5 -> 1
            else -> 0
        }
        if (hot) tier = max(tier - 1, 0)
        return intArrayOf(4, 8, 12)[tier]
    }

    /** Качание лист за листом — синус с фазой детали. */
    fun wave(clock: Double, phase: Float): Double = sin(clock * 1.3 + phase * 2 * PI)

    /** Скрыть ли лист в более редкой модели «по фото» — одинаково при каждом показе. */
    fun thinned(index: Int, density: Double): Boolean {
        if (density >= 1) return false
        val hash = ((index * 2_654_435_761L) and 0xFFFF).toDouble() / 0x10000
        return hash < (1 - density)
    }

    fun distance(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]
        val dy = a[1] - b[1]
        val dz = a[2] - b[2]
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}
