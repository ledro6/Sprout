package com.ledro6.sprout.model

import kotlinx.serialization.Serializable
import java.time.LocalDate

/**
 * Запись журнала: кого полили и когда. Время настоящее, а не садовое: по
 * садовым часам «сегодня» кончалось бы втрое чаще.
 */
@Serializable
data class Watering(
    val plant: String,
    val at: Long,
    /** Сколько воды оставалось в земле в миг полива. */
    val left: Double? = null,
) {
    /** Та же запись — по растению и мигу. */
    fun same(other: Watering) = plant == other.plant && at == other.at
}

data class Tally(val name: String, val count: Int)

data class Chore(val day: LocalDate, val count: Int)

/** Всё, что сад может рассказать о поливах, — из журнала, а не счётчиками. */
data class Score(
    val total: Int = 0,
    val today: Int = 0,
    val week: Int = 0,
    val streak: Int = 0,
    val best: Int = 0,
    val rooms: List<Tally> = emptyList(),
    val plants: List<Tally> = emptyList(),
    /** Две недели от старого к новому, пустые дни тоже. */
    val days: List<Chore> = emptyList(),
) {
    companion object {
        const val SPAN = 14

        fun of(log: List<Watering>, rooms: List<Room>, now: Long, days: Days): Score {
            val today = days.day(now)
            val weekAgo = days.start(today.minusDays(6))
            val byDay = HashMap<LocalDate, Int>()
            for (note in log) {
                val day = days.day(note.at)
                byDay[day] = (byDay[day] ?: 0) + 1
            }
            val byPlant = HashMap<String, Int>()
            for (note in log) byPlant[note.plant] = (byPlant[note.plant] ?: 0) + 1
            val ranked = compareByDescending<Tally> { it.count }.thenBy { it.name }
            return Score(
                total = log.size,
                today = log.count { days.day(it.at) == today },
                week = log.count { it.at >= weekAgo },
                streak = streak(today, byDay.keys),
                best = best(byDay.keys),
                rooms = rooms.map { room ->
                    Tally(room.name, room.plants.sumOf { byPlant[it.id] ?: 0 })
                }.filter { it.count > 0 }.sortedWith(ranked),
                plants = rooms.flatMap { it.plants }
                    .map { Tally(it.name, byPlant[it.id] ?: 0) }
                    .filter { it.count > 0 }
                    .sortedWith(ranked),
                days = (SPAN - 1 downTo 0).map { back ->
                    val day = today.minusDays(back.toLong())
                    Chore(day, byDay[day] ?: 0)
                },
            )
        }

        /** Сегодняшний пропуск череду не рвёт; рвёт пропущенный вчерашний. */
        private fun streak(today: LocalDate, days: Set<LocalDate>): Int {
            var day = today
            if (day !in days) {
                val yesterday = day.minusDays(1)
                if (yesterday !in days) return 0
                day = yesterday
            }
            var run = 0
            while (day in days) {
                run += 1
                day = day.minusDays(1)
            }
            return run
        }

        private fun best(days: Set<LocalDate>): Int {
            var longest = 0
            for (day in days) {
                if (day.minusDays(1) in days) continue
                var run = 0
                var walk = day
                while (walk in days) {
                    run += 1
                    walk = walk.plusDays(1)
                }
                longest = maxOf(longest, run)
            }
            return longest
        }
    }
}
