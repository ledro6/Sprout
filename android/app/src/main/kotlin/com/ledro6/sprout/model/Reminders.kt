package com.ledro6.sprout.model

import kotlin.math.max

/**
 * Напоминание о поливе: кого и когда будить. Одна арифметика — доставку
 * делает система, см. `platform/Notifier`.
 */
object Reminder {
    data class Due(
        val plant: Plant,
        val others: Int,
        /** Через сколько настоящих секунд. */
        val after: Double,
        /** Кого польёт кнопка «Полил» в уведомлении. */
        val ids: List<String> = emptyList(),
    )

    data class Chore(val plant: Plant, val repot: Boolean, val after: Double)

    /** Раньше уведомление бессмысленно: экран ещё не погас. */
    const val SOONEST = 15.0

    /** Через сколько настоящих секунд растение опустится до порога. */
    fun delay(plant: Plant, threshold: Double): Double? {
        if (plant.dryingDays <= 0) return null
        if (plant.moisture <= threshold) return 0.0
        val days = (plant.moisture - threshold) * plant.period
        return days * 86_400 / Garden.SPEED
    }

    /** Одно на всю квартиру — но с числом соседей, которым станет сухо к тому же мигу. */
    fun next(rooms: List<Room>, threshold: Double): Due? {
        val plants = rooms.flatMap { it.plants }
        var soonest: Pair<Plant, Double>? = null
        for (plant in plants) {
            val delay = delay(plant, threshold) ?: continue
            if (soonest == null || delay < soonest.second) soonest = plant to delay
        }
        val first = soonest ?: return null
        val together = plants.filter { plant ->
            val delay = delay(plant, threshold) ?: return@filter false
            delay <= first.second
        }
        return Due(first.first, together.size - 1, max(first.second, SOONEST), together.map { it.id })
    }

    val title: String get() = Lang.text("Пора поливать")

    fun text(due: Due): String {
        if (due.others <= 0) return Lang.format("«%@» просит воды", due.plant.name)
        return Lang.format(
            "«%1\$@» и ещё %2\$@ просят воды",
            due.plant.name, Lang.format("%lld растений", due.others),
        )
    }

    /** Ближайший уход по всей квартире. Подкормка — только в пору роста. */
    fun chore(rooms: List<Room>): Chore? {
        var best: Triple<Plant, Boolean, Double>? = null
        for (plant in rooms.flatMap { it.plants }) {
            val tending = plant.tending
            val options = mutableListOf<Pair<Boolean, Double>>()
            if (Season.growing) tending.feedIn?.let { options.add(false to it) }
            tending.repotIn?.let { options.add(true to it) }
            for ((repot, days) in options) {
                if (best == null || days < best.third) best = Triple(plant, repot, days)
            }
        }
        val found = best ?: return null
        return Chore(found.first, found.second, max(found.third * 86_400 / Garden.SPEED, SOONEST))
    }

    fun title(chore: Chore): String =
        if (chore.repot) Lang.text("Пора пересадить") else Lang.text("Пора подкормить")

    fun text(chore: Chore): String =
        if (chore.repot) Lang.format("«%@» просится в горшок побольше", chore.plant.name)
        else Lang.format("«%@» ждёт подкормки", chore.plant.name)
}
