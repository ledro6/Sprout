package com.ledro6.sprout.model

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import java.util.Locale

/**
 * Календарь: часовой пояс и первый день недели. Снаружи, а не
 * `ZoneId.systemDefault()` внутри — прогон модели не должен зависеть от
 * часового пояса и дня запуска. Время в модели — миллисекунды от 1970 года.
 */
data class Days(
    val zone: ZoneId = ZoneId.systemDefault(),
    val firstDay: DayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek,
) {
    fun day(millis: Long): LocalDate = moment(millis).toLocalDate()

    fun moment(millis: Long): ZonedDateTime = Instant.ofEpochMilli(millis).atZone(zone)

    /** Начало дня: сутки бывают в 23 и 25 часов, поэтому по календарю. */
    fun start(day: LocalDate): Long = day.atStartOfDay(zone).toInstant().toEpochMilli()

    fun startOfDay(millis: Long): Long = start(day(millis))

    fun hour(millis: Long): Int = moment(millis).hour

    fun minute(millis: Long): Int = moment(millis).minute

    fun sameDay(a: Long, b: Long): Boolean = day(a) == day(b)

    /** Первый день недели, в которой лежит `day`, — как в календаре телефона. */
    fun weekStart(day: LocalDate): LocalDate =
        day.with(TemporalAdjusters.previousOrSame(firstDay))

    /** Целых дней между днями — по календарю. */
    fun between(from: LocalDate, to: LocalDate): Long = ChronoUnit.DAYS.between(from, to)

    companion object {
        /** Сейчас в этом телефоне: пояс и неделя могли смениться. */
        val current: Days get() = Days()
    }
}
