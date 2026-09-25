package com.ledro6.sprout.model

import java.time.temporal.TemporalAccessor
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Дата по-местному из набора полей: у кого «20 сентября», у кого
 * «September 20». На телефоне шаблон подбирает Android
 * (`DateFormat.getBestDateTimePattern`); без телефона — запасной шаблон.
 */
object Skeleton {
    private val fallback = mapOf(
        "dMMMM" to "d MMMM",
        "dMMMMy" to "d MMMM y",
        "dMMM" to "d MMM",
        "MMMMy" to "LLLL y",
        "LLLL" to "LLLL",
        "MMM" to "LLL",
        "EEEE" to "EEEE",
        "EEEEdMMMM" to "EEEE, d MMMM",
        "Hm" to "HH:mm",
        "hm" to "h:mm a",
    )

    @Volatile
    var resolve: (String, Locale) -> String = { skeleton, _ -> fallback[skeleton] ?: skeleton }

    /** 24 часа или 12 — как в настройках телефона; пусто — как принято в языке. */
    @Volatile
    var hours24: Boolean? = null

    fun time(moment: TemporalAccessor): String = when (hours24) {
        null -> DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(Lang.locale).format(moment)
        true -> format(moment, "Hm")
        false -> format(moment, "hm")
    }

    fun pattern(skeleton: String): String =
        runCatching { resolve(skeleton, Lang.locale) }.getOrNull() ?: fallback[skeleton] ?: skeleton

    fun format(moment: TemporalAccessor, skeleton: String): String =
        runCatching { DateTimeFormatter.ofPattern(pattern(skeleton), Lang.locale).format(moment) }
            .getOrElse { DateTimeFormatter.ofPattern(fallback[skeleton] ?: "d MMMM", Lang.locale).format(moment) }
}
