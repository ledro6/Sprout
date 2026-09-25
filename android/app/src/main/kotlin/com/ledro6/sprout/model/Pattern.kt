package com.ledro6.sprout.model

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Раскладка узора: какая фигурка стоит в узле сетки. Номер сдвигается на
 * постоянный шаг вбок и вниз; шаги взаимно просты с числом фигурок, поэтому
 * одинаковые не стоят рядом.
 */
data class Weave(val stepX: Int = 1, val stepY: Int = 1, val shift: Int = 0) {
    /** Узлы в ряду нумеруются сплошь, `2·столбец + гнездо`. */
    fun index(column: Int, slot: Int, row: Int, count: Int): Int {
        if (count <= 1) return 0
        val node = 2 * column + slot
        val raw = (stepX * node + stepY * row + shift) % count
        return if (raw < 0) raw + count else raw
    }

    companion object {
        fun of(count: Int, twistX: Int, twistY: Int, start: Int): Weave {
            if (count <= 1) return Weave()
            val steps = (1 until count).filter { divisor(it, count) == 1 }
            return Weave(
                steps[abs(twistX) % steps.size],
                steps[abs(twistY) % steps.size],
                abs(start) % count,
            )
        }

        private tailrec fun divisor(a: Int, b: Int): Int = if (b == 0) a else divisor(b, a % b)
    }
}

/** Откуда по узору расходится переход — черёд каждой фигурки, 0…1. */
sealed class Front {
    /** Из точки наружу — туда, куда нажал палец. */
    data class Point(val x: Double, val y: Double) : Front()

    /** В точку снаружи — волна, пущенная вспять. */
    data class Collapse(val x: Double, val y: Double) : Front()

    /** Полосой; угол — куда фронт идёт. */
    data class Sweep(val angle: Double) : Front()

    fun turn(x: Double, y: Double, width: Double, height: Double): Double {
        val w = max(width, 1.0)
        val h = max(height, 1.0)
        return when (this) {
            is Point -> min(hypot(x - this.x, y - this.y) / REACH, 1.0)
            is Collapse -> {
                val dx = this.x
                val dy = this.y
                val corner = maxOf(hypot(dx, dy), hypot(w - dx, dy), hypot(dx, h - dy), hypot(w - dx, h - dy))
                val far = hypot(x - dx, y - dy)
                1 - min(far / max(corner, 1.0), 1.0)
            }
            is Sweep -> {
                val dx = cos(angle)
                val dy = sin(angle)
                val reach = (abs(dx) + abs(dy)) / 2
                val along = (x / w - 0.5) * dx + (y / h - 0.5) * dy
                (along / (2 * reach) + 0.5).coerceIn(0.0, 1.0)
            }
        }
    }

    companion object {
        /** Общая мерка на все переходы — больше диагонали экрана, в dp. */
        const val REACH = 900.0
    }
}

/**
 * Фигурки плавают в вязкой среде, пока узор едет за наклоном: каждый слой
 * догоняет наклон со своей вязкостью.
 */
object Sway {
    val eases = doubleArrayOf(0.24, 0.17, 0.12, 0.075, 0.045)

    /** Упор в dp: между соседями 45, и резкий взмах не должен развалить узор. */
    const val LIMIT = 7.0

    const val SHUFFLE_SECONDS = 0.9

    fun layer(column: Int, row: Int, slot: Int, era: Int): Int {
        val part = (noise(column, row, slot, era * 2 + 7) + 1) / 2
        return (part * eases.size).toInt().coerceIn(0, eases.size - 1)
    }

    /** Шаг к цели для каждого слоя; `places` — пары x, y подряд. */
    fun settle(places: DoubleArray, targetX: Double, targetY: Double) {
        for (i in eases.indices) {
            val ease = eases[i]
            places[2 * i] += (targetX - places[2 * i]) * ease
            places[2 * i + 1] += (targetY - places[2 * i + 1]) * ease
        }
    }

    fun hold(value: Double): Double = value.coerceIn(-LIMIT, LIMIT)

    /** Детерминированный шум −1…1 — тот же, что на iOS. */
    fun noise(column: Int, row: Int, slot: Int, axis: Int): Double {
        var mix = column.toLong() * 73_856_093L
        mix = mix xor (row.toLong() * 19_349_663L)
        mix = mix xor (slot.toLong() * 83_492_791L)
        mix = mix xor (axis.toLong() * 2_654_435_761L)
        mix = mix xor (mix shr 13)
        mix *= 1_274_126_177L
        mix = mix xor (mix shr 16)
        return (mix and 0xFFFF).toDouble() / 0xFFFF * 2 - 1
    }
}

/**
 * Кутерьма от тряски: фигурки волной сжимаются и вырастают другими, узор с
 * каждым тактом перекрашивается, а потом садится обратно.
 */
data class Frolic(val elapsed: Double) {
    /** Состояние и размер фигурки с этим черёдом. */
    fun look(turn: Double): Pair<Int, Double> {
        val own = elapsed - turn.coerceIn(0.0, 1.0) * BEAT
        if (own <= 0) return 0 to 1.0
        val raw = own / BEAT
        val beat = raw.toInt()
        if (beat >= BEATS) return BEATS to 1.0
        val part = raw - beat
        if (part < 0.5) {
            val x = part * 2
            return beat to 1 - x * x * x
        }
        val x = (part - 0.5) * 2
        return (beat + 1) to 1 - (1 - x).pow(3)
    }

    companion object {
        const val BEAT = 0.7
        const val BEATS = 6
        val SECONDS: Double get() = (BEATS + 1) * BEAT

        fun chaotic(state: Int) = state in 1 until BEATS
    }
}

/** Случайность от строки или числа — одинаковая на всех телефонах. */
class Seeded(private var state: Long) {
    constructor(text: String) : this(hash(text))

    fun next(): Long {
        state += -0x61c8864680b583ebL
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L
        return z xor (z ushr 31)
    }

    /** Равномерно в [from, to]. */
    fun roll(from: Double, to: Double): Double {
        val unit = (next() ushr 11).toDouble() / (1L shl 53).toDouble()
        return from + (to - from) * unit
    }

    companion object {
        fun hash(text: String): Long {
            var hash = -0x340d631b7bdddcdbL
            for (byte in text.toByteArray(Charsets.UTF_8)) {
                hash = (hash xor (byte.toLong() and 0xFF)) * 0x100000001b3L
            }
            return hash
        }
    }
}
