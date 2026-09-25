package com.ledro6.sprout.model

import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import kotlin.math.PI
import kotlin.math.abs

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class StatsTest {
    private val utc = Days(ZoneOffset.UTC, DayOfWeek.MONDAY)
    private val noon = ZonedDateTime.of(2026, 9, 18, 12, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()

    private fun day(back: Int, hour: Int = 10): Long =
        ZonedDateTime.of(2026, 9, 18, hour, 0, 0, 0, ZoneOffset.UTC).minusDays(back.toLong()).toInstant().toEpochMilli()

    private fun note(plant: String, back: Int) = Watering(plant, day(back))

    @Before
    fun russian() {
        speak("ru")
        Season.stretch = 1.0
        Season.growing = true
    }

    @After
    fun reset() {
        speak("ru")
        Season.stretch = 1.0
        Season.growing = true
    }

    @Test
    fun score() = checks {
        val plot = listOf(
            Room("Спальня", listOf(plantNamed("Баксик", 1.0, 9.0), plantNamed("Борис", 1.0, 5.0))),
            Room("Кухня", listOf(plantNamed("Мурзик", 1.0, 7.0))),
        )
        val journal = listOf(
            note("Баксик", 0), note("Баксик", 0), note("Борис", 0), note("Мурзик", 1),
            note("Баксик", 2), note("Борис", 9), note("Борис", 20),
        )
        val score = Score.of(journal, plot, noon, utc)
        check("${score.total}", "7", "всего — весь журнал")
        check("${score.today}", "3", "сегодня — только сегодняшние")
        check("${score.week}", "5", "за неделю — шесть дней назад и ближе")
        check("${score.days.size}", "14", "две недели в ряду")
        check(score.days.first().day < score.days.last().day, "от старого к новому")
        check("${score.days.last().count}", "3", "последний день — сегодня")
        check("${score.days.count { it.count == 0 }}", "10", "пустые дни в ряду есть")
        check("${score.streak}", "3", "три дня подряд")
        fun streak(list: List<Watering>) = Score.of(list, plot, noon, utc).streak
        check(streak(listOf(note("Баксик", 0), note("Баксик", 2), note("Баксик", 3))) == 1, "вчерашний пропуск обрывает")
        check(streak(listOf(note("Баксик", 0), note("Баксик", 1), note("Баксик", 2))) == 3, "три подряд")
        check(streak(listOf(note("Баксик", 1), note("Баксик", 2))) == 2, "сегодня ещё не полили — череда жива")
        check(streak(listOf(note("Баксик", 2), note("Баксик", 3))) == 0, "пропустили вчера — оборвана")
        check(streak(emptyList()) == 0, "в пустом журнале череды нет")
        val twoRuns = listOf(note("Баксик", 10), note("Баксик", 11), note("Баксик", 12), note("Баксик", 13), note("Баксик", 0))
        check(Score.of(twoRuns, plot, noon, utc).best == 4, "самая длинная череда — из прошлого")
        check(score.plants.map { it.name } == listOf("Баксик", "Борис", "Мурзик"), "растения от большего к меньшему")
        check(score.plants.map { it.count } == listOf(3, 3, 1), "с их числами")
        check(score.rooms.map { it.name } == listOf("Спальня", "Кухня") && score.rooms.map { it.count } == listOf(6, 1), "комнаты")
        val quiet = Score.of(listOf(note("Баксик", 0)), plot, noon, utc)
        check(quiet.plants.size == 1 && quiet.rooms.size == 1, "без поливов — нет в списке")
    }

    @Test
    fun almanac() = checks {
        fun poured(plant: String, back: Int, hour: Int, left: Double?) = Watering(plant, day(back, hour), left)
        val yard = listOf(
            Room("Спальня", listOf(plantNamed("Баксик", 0.9, 9.0), plantNamed("Борис", 0.08, 5.0))),
            Room("Кухня", listOf(plantNamed("Мурзик", 0.3, 7.0))),
        )
        val log = listOf(
            poured("Баксик", 0, 9, 0.3), poured("Борис", 1, 19, 0.05), poured("Мурзик", 2, 19, 0.0),
            poured("Баксик", 3, 8, 0.55), poured("Борис", 6, 19, 0.25), poured("Мурзик", 7, 19, 0.3),
            poured("Баксик", 10, 10, null), poured("Борис", 40, 10, 0.35), poured("Борис", 400, 10, 0.2),
        )
        val book = Almanac.of(log, yard, Almanac.Period.WEEK, day(500), noon, utc)
        check(book.total == 5, "за неделю — семь дней с сегодняшним")
        check(book.previous == 2 && book.change == 3, "прошлая неделя — два, разница плюс три")
        check(book.active == 5 && book.length == 7, "пять дней с поливом из семи")
        check(book.bars.size == 7 && !book.byMonth, "семь столбиков")
        check(book.bars.first().start < book.bars.last().start && book.bars.last().count == 1 && book.bars.first().count == 1, "от старого к новому")
        check(book.streak == 4 && book.best == 4, "череда — четыре дня")
        check(
            book.aim.count(Almanac.Aim.Zone.EARLY) == 1 && book.aim.count(Almanac.Aim.Zone.ON_TIME) == 2 &&
                book.aim.count(Almanac.Aim.Zone.LAST_MOMENT) == 1 && book.aim.count(Almanac.Aim.Zone.DRY) == 1,
            "поливы по зонам",
        )
        check(round2(book.aim.share(Almanac.Aim.Zone.ON_TIME)), "0.40", "вовремя — две пятых")
        check(round2(book.aim.typical ?: -1.0), "0.25", "медиана — четверть")
        check(book.aim.usual == Almanac.Aim.Zone.ON_TIME, "чаще всего — вовремя")
        check(book.aim.bins == listOf(2, 0, 1, 1, 0, 1, 0, 0, 0, 0), "корзины по десять процентов")
        check(
            Almanac.Aim.zone(0.4) == Almanac.Aim.Zone.EARLY && Almanac.Aim.zone(0.2) == Almanac.Aim.Zone.ON_TIME &&
                Almanac.Aim.zone(0.19) == Almanac.Aim.Zone.LAST_MOMENT && Almanac.Aim.zone(0.005) == Almanac.Aim.Zone.DRY,
            "границы зон",
        )
        check(Almanac.Aim.of(listOf(Watering("x", noon))).known == 0, "без остатка — не в счёт")
        check(book.peakHour == 19 && book.hours[19] == 3, "чаще всего в семь вечера")
        check(book.cells.last().day == LocalDate.of(2026, 9, 18) && book.cells.last().count == 1, "календарь кончается сегодня")
        check(book.cells.first().day.dayOfWeek == DayOfWeek.MONDAY, "и начинается с начала недели")
        check(book.cells.size > (Almanac.WEEKS - 1) * 7 && book.cells.size <= Almanac.WEEKS * 7, "шестнадцать недель")
        check(book.cells.sumOf { it.count } == 8, "все поливы, кроме прошлогоднего")
        check(book.records.total == 9 && book.records.longest == 4, "рекорды за всё время")
        check(book.records.busiest?.count == 1 && book.records.busiest?.day == LocalDate.of(2026, 9, 18), "день-рекорд — последний из равных")
        check(book.records.earliest == 8 * 60 && book.records.latest == 19 * 60, "самый ранний и поздний")
        check(book.weekdays.first().number == 2, "неделя с понедельника")
        check(book.weekdays.map { it.count } == listOf(0, 1, 1, 1, 1, 1, 0), "по дням недели")
        check(book.peakDay?.number == 3, "из равных — первый")
        check(book.weekdays.first().name == "понедельник" && book.weekdays.first().symbol.isNotEmpty(), "названия дней по-русски")
        check(
            book.rooms.map { it.name } == listOf("Спальня", "Кухня") && book.rooms[0].waterings == 4 && book.rooms[1].waterings == 1,
            "комнаты — по жильцам",
        )
        check(round2(book.rooms[0].moisture ?: -1.0), "0.49", "средняя влажность комнаты")
        check(book.rooms[0].onTime == 0.5 && book.rooms[1].onTime == 0.0, "доля вовремя по комнате")
        val baksik = book.plants.first { it.id == "Баксик" }
        check(baksik.waterings == 2 && baksik.total == 3 && baksik.due == 8 && baksik.last == day(0, 9), "растение: за период, всего, срок")
        check(abs((baksik.typical ?: -1.0) - 0.425) < 1e-9, "обычный остаток")
        check(book.now.calm == 1 && book.now.warn == 1 && book.now.alarm == 1, "по одному в каждой зоне")
        check(book.now.driest == "Борис" && book.now.levels == listOf(0.08, 0.3, 0.9), "самый сухой и полоска")
        check(round2(book.now.content), "0.33", "довольна треть")
        check(book.ahead.size == Almanac.HORIZON, "прогноз на две недели")
        check(book.ahead.map { it.count } == listOf(1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0), "прогноз по срокам")
        check(book.ahead[8].names == listOf("Баксик"), "в прогнозе клички")

        val month = Almanac.of(log, yard, Almanac.Period.MONTH, day(500), noon, utc)
        check(month.total == 7 && month.previous == 1 && month.bars.size == 30, "месяц — тридцать дней")
        val year = Almanac.of(log, yard, Almanac.Period.YEAR, day(500), noon, utc)
        check(year.byMonth && year.bars.size == 12 && year.total == 8, "год — двенадцать месяцев")
        check(year.bars.last().count == 7 && year.bars[10].count == 1, "столбик месяца — все его поливы")
        val all = Almanac.of(log, yard, Almanac.Period.ALL, day(500), noon, utc)
        check(all.byMonth && all.total == 9 && all.previous == null, "всё время — по месяцам")
        val young = Almanac.of(log.take(3), yard, Almanac.Period.ALL, day(10), noon, utc)
        check(!young.byMonth && young.bars.size == 11, "молодой сад — по дням")
        val empty = Almanac.of(emptyList(), emptyList(), Almanac.Period.WEEK, day(3), noon, utc)
        check(empty.total == 0 && empty.peakHour == null && empty.peakDay == null && empty.now.average == null && empty.tallest == 0, "пустой сад")
        val future = Almanac.of(emptyList(), yard, Almanac.Period.ALL, noon + 86_400_000L * 3, noon, utc)
        check(future.bars.size == 1, "сад «из будущего» (часы переводили) — один столбик, а не пусто")

        val card = PlantBook.of(yard[0].plants[0], log, Almanac.Period.WEEK, day(500), noon, utc)
        check(card.total == 3 && card.inPeriod == 2 && card.last == day(0, 9), "растение: всего и за период")
        check(card.dues == listOf(8, 17, 26), "три ближайших полива")
        check(card.recent.map { it.at } == listOf(day(3, 8), day(0, 9)), "поливы периода от старого к новому")
    }

    @Test
    fun diary() = checks {
        val moscow = Days(ZoneId.of("Europe/Moscow"), DayOfWeek.MONDAY)
        fun at(day: Int, hour: Int, minute: Int, month: Int = 9, year: Int = 2026) =
            ZonedDateTime.of(year, month, day, hour, minute, 0, 0, moscow.zone).toInstant().toEpochMilli()
        val now = at(23, 15, 30)
        check(Diary.label(at(23, 14, 5), now, moscow), "Сегодня, 14:05", "сегодня")
        check(Diary.label(at(22, 9, 12), now, moscow), "Вчера, 09:12", "вчера")
        check(Diary.label(at(22, 0, 0), now, moscow), "Вчера, 00:00", "полночь")
        check(Diary.label(at(20, 18, 40), now, moscow), "20 сентября, 18:40", "в этом году — без года")
        // Между годом и «г.» — неразрывный пробел: какой именно, решает ICU телефона.
        check(
            Diary.label(at(2, 7, 0, 11, 2025), now, moscow).replace('\u00A0', ' ').replace('\u202F', ' '),
            "2 ноября 2025 г., 07:00",
            "в прошлом году — с годом",
        )
        Skeleton.hours24 = false
        speak("en")
        Skeleton.hours24 = false
        check(Diary.label(at(23, 14, 5), now, moscow), "Today, 2:05 PM", "по-английски — 12 часов, если так в телефоне")
        speak("ru")
        val log = listOf(
            Watering("x", at(20, 12, 0)), Watering("y", at(21, 12, 0)),
            Watering("x", at(23, 12, 0)), Watering("x", at(22, 0, 0)),
        )
        val diary = Diary.of(log, "x")
        check(diary.entries == listOf(at(23, 12, 0), at(22, 0, 0), at(20, 12, 0)), "его поливы, от свежего")
        check(diary.total == 3 && diary.average == 1.5 * 86_400_000, "три, раз в полтора дня")
        check(Diary.of(log, "y").average == null, "из одного среднего нет")
        check(Diary.rhythm(30_000.0), "чаще раза в минуту", "совсем часто")
        check(Diary.rhythm(60_000.0), "раз в минуту", "минута")
        check(Diary.rhythm(20 * 60_000.0), "раз в 20 минут", "минуты")
        check(Diary.rhythm(3 * 60_000.0), "раз в 3 минуты", "три минуты")
        check(Diary.rhythm(3_600_000.0), "раз в час", "час")
        check(Diary.rhythm(5 * 3_600_000.0), "раз в 5 часов", "часы")
        check(Diary.rhythm(2 * 3_600_000.0), "раз в 2 часа", "два часа")
        check(Diary.rhythm(1.2 * 86_400_000), "раз в день", "день")
        check(Diary.rhythm(1.5 * 86_400_000), "раз в 2 дня", "полтора дня — уже два")
        check(Diary.rhythm(5 * 86_400_000.0), "раз в 5 дней", "дни")
    }

    @Test
    fun reminders() = checks {
        fun delay(moisture: Double, days: Double = 7.0, threshold: Double = 0.2): String =
            Reminder.delay(plant(moisture, days), threshold)?.let { round2(it) } ?: "никогда"
        fun real(days: Double) = round2(days * 86_400 / Garden.SPEED)
        check(delay(0.5), real(2.1), "с 50% до 20% при недельной сушке — 2.1 суток сада")
        check(delay(0.5, 14.0), real(4.2), "вдвое медленнее — вдвое дольше")
        check(delay(0.2) == "0.00" && delay(0.05) == "0.00", "на пороге и ниже — уже пора")
        check(delay(0.5, 0.0), "никогда", "без скорости сушки срока нет")
        check(delay(0.5, 7.0, 0.4), real(0.7), "порог выше — ждать меньше")
        val thirsty = listOf(
            Room(
                "Комната",
                listOf(
                    plantNamed("Тихоня", 0.9, 7.0), plantNamed("Борис", 0.25, 5.0),
                    plantNamed("Сумка", 0.05, 6.0), plantNamed("Кефир", 0.1, 6.0),
                ),
            ),
        )
        val due = Reminder.next(thirsty, 0.2)!!
        check(due.plant.name, "Сумка", "первой — самая сухая")
        check("${due.others}", "1", "и с ней ещё одна")
        check(round2(due.after), "15.00", "не раньше четверти минуты")
        check(Reminder.text(due), "«Сумка» и ещё 1 растение просят воды", "строка с соседями")
        check(due.ids.toSet() == setOf("Сумка", "Кефир"), "«Полил» польёт всех, кому сухо")
        val single = Reminder.next(listOf(Room("Комната", listOf(plantNamed("Борис", 0.5, 5.0)))), 0.2)!!
        check(single.others == 0 && round2(single.after) == real(1.5), "в одиночку — полтора дня сада")
        check(Reminder.text(single), "«Борис» просит воды", "строка про одного")
        check(Reminder.next(emptyList(), 0.2) == null, "в пустой квартире будить некого")
        fun many(n: Int) = Reminder.text(Reminder.Due(plantNamed("Х", 0.0, 1.0), n, 0.0))
        check(many(1), "«Х» и ещё 1 растение просят воды", "1 растение")
        check(many(2), "«Х» и ещё 2 растения просят воды", "2 растения")
        check(many(5), "«Х» и ещё 5 растений просят воды", "5 растений")
        val fed = plantNamed("Фиалка", 1.0, 5.0).copy(care = Care(14.0, 10.0, 365.0, 300.0))
        val potted = plantNamed("Кактус", 1.0, 30.0).copy(care = Care(30.0, 0.0, 730.0, 728.0))
        Season.growing = true
        val chore = Reminder.chore(listOf(Room("Кухня", listOf(fed, potted))))!!
        check(chore.plant.name == "Кактус" && chore.repot, "ближайший уход — пересадка кактуса")
        check(Reminder.text(chore), "«Кактус» просится в горшок побольше", "строка о пересадке")
        Season.growing = false
        val winter = Reminder.chore(listOf(Room("Кухня", listOf(fed, potted.copy(care = potted.care!!.copy(repotEvery = null))))))
        check(winter?.plant?.name == "Фиалка" && winter.repot, "зимой — только пересадка")
        Season.growing = true
    }

    @Test
    fun species() = checks {
        fun guessed(vararg seen: Pair<String, Double>) = Species.read(seen.map { Sighting(it.first, it.second) })?.species ?: "—"
        check(guessed("plant" to 0.91, "houseplant" to 0.44, "cactus" to 0.21), "Кактус", "частное важнее общего")
        check(guessed("plant" to 0.91, "houseplant" to 0.44), "Комнатное растение", "без частного — общее")
        check(guessed("flowering_plant" to 0.5), "Цветок", "слово внутри ярлыка")
        check(guessed("rosemary" to 0.5), "Розмарин", "розмарин — не роза")
        check(guessed("tree_fern" to 0.5), "Папоротник", "древовидный папоротник")
        check(guessed("cactus" to 0.01, "plant" to 0.9), "Комнатное растение", "слабый ярлык не в счёт")
        check(guessed("dog" to 0.9, "sofa" to 0.4), "—", "без растения вида нет")
        check(guessed(), "—", "и на пустом")
        check("${Species.read(listOf(Sighting("Cactus", 0.3)))?.dryingDays}", "30.0", "кактусу месяц; регистр не мешает")
        check(Species.table.all { it.days <= Species.LONGEST }, "срок любого вида на барабане")
        check(Species.periodLabel(1.0), "Раз в 1 день", "1 день")
        check(Species.periodLabel(3.0), "Раз в 3 дня", "3 дня")
        check(Species.periodLabel(7.0), "Раз в 7 дней", "7 дней")
        check(Species.periodLabel(21.0), "Раз в 21 день", "21 день")
        check(Species.periodLabel(6.5), "Раз в 6,5 дня", "дробное")
        check(Species.periodLabel(10.4), "Раз в 10,4 дня", "дробное больше десяти")
        check(Species.usual(" кактус ") == 30.0 && Species.usual("Баобаб") == null, "обычный срок вида")
        val shadowed = mutableListOf<String>()
        for ((i, entry) in Species.table.withIndex()) {
            for (later in Species.table.drop(i + 1)) if (later.word.contains(entry.word)) shadowed.add(later.word)
        }
        check(shadowed.isEmpty(), "до каждого слова доходит очередь: $shadowed")
        check(Preset.of("Каменная роза") == Preset.ECHEVERIA, "каменная роза — суккулент")
        check(Preset.of("Розмарин") == Preset.ROSEMARY && Preset.of("Роза") == Preset.ROSE, "розмарин и роза")
        check(Preset.of("Баобаб") == Preset.SPATHIPHYLLUM && Preset.known("Баобаб") == null, "незнакомый — спатифиллум")
        check(Preset.of("Monstera deliciosa") == Preset.MONSTERA, "латынь")
        check(Preset.entries.all { Preset.raw(it.raw) == it }, "имена моделей разбираются обратно")
        speak("ja")
        check(Preset.of(Preset.CACTUS.title) == Preset.CACTUS, "кактус по-японски — тоже кактус")
        speak("ru")
    }

    @Test
    fun orrery() = checks {
        val sky = Orrery.orbits(
            listOf(plantNamed("Кактус", 0.5, 57.0), plantNamed("Борис", 0.5, 5.0), plantNamed("Алоэ", 0.5, 5.0), plantNamed("Баксик", 0.5, 9.0)),
        )
        check(sky.map { it.name } == listOf("Алоэ", "Борис", "Баксик", "Кактус"), "от быстрых к терпеливым")
        check(sky.first().radius == Orrery.INNER && sky.last().radius == Orrery.OUTER, "по краям")
        check(sky.map { it.rank } == listOf(0, 1, 2, 3), "номера по порядку")
        check(Orrery.angle(1.0) == 0.0 && abs(Orrery.angle(0.0) - 2 * PI) < 1e-9 && abs(Orrery.angle(0.5) - PI) < 1e-9, "углы")
        val half = Orrery.Orbit("x", "x", 10.0, 0.5, 0.5, 0)
        val coming = Orrery.sky(listOf(half), 4.999)[0].angle
        val gone = Orrery.sky(listOf(half), 5.001)[0].angle
        check(2 * PI - coming < 0.01 && gone < 0.01, "луч — в миг полива, без скачка")
        check(Spheres.notes(Orrery.crossings(listOf(half), 30.0), 1).map { round2(it.at) } == listOf("3.33", "10.00", "16.67"), "нота на луче")
        check(round2(Orrery.moisture(half, 3.0)) == "0.20" && round2(Orrery.moisture(half, 5.0)) == "1.00" && round2(Orrery.moisture(half, 7.0)) == "0.80", "влажность впереди")
        check(Orrery.crossings(listOf(half), 30.0).map { it.day } == listOf(5.0, 15.0, 25.0), "поливы впереди")
        val dry = half.copy(moisture = 0.0, period = 7.0)
        check(Orrery.crossings(listOf(dry), 30.0).map { it.day } == listOf(0.0, 7.0, 14.0, 21.0, 28.0), "сухую ждут сейчас")
        val crowd = Orrery.orbits(
            listOf(plantNamed("Раз", 0.4, 5.0), plantNamed("Два", 0.2, 10.0), plantNamed("Три", 0.1, 20.0), plantNamed("Четыре", 0.9, 30.0)),
        )
        val parades = Orrery.parades(crowd, 30.0)
        check(parades.first().day == 2 && parades.first().ids.size == 3, "парад — трое в один день")
        check(parades.first().names.toSet() == setOf("Раз", "Два", "Три"), "с кличками")
        check(Orrery.parades(crowd, 30.0, 5).isEmpty(), "пятерых не бывает")
        check(Orrery.orbits(emptyList()).isEmpty() && Orrery.orbits(listOf(plant(0.5, 0.0))).isEmpty(), "без срока — без орбиты")

        val top = Spheres.pitch(0, 5)
        check(round2(Spheres.pitch(4, 5)), "220.00", "дальняя — ля")
        check(top > 900 && top < 1000, "ближняя — на две октавы выше")
        check((0 until 5).map { Spheres.pitch(it, 5) }.zipWithNext().all { it.first > it.second }, "чем ближе, тем выше")
        check(round2(Spheres.notes(listOf(Orrery.Crossing("x", 15.0, 0)), 1).first().at), "10.00", "середина месяца — десятая секунда")
        val sound = Spheres.render(listOf(Spheres.Note(1.0, 440.0)))
        val second = Spheres.RATE * Spheres.CHANNELS
        check(sound.size == ((Spheres.SECONDS + Spheres.TAIL) * Spheres.RATE).toInt() * Spheres.CHANNELS, "длина — месяц и хвост")
        check((0 until second).all { sound[it] == 0f }, "до первой ноты тишина")
        check((second until second + second / 10).any { abs(sound[it]) > 0.3 }, "нота звучит")
        check(sound.all { abs(it) <= 0.91 }, "громкость с запасом")
        check(abs(sound.last()) < 0.001, "к концу стихает")
        val crowdSound = Spheres.render((0 until 12).map { Spheres.Note(2.0, Spheres.pitch(it, 12)) })
        check(crowdSound.all { abs(it) <= 0.91 }, "плотный парад не зашкаливает")
        val wide = Spheres.render(listOf(Spheres.Note(1.0, 440.0, -1.0)))
        val left = (second until second + second / 10 step 2).maxOf { abs(wide[it]) }
        val right = (second + 1 until second + second / 10 step 2).maxOf { abs(wide[it]) }
        check(left > 0.3 && right < left / 4, "нота слева — в левом канале")
        val file = Spheres.wav(sound)
        check(file.size == 44 + 2 * sound.size, "WAV: заголовок и 16 бит")
        check(String(file, 0, 4) == "RIFF" && String(file, 8, 4) == "WAVE" && file[22].toInt() == 2, "WAV: метки и стерео")
    }

    @Test
    fun trip() = checks {
        val rooms = listOf(
            Room("Кухня", listOf(plantNamed("папоротник", 0.2, 5.0), plantNamed("кактус", 0.9, 30.0), plantNamed("фикус", 0.5, 8.0))),
        )
        val needs = Trip.needs(rooms, 12)
        check(needs.map { it.plant.id } == listOf("папоротник", "фикус"), "соседу — кто не дождётся")
        check(needs[0].visits == listOf(4, 8) && needs[1].visits == listOf(7), "в какие дни")
        check(
            needs.all { need ->
                val stops = listOf(0) + need.visits + 12
                stops.zipWithNext().all { (it.second - it.first).toDouble() <= need.dries }
            },
            "никто не остаётся без воды дольше срока",
        )
        check(Trip.fine(rooms, 12).map { it.id } == listOf("кактус"), "кактус дождётся")
        check(Trip.needs(rooms, 3).isEmpty(), "на три дня — никого")
        val leave = LocalDate.of(2026, 6, 15)
        val back = leave.plusDays(12)
        check(Trip.days(leave, back) == 12 && Trip.days(back, leave) == 0, "дни поездки")
        val memo = Trip.memo(needs, leave, back)
        check(memo.contains("папоротник") && memo.contains("фикус") && !memo.contains("кактус"), "в памятке — кого полить")
        check(memo.startsWith("Привет! Меня не будет с 15 июня по 27 июня."), "даты по-русски: ${memo.lines().first()}")
        check(memo.contains("19 июня, 23 июня"), "дни визитов датами")
        check(Trip.memo(emptyList(), leave, back).contains("поливать никого"), "никого — так и написано")
    }

    @Test
    fun guide() = checks {
        val terms = Term.entries
        check(terms.all { it.title.isNotEmpty() && it.meaning.isNotEmpty() }, "у слов есть названия и пояснения")
        check(terms.map { it.title }.toSet().size == terms.size && terms.map { it.meaning }.toSet().size == terms.size, "не повторяются")
        val pages = Tour.pages
        check(pages.size == 7 && pages.map { it.id } == (0 until 7).toList(), "семь страниц по порядку")
        val all = Walk.entries.flatMap { it.hints }
        check(Walk.entries.all { it.hints.isNotEmpty() }, "у каждого экрана подсказки")
        check(all.size == Hint.Target.entries.size && all.map { it.target }.toSet().size == all.size, "место — ровно одна подсказка")
        check(all.all { it.target.raw.contains(".") }, "имя места — «экран.место»")
        val russian = terms.map { it.meaning } + pages.flatMap { listOf(it.title, it.text) } + all.map { it.text }
        val languages = listOf(
            "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "gu", "he", "hi", "hr", "hu", "id",
            "it", "ja", "kk", "kn", "ko", "lt", "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro",
            "sk", "sl", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
        )
        for (tongue in languages) {
            speak(tongue)
            val local = Term.entries.map { it.meaning } + Tour.pages.flatMap { listOf(it.title, it.text) } +
                Walk.entries.flatMap { it.hints }.map { it.text }
            val same = local.zip(russian).filter { it.first == it.second }.map { it.first }
            check(same.isEmpty(), "$tongue: знакомство, словарик и подсказки переведены: $same")
        }
        speak("ru")
    }

    @Test
    fun languages() = checks {
        speak("en")
        check(Lang.format("%lld растений", 1), "1 plant", "английский: одно")
        check(Lang.format("%lld растений", 5), "5 plants", "английский: много")
        check(Plant.wateringLabel(2), "Next watering: in 2 days", "английский: срок")
        check(Species.periodLabel(1.0), "Every 1 day", "английский: барабан")
        check(Term.WAVE.title, "Wave", "английский: словарик")
        speak("pl")
        check(Lang.format("%lld растений", 2), "2 rośliny", "польский: few")
        check(Lang.format("%lld растений", 5), "5 roślin", "польский: many")
        check(Lang.format("%lld растений", 22), "22 rośliny", "польский: 22")
        speak("cs")
        check(Lang.format("%lld растений", 3), "3 rostliny", "чешский: few")
        check(Lang.format("%lld растений", 7), "7 rostlin", "чешский: other")
        speak("ar")
        check(Lang.format("%lld растений", 2), "2 نبتتان", "арабский: два")
        check(Lang.format("%lld растений", 7), "7 نبتات", "арабский: few")
        check(Lang.format("%lld растений", 11), "11 نبتة", "арабский: many")
        speak("ja")
        check(Lang.format("%lld растений", 3), "3株", "японский: одна форма")
        speak("tr")
        check(Lang.format("%lld%%", 50), "%50", "турецкий: процент впереди")
        speak("de")
        check(Lang.format("%lld%%", 50), "50 %", "немецкий: неразрывный пробел")
        speak("fr")
        check(Seed.dueLine(emptyList()), "Aucune plante à arroser aujourd’hui.", "французский")
        speak("he")
        check(Lang.text("Полить") != "Полить", "иврит находится и под старым кодом")
        speak("id")
        check(Lang.text("Полить") != "Полить", "индонезийский тоже")
        speak("zh-Hant")
        val traditional = Lang.text("Настройки")
        speak("zh-Hans")
        check(traditional != Lang.text("Настройки") && traditional != "Настройки", "традиционный и упрощённый китайский различаются")
        speak("pt-PT")
        val portugal = Lang.text("Сад")
        speak("pt-BR")
        check(Lang.text("Сад").isNotEmpty() && portugal.isNotEmpty(), "оба португальских")
        speak("sv-SE")
        check(Lang.text("Полить") != "Полить", "шведский с регионом — шведский")
        speak("xx")
        check(Lang.text("Полить"), "Water", "незнакомый язык — английский")
        speak("ru")
        check(Lang.text("Полить"), "Полить", "русский — ключ как есть")
    }
}
