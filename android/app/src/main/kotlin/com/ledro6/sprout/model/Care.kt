package com.ledro6.sprout.model

import kotlinx.serialization.Serializable
import kotlin.math.max

/**
 * Подкормка и пересадка: сколько дней сада прошло с последней и раз в сколько
 * их делать. Счёт — в днях сада, как влажность. Подкормка считается только в
 * пору роста — зимой удобрение жжёт корни.
 */
@Serializable
data class Care(
    val feedEvery: Double? = null,
    val sinceFed: Double = 0.0,
    val repotEvery: Double? = null,
    val sinceRepot: Double = 0.0,
) {
    val feedIn: Double? get() = feedEvery?.let { max(0.0, it - sinceFed) }

    val repotIn: Double? get() = repotEvery?.let { max(0.0, it - sinceRepot) }

    val feedDue: Boolean get() = feedIn?.let { it < 0.5 } ?: false

    val repotDue: Boolean get() = repotIn?.let { it < 0.5 } ?: false

    fun passed(days: Double, growing: Boolean): Care {
        if (days <= 0) return this
        return copy(
            sinceFed = if (growing) sinceFed + days else sinceFed,
            sinceRepot = sinceRepot + days,
        )
    }

    val feedLabel: String?
        get() {
            val left = feedIn ?: return null
            if (feedDue) return Lang.text("Пора подкормить")
            return Lang.format("Подкормка через %lld дней", left.roundedInt())
        }

    val repotLabel: String?
        get() {
            val left = repotIn ?: return null
            if (repotDue) return Lang.text("Пора пересадить")
            val months = months(left)
            if (months < 1) return Lang.format("Пересадка через %lld дней", left.roundedInt())
            return Lang.format("Пересадка через %lld месяцев", months)
        }

    companion object {
        /** Суккуленты едят раз в месяц, цветущие — раз в две недели. */
        fun usual(preset: Preset): Care = when (preset) {
            Preset.CACTUS, Preset.ALOE, Preset.ECHEVERIA, Preset.JADE, Preset.SANSEVIERIA,
            Preset.ZAMIOCULCAS, Preset.HAWORTHIA, Preset.OPUNTIA, Preset.KALANCHOE, Preset.YUCCA,
            -> Care(feedEvery = 30.0, repotEvery = 730.0)
            Preset.ORCHID, Preset.ANTHURIUM, Preset.HOYA -> Care(feedEvery = 21.0, repotEvery = 730.0)
            Preset.CITRUS -> Care(feedEvery = 14.0, repotEvery = 730.0)
            Preset.VIOLET, Preset.BEGONIA, Preset.PELARGONIUM, Preset.TULIP, Preset.HERBS,
            Preset.ROSE, Preset.MINT, Preset.ROSEMARY, Preset.LILY, Preset.SUNFLOWER,
            Preset.LAVENDER, Preset.CHRYSANTHEMUM,
            -> Care(feedEvery = 14.0, repotEvery = 365.0)
            else -> Care(feedEvery = 21.0, repotEvery = 365.0)
        }

        /** Сроки пересадки на выбор — в месяцах. */
        val repotMonths = listOf(6, 12, 18, 24)

        fun days(months: Int): Double = months * 365.0 / 12

        fun months(days: Double): Int = (days * 12 / 365).roundedInt()
    }
}
