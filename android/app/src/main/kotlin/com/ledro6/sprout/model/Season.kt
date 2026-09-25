package com.ledro6.sprout.model

import java.util.Locale
import kotlin.math.max

/**
 * Время года для полива: зимой земля сохнет медленнее, летом быстрее.
 * Полушарие — по стране из настроек телефона, без сети и без места на карте.
 */
object Season {
    enum class Side { NORTH, SOUTH, TROPICS }

    /** Во сколько раз срок сейчас длиннее записанного; единица — без поправки. */
    @Volatile
    var stretch: Double = 1.0

    /** Сейчас пора роста — идёт счёт до подкормки. */
    @Volatile
    var growing: Boolean = true

    private val southern = setOf(
        "AR", "AU", "BW", "CL", "FK", "LS", "NA", "NZ", "PY", "SZ", "UY", "ZA",
    )

    private val equatorial = setOf(
        "BN", "BR", "CO", "CR", "EC", "GA", "GH", "ID", "KE", "LK", "MV", "MY",
        "NG", "PA", "PE", "PH", "SG", "SR", "TH", "TZ", "UG", "VE", "VN",
    )

    fun side(region: String?): Side {
        val code = region?.uppercase(Locale.ROOT)?.takeIf { it.isNotEmpty() } ?: return Side.NORTH
        if (code in southern) return Side.SOUTH
        if (code in equatorial) return Side.TROPICS
        return Side.NORTH
    }

    /** Месяц 1…12 по ту сторону экватора: южный январь — северный июль. */
    private fun northern(month: Int, side: Side): Int =
        if (side == Side.SOUTH) (month + 5) % 12 + 1 else month

    fun stretch(month: Int, side: Side): Double {
        if (side == Side.TROPICS) return 1.0
        return when (northern(month, side)) {
            12, 1, 2 -> 1.35
            3, 11 -> 1.15
            4, 10 -> 1.0
            5, 9 -> 0.95
            else -> 0.85
        }
    }

    fun growing(month: Int, side: Side): Boolean =
        side == Side.TROPICS || northern(month, side) in 3..9

    /** Поправка на сегодня; выключено — круглый год как записано. */
    fun settle(on: Boolean, month: Int, region: String?) {
        val here = side(region)
        stretch = if (on) stretch(month, here) else 1.0
        growing = growing(month, here)
    }

    /** Строка для экрана растения; летом и осенью молчит. */
    fun line(stretch: Double): String? = when {
        stretch >= 1.3 -> Lang.text("Зима: земля сохнет медленнее, поливать реже")
        stretch >= 1.1 -> Lang.text("Прохладно: земля сохнет чуть медленнее")
        stretch < 0.9 -> Lang.text("Лето: земля сохнет быстрее, поливать чаще")
        else -> null
    }
}

/**
 * Подстройка срока по тому, как поливают на самом деле: поливают стабильно при
 * трети воды и больше — земля у хозяина сохнет быстрее записанного.
 */
object Rhythm {
    const val ENOUGH = 3
    const val WINDOW = 6
    const val EARLY = 0.25

    fun suggest(plant: Plant, log: List<Watering>): Double? {
        val left = log.filter { it.plant == plant.id }.mapNotNull { it.left }.takeLast(WINDOW)
        if (left.size < ENOUGH) return null
        val middle = left.sorted()[left.size / 2]
        if (middle < EARLY) return null
        val days = max(1.0, (plant.dryingDays * (1 - middle)).rounded())
        if (days > plant.dryingDays - 1 || days == plant.quiet) return null
        return days
    }
}
