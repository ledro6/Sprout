package com.ledro6.sprout.model

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.TextStyle

/**
 * Статистика сада за период: из журнала поливов и сада, как `Score`.
 * Привычки — в настоящем времени журнала; точность — по остатку воды в миг
 * полива; прогноз — в днях сада, тех же, что на карточках.
 */
data class Almanac(
    val period: Period = Period.WEEK,
    val start: LocalDate = LocalDate.of(1970, 1, 1),
    val byMonth: Boolean = false,
    val bars: List<Bar> = emptyList(),
    val total: Int = 0,
    /** Тот же срок перед периодом; у «всего времени» сравнивать не с чем. */
    val previous: Int? = null,
    val active: Int = 0,
    val length: Int = 1,
    val streak: Int = 0,
    val best: Int = 0,
    val aim: Aim = Aim(),
    val hours: List<Int> = List(24) { 0 },
    val weekdays: List<Weekday> = emptyList(),
    val rooms: List<RoomLine> = emptyList(),
    val plants: List<PlantLine> = emptyList(),
    val now: Now = Now(),
    val ahead: List<Ahead> = emptyList(),
    val cells: List<Cell> = emptyList(),
    val records: Records = Records(),
) {
    enum class Period {
        WEEK, MONTH, YEAR, ALL;

        val title: String
            get() = when (this) {
                WEEK -> Lang.text("Неделя")
                MONTH -> Lang.text("Месяц")
                YEAR -> Lang.text("Год")
                ALL -> Lang.text("Всё время")
            }
    }

    /** Столбик графика: день или месяц и поливы в нём. */
    data class Bar(val start: LocalDate, val count: Int)

    /** Сколько воды оставалось в земле, когда поливали. */
    data class Aim(
        val counts: List<Int> = List(4) { 0 },
        /** Десять корзин по десять процентов. */
        val bins: List<Int> = List(10) { 0 },
        /** Обычный остаток — медиана. */
        val typical: Double? = null,
    ) {
        enum class Zone {
            EARLY, ON_TIME, LAST_MOMENT, DRY;

            val title: String
                get() = when (this) {
                    EARLY -> Lang.text("Заранее")
                    ON_TIME -> Lang.text("Вовремя")
                    LAST_MOMENT -> Lang.text("В последний момент")
                    DRY -> Lang.text("Пересохло")
                }

            val range: String
                get() = when (this) {
                    EARLY -> Lang.text("40% воды и больше")
                    ON_TIME -> Lang.text("20–40% воды")
                    LAST_MOMENT -> Lang.text("меньше 20% воды")
                    DRY -> Lang.text("земля сухая")
                }
        }

        val known: Int get() = counts.sum()

        fun count(zone: Zone) = counts[zone.ordinal]

        fun share(zone: Zone): Double = if (known == 0) 0.0 else count(zone).toDouble() / known

        /** Зона, куда пришлось больше всего поливов; при равенстве — ближе к «вовремя». */
        val usual: Zone?
            get() {
                if (known == 0) return null
                val order = listOf(Zone.ON_TIME, Zone.LAST_MOMENT, Zone.EARLY, Zone.DRY)
                var best = order[0]
                for (zone in order.drop(1)) if (count(zone) > count(best)) best = zone
                return best
            }

        companion object {
            const val DRY_BELOW = 0.01

            fun zone(left: Double): Zone = when {
                left < DRY_BELOW -> Zone.DRY
                left < Thirst.ALARM_BELOW -> Zone.LAST_MOMENT
                left < Thirst.WARN_BELOW -> Zone.ON_TIME
                else -> Zone.EARLY
            }

            /** Записи без остатка воды не считаются: гадать о них нечем. */
            fun of(entries: List<Watering>): Aim {
                val lefts = entries.mapNotNull { it.left }.map { it.coerceIn(0.0, 1.0) }
                val counts = IntArray(4)
                val bins = IntArray(10)
                for (left in lefts) {
                    counts[zone(left).ordinal] += 1
                    bins[minOf((left * 10 + 1e-9).toInt(), 9)] += 1
                }
                if (lefts.isEmpty()) return Aim(counts.toList(), bins.toList(), null)
                val sorted = lefts.sorted()
                val middle = sorted.size / 2
                val typical = if (sorted.size % 2 == 1) sorted[middle]
                else (sorted[middle - 1] + sorted[middle]) / 2
                return Aim(counts.toList(), bins.toList(), typical)
            }
        }
    }

    /** День недели с поливами. Номер — как у календаря iOS: 1 — воскресенье. */
    data class Weekday(val number: Int, val symbol: String, val name: String, val count: Int)

    data class RoomLine(
        val name: String,
        val plants: Int,
        val moisture: Double?,
        val waterings: Int,
        val onTime: Double?,
    )

    data class PlantLine(
        val id: String,
        val name: String,
        val species: String,
        val room: String,
        val moisture: Double,
        val due: Int,
        val waterings: Int,
        val total: Int,
        val last: Long?,
        val typical: Double?,
    )

    /** Сад в эту минуту. */
    data class Now(
        val calm: Int = 0,
        val warn: Int = 0,
        val alarm: Int = 0,
        val average: Double? = null,
        val levels: List<Double> = emptyList(),
        val driest: String? = null,
    ) {
        val count: Int get() = calm + warn + alarm
        val content: Double get() = if (count == 0) 0.0 else calm.toDouble() / count
    }

    /** День сада в прогнозе: кому понадобится вода. */
    data class Ahead(val offset: Int, val plants: List<String> = emptyList(), val names: List<String> = emptyList()) {
        val count: Int get() = plants.size
    }

    data class Cell(val day: LocalDate, val count: Int)

    data class Records(
        val busiest: Cell? = null,
        val earliest: Int? = null,
        val latest: Int? = null,
        val longest: Int = 0,
        val total: Int = 0,
    )

    val change: Int? get() = previous?.let { total - it }

    val peakHour: Int?
        get() {
            val most = hours.maxOrNull() ?: return null
            if (most <= 0) return null
            return hours.indexOf(most)
        }

    val peakDay: Weekday?
        get() {
            val most = weekdays.maxOfOrNull { it.count } ?: return null
            if (most <= 0) return null
            return weekdays.firstOrNull { it.count == most }
        }

    val tallest: Int get() = bars.maxOfOrNull { it.count } ?: 0

    companion object {
        const val HORIZON = 14
        const val WEEKS = 16
        const val DAILY_UP_TO = 45

        fun of(log: List<Watering>, rooms: List<Room>, period: Period, since: Long, now: Long, days: Days): Almanac {
            val today = days.day(now)
            val (start, byMonth) = window(period, log, since, today, days)
            val from = days.start(start)
            val inside = log.filter { it.at >= from && it.at <= now }
            val previous = before(period, start)?.let { back ->
                val b = days.start(back)
                log.count { it.at >= b && it.at < from }
            }
            val score = Score.of(log, rooms, now, days)
            val hours = IntArray(24)
            for (entry in inside) hours[days.hour(entry.at)] += 1
            val byPlant = log.groupBy { it.plant }
            return Almanac(
                period = period,
                start = start,
                byMonth = byMonth,
                total = inside.size,
                length = maxOf(1, (days.between(start, today) + 1).toInt()),
                previous = previous,
                active = inside.map { days.day(it.at) }.toSet().size,
                streak = score.streak,
                best = score.best,
                bars = bars(inside, start, today, byMonth, days),
                aim = Aim.of(inside),
                hours = hours.toList(),
                weekdays = weekdays(inside, days),
                rooms = rooms.map { room ->
                    val ids = room.plants.map { it.id }.toSet()
                    val mine = inside.filter { it.plant in ids }
                    val aim = Aim.of(mine)
                    val levels = room.plants.map { it.moisture }
                    RoomLine(
                        name = room.name,
                        plants = room.plants.size,
                        moisture = if (levels.isEmpty()) null else levels.sum() / levels.size,
                        waterings = mine.size,
                        onTime = if (aim.known == 0) null else aim.share(Aim.Zone.ON_TIME),
                    )
                },
                plants = rooms.flatMap { room ->
                    room.plants.map { plant ->
                        val all = byPlant[plant.id] ?: emptyList()
                        PlantLine(
                            id = plant.id, name = plant.name, species = plant.species,
                            room = room.name, moisture = plant.moisture,
                            due = plant.daysUntilWatering,
                            waterings = all.count { it.at >= from && it.at <= now },
                            total = all.size,
                            last = all.maxOfOrNull { it.at },
                            typical = Aim.of(all).typical,
                        )
                    }
                },
                now = now(rooms),
                ahead = ahead(rooms),
                cells = cells(log, today, days),
                records = records(log, score.best, days),
            )
        }

        /** Дни от начала недели шестнадцать недель назад и до сегодня. */
        fun cells(log: List<Watering>, today: LocalDate, days: Days): List<Cell> {
            val back = today.minusDays(7L * (WEEKS - 1))
            val first = days.weekStart(back)
            val from = days.start(first)
            val counts = HashMap<LocalDate, Int>()
            for (entry in log) {
                if (entry.at < from) continue
                val day = days.day(entry.at)
                counts[day] = (counts[day] ?: 0) + 1
            }
            val out = mutableListOf<Cell>()
            var day = first
            while (!day.isAfter(today)) {
                out.add(Cell(day, counts[day] ?: 0))
                day = day.plusDays(1)
            }
            return out
        }

        fun records(log: List<Watering>, longest: Int, days: Days): Records {
            val counts = HashMap<LocalDate, Int>()
            var earliest: Int? = null
            var latest: Int? = null
            for (entry in log) {
                val day = days.day(entry.at)
                counts[day] = (counts[day] ?: 0) + 1
                val at = days.moment(entry.at)
                val minute = at.hour * 60 + at.minute
                earliest = minOf(earliest ?: minute, minute)
                latest = maxOf(latest ?: minute, minute)
            }
            val top = counts.entries.maxWithOrNull(compareBy<Map.Entry<LocalDate, Int>> { it.value }.thenBy { it.key })
            return Records(
                busiest = top?.let { Cell(it.key, it.value) },
                earliest = earliest,
                latest = latest,
                longest = longest,
                total = log.size,
            )
        }

        /** Начало периода и шаг графика. */
        fun window(period: Period, log: List<Watering>, since: Long, today: LocalDate, days: Days): Pair<LocalDate, Boolean> =
            when (period) {
                Period.WEEK -> today.minusDays(6) to false
                Period.MONTH -> today.minusDays(29) to false
                Period.YEAR -> today.withDayOfMonth(1).minusMonths(11) to true
                Period.ALL -> {
                    val first = (listOf(since) + log.map { it.at }).min()
                    val day = days.day(first)
                    val start = if (day.isAfter(today)) today else day
                    if (days.between(start, today) < DAILY_UP_TO) start to false
                    else start.withDayOfMonth(1) to true
                }
            }

        private fun before(period: Period, start: LocalDate): LocalDate? = when (period) {
            Period.WEEK -> start.minusDays(7)
            Period.MONTH -> start.minusDays(30)
            Period.YEAR -> start.minusMonths(12)
            Period.ALL -> null
        }

        /** Пустые дни тоже: без них график врал бы о промежутках. */
        fun bars(entries: List<Watering>, start: LocalDate, today: LocalDate, byMonth: Boolean, days: Days): List<Bar> {
            val counts = HashMap<LocalDate, Int>()
            for (entry in entries) {
                val day = days.day(entry.at)
                val key = if (byMonth) day.withDayOfMonth(1) else day
                counts[key] = (counts[key] ?: 0) + 1
            }
            val out = mutableListOf<Bar>()
            var cursor = if (byMonth) start.withDayOfMonth(1) else start
            while (!cursor.isAfter(today) && out.size < 400) {
                out.add(Bar(cursor, counts[cursor] ?: 0))
                cursor = if (byMonth) cursor.plusMonths(1) else cursor.plusDays(1)
            }
            return out
        }

        /** С первого дня недели, принятого в стране. Названия — на языке приложения. */
        fun weekdays(entries: List<Watering>, days: Days): List<Weekday> {
            val counts = IntArray(7)
            for (entry in entries) counts[sunday(days.moment(entry.at).dayOfWeek) - 1] += 1
            val first = sunday(days.firstDay) - 1
            return (0 until 7).map { step ->
                val index = (first + step) % 7
                val weekday = fromSunday(index + 1)
                Weekday(
                    number = index + 1,
                    symbol = weekday.getDisplayName(TextStyle.SHORT_STANDALONE, Lang.locale),
                    name = weekday.getDisplayName(TextStyle.FULL_STANDALONE, Lang.locale),
                    count = counts[index],
                )
            }
        }

        /** 1 — воскресенье, как у календаря iOS. */
        private fun sunday(day: DayOfWeek): Int = day.value % 7 + 1

        private fun fromSunday(number: Int): DayOfWeek = if (number == 1) DayOfWeek.SUNDAY else DayOfWeek.of(number - 1)

        fun now(rooms: List<Room>): Now {
            val plants = rooms.flatMap { it.plants }
            var calm = 0
            var warn = 0
            var alarm = 0
            for (plant in plants) {
                when (plant.thirst) {
                    Thirst.CALM -> calm += 1
                    Thirst.WARN -> warn += 1
                    Thirst.ALARM -> alarm += 1
                }
            }
            if (plants.isEmpty()) return Now(calm, warn, alarm)
            return Now(
                calm, warn, alarm,
                average = plants.sumOf { it.moisture } / plants.size,
                levels = plants.map { it.moisture }.sorted(),
                driest = plants.minByOrNull { it.moisture }?.name,
            )
        }

        /** Первый полив — тем же счётом, что на карточке; дальше — через срок. */
        fun ahead(rooms: List<Room>, count: Int = HORIZON): List<Ahead> {
            val plants = Array(count) { mutableListOf<String>() }
            val names = Array(count) { mutableListOf<String>() }
            for (plant in rooms.flatMap { it.plants }) {
                if (plant.period <= 0) continue
                for (turn in 0 until 1_000) {
                    val day = (plant.daysUntilWatering + turn * plant.period).roundedInt()
                    if (day >= count) break
                    plants[day].add(plant.id)
                    names[day].add(plant.name)
                }
            }
            return (0 until count).map { Ahead(it, plants[it], names[it]) }
        }
    }
}

/** Статистика одного растения — для его экрана в статистике. */
data class PlantBook(
    val total: Int = 0,
    val inPeriod: Int = 0,
    val last: Long? = null,
    val aim: Almanac.Aim = Almanac.Aim(),
    val recent: List<Watering> = emptyList(),
    val dues: List<Int> = emptyList(),
    val average: Double? = null,
) {
    companion object {
        const val DUE_COUNT = 3

        fun of(plant: Plant, log: List<Watering>, period: Almanac.Period, since: Long, now: Long, days: Days): PlantBook {
            val mine = log.filter { it.plant == plant.id }.sortedBy { it.at }
            val today = days.day(now)
            val (start, _) = Almanac.window(period, log, since, today, days)
            val from = days.start(start)
            val recent = mine.filter { it.at >= from && it.at <= now }
            return PlantBook(
                total = mine.size,
                recent = recent,
                inPeriod = recent.size,
                last = mine.lastOrNull()?.at,
                aim = Almanac.Aim.of(mine),
                average = Diary.of(log, plant.id).average,
                dues = if (plant.period > 0) {
                    (0 until DUE_COUNT).map { (plant.daysUntilWatering + it * plant.period).roundedInt() }
                } else {
                    emptyList()
                },
            )
        }
    }
}
