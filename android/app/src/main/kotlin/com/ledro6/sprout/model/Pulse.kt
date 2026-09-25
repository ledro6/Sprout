package com.ledro6.sprout.model

import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/** Точка огибающей: доля времени и сила, обе 0…1. */
data class Moment(val at: Double, val strength: Double)

/** Тычок в руку: когда (секунды), сила и резкость 0…1. */
data class Tap(val at: Double, val strength: Double, val edge: Double)

/**
 * Рисунок отклика в руке — форма без времени и без движка. Из тычков, а не
 * из ровного гула: волна идёт рядами фигурок, и тычок на ряд это передаёт.
 * Играет его `platform/Haptics` — вибромотором телефона.
 */
data class Pulse(
    val rate: Double,
    val edge: Double = 0.6,
    val hum: Double = 0.0,
    val strike: Double = 0.0,
    val strikeEdge: Double = 0.5,
    val finish: Double = 0.0,
    val finishEdge: Double = 0.5,
    val envelope: List<Moment>,
) {
    fun taps(seconds: Double): List<Tap> {
        if (rate <= 0 || seconds <= 0) return emptyList()
        val step = 1 / rate
        val out = mutableListOf<Tap>()
        var time = 0.0
        while (time <= seconds + 1e-9) {
            val force = strength(time / seconds)
            if (force >= FAINTEST) out.add(Tap(time, min(force, 1.0), edge))
            time += step
        }
        return out
    }

    fun strength(moment: Double): Double {
        val time = moment.coerceIn(0.0, 1.0)
        val last = envelope.lastOrNull() ?: return 0.0
        val next = envelope.indexOfFirst { it.at >= time }
        if (next < 0) return last.strength
        if (next == 0) return envelope[0].strength
        val before = envelope[next - 1]
        val after = envelope[next]
        val span = after.at - before.at
        if (span <= 0) return after.strength
        val part = (time - before.at) / span
        return before.strength + (after.strength - before.strength) * part
    }

    val valid: Boolean
        get() {
            fun fits(value: Double) = value in 0.0..1.0
            if (!(fits(strike) && fits(strikeEdge) && fits(finish) && fits(finishEdge) && fits(edge) && fits(hum))) {
                return false
            }
            if (rate <= 0 || rate > 40) return false
            if (envelope.size < 2 || envelope.first().at != 0.0 || envelope.last().at != 1.0) return false
            for ((index, point) in envelope.withIndex()) {
                if (!fits(point.at) || !fits(point.strength)) return false
                if (index > 0 && point.at <= envelope[index - 1].at) return false
            }
            return true
        }

    companion object {
        const val FAINTEST = 0.06
        const val LIFT = 0.65
        const val BOOST = 1.25

        /** Сила с ползунка: слабые тычки подтягиваются сильнее сильных. */
        fun scaled(force: Double, strength: Double): Double {
            val level = strength.coerceIn(0.0, 1.0)
            val base = force.coerceIn(0.0, 1.0)
            if (level <= 0 || base <= 0) return 0.0
            return min(base.pow(LIFT) * BOOST * level, 1.0)
        }

        /** Всходы: редкие слабые тычки набирают частоту и садятся хлопком. */
        val sprout = Pulse(
            rate = 15.0, edge = 0.3, finish = 0.45, finishEdge = 0.25,
            envelope = listOf(Moment(0.0, 0.08), Moment(0.25, 0.3), Moment(0.55, 0.58), Moment(0.85, 0.42), Moment(1.0, 0.16)),
        )

        /** Новое растение: нарастает из ничего и лопается хлопком. */
        val bloom = Pulse(
            rate = 18.0, edge = 0.55, finish = 1.0, finishEdge = 0.85,
            envelope = listOf(Moment(0.0, 0.08), Moment(0.45, 0.35), Moment(0.8, 0.7), Moment(1.0, 0.9)),
        )

        /** Кутерьма: бугор на каждый такт. */
        val frenzy: Pulse
            get() {
                val slots = (Frolic.BEATS + 1).toDouble()
                val points = mutableListOf<Moment>()
                for (beat in 0 until Frolic.BEATS) {
                    val from = beat / slots
                    val peak = 0.34 + 0.52 * beat / (Frolic.BEATS - 1)
                    points.add(Moment(from, peak * 0.35))
                    points.add(Moment(from + 0.4 / slots, peak))
                }
                points.add(Moment(1.0, 0.0))
                return Pulse(
                    rate = 12.0, edge = 0.75, hum = 0.2, strike = 0.55, strikeEdge = 0.9,
                    finish = 0.7, finishEdge = 0.3, envelope = points,
                )
            }
    }
}

/**
 * Полив в руке — капли: удар и россыпь тычков, каждый раз новая. Одинаковый
 * рисунок на каждый полив рука выучила бы на третий раз.
 */
object Rain {
    const val CLOSEST = 0.028

    fun drops(seconds: Double, seed: Long): List<Tap> {
        if (seconds <= 0) return emptyList()
        val dice = Seeded(seed)
        val out = mutableListOf(Tap(0.0, dice.roll(0.85, 1.0), dice.roll(0.55, 0.8)))
        var time = dice.roll(0.05, 0.09)
        while (time <= seconds) {
            val part = time / seconds
            val fade = (1 - part).pow(1.3)
            val force = fade * dice.roll(0.55, 1.15)
            if (force >= Pulse.FAINTEST && dice.roll(0.0, 1.0) > 0.08) {
                out.add(Tap(time, min(force, 1.0), dice.roll(0.2, 0.95)))
                val echo = force * dice.roll(0.45, 0.75)
                val later = time + dice.roll(0.03, 0.045)
                if (dice.roll(0.0, 1.0) < 0.18 && echo >= Pulse.FAINTEST && later <= seconds) {
                    out.add(Tap(later, min(echo, 1.0), dice.roll(0.3, 0.9)))
                }
            }
            val gap = (0.055 + 0.13 * part) * dice.roll(0.6, 1.5)
            time = max(time + gap, (out.lastOrNull()?.at ?: time) + CLOSEST)
        }
        return out
    }
}

/** Короткие отклики — послушные ползунку силы. */
object Knock {
    val pick = listOf(Tap(0.0, 0.55, 0.8))
    val done = listOf(Tap(0.0, 0.6, 0.45), Tap(0.1, 1.0, 0.7))
    val toss = listOf(Tap(0.0, 1.0, 0.6), Tap(0.12, 0.5, 0.3))
    val back = listOf(Tap(0.0, 0.75, 0.35), Tap(0.09, 0.5, 0.55))
    val wrong = listOf(Tap(0.0, 0.8, 0.85), Tap(0.08, 0.75, 0.85), Tap(0.17, 1.0, 0.95))
}
