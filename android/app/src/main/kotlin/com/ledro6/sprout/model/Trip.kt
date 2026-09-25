package com.ledro6.sprout.model

import java.time.LocalDate
import kotlin.math.floor
import kotlin.math.max

/**
 * «Уезжаю»: кто дождётся хозяина, а кого должен полить сосед и в какие дни.
 * Считается так, будто перед отъездом полили всех.
 */
object Trip {
    data class Need(
        val plant: Plant,
        val room: String,
        /** Через сколько дней после отъезда земля высохнет досуха. */
        val dries: Double,
        /** В какие дни от отъезда соседу полить. */
        val visits: List<Int>,
    )

    /** Сосед приходит, пока в земле ещё остаётся десятая часть. */
    const val MARGIN = 0.9

    fun needs(rooms: List<Room>, days: Int): List<Need> {
        val out = mutableListOf<Need>()
        for (room in rooms) {
            for (plant in room.plants) {
                if (plant.dryingDays <= 0) continue
                val lasts = plant.period
                if (days.toDouble() <= lasts) continue
                val step = max(1, floor(lasts * MARGIN).toInt())
                val visits = (step until days step step).toList()
                out.add(Need(plant, room.name, lasts, visits))
            }
        }
        return out.sortedBy { it.dries }
    }

    fun fine(rooms: List<Room>, days: Int): List<Plant> {
        val needy = needs(rooms, days).map { it.plant.id }.toSet()
        return rooms.flatMap { it.plants }.filter { it.id !in needy }
    }

    fun days(leave: LocalDate, back: LocalDate): Int =
        max(0, java.time.temporal.ChronoUnit.DAYS.between(leave, back).toInt())

    /** Памятка соседу — текстом, чтобы отправить любым мессенджером. */
    fun memo(needs: List<Need>, leave: LocalDate, back: LocalDate): String {
        fun say(day: LocalDate) = Skeleton.format(day, "dMMMM")
        val lines = mutableListOf(
            Lang.format("Привет! Меня не будет с %1\$@ по %2\$@.", say(leave), say(back)),
        )
        if (needs.isEmpty()) {
            lines.add(Lang.text("Растения дождутся меня сами — поливать никого не нужно. Спасибо!"))
            return lines.joinToString("\n")
        }
        lines.add(Lang.text("Пожалуйста, полей растения:"))
        for (need in needs) {
            val dates = need.visits.map { say(leave.plusDays(it.toLong())) }
            lines.add(
                Lang.format(
                    "• %1\$@ (%2\$@, «%3\$@») — %4\$@",
                    need.plant.name, need.plant.species, need.room, dates.joinToString(", "),
                ),
            )
        }
        lines.add(
            Lang.text(
                "Полить — до мокрой земли, но чтобы вода не стояла в поддоне. " +
                    "Остальные растения дождутся меня сами. Спасибо!",
            ),
        )
        return lines.joinToString("\n")
    }
}
