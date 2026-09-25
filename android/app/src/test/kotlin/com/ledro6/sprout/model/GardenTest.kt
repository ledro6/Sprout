package com.ledro6.sprout.model

import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.math.abs
import kotlin.math.max

/** Сад: те же проверки, что у модели iOS, — на Kotlin и ресурсах Android. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class GardenTest {
    @Before
    fun russian() {
        speak("ru")
        Season.stretch = 1.0
        Season.growing = true
    }

    @After
    fun reset() {
        Season.stretch = 1.0
        Season.growing = true
    }

    @Test
    fun days() = checks {
        fun label(d: Int) = Plant.wateringLabel(d)
        check(label(0), "Следующий полив: сегодня", "0 → сегодня")
        check(label(1), "Следующий полив: завтра", "1 → завтра")
        check(label(2), "Следующий полив: 2 дня", "2 дня")
        check(label(5), "Следующий полив: 5 дней", "5 дней")
        check(label(11), "Следующий полив: 11 дней", "11 дней")
        check(label(21), "Следующий полив: 21 день", "21 день")
        check(label(22), "Следующий полив: 22 дня", "22 дня")
    }

    @Test
    fun seed() = checks {
        val bedroom = Seed.rooms()[0]
        check(bedroom.name, "Спальня", "первая комната")
        check("${bedroom.plants.size}", "8", "растений в спальне")
        check(bedroom.plants[0].moistureLabel, "89%", "влажность Баксика")
        check(bedroom.plants[0].addedLabel, "Добавлен 02.11.2024", "дата добавления")
        check(bedroom.plants[0].wateringLabel, "Следующий полив: 8 дней", "89% при девяти сутках — 8 дней")
        check("${Seed.rooms()[1].plants.size}", "7", "растений в гостиной")
        check("${Seed.rooms()[2].plants.size}", "11", "растений на кухне")
        check(Seed.rooms().flatMap { it.plants }.map { it.id }.toSet().size == 26, "номера растений не повторяются")
    }

    @Test
    fun thirst() = checks {
        fun thirst(m: Double) = "${plant(m).thirst}"
        check(thirst(1.00), "CALM", "100% — спокойно")
        check(thirst(0.41), "CALM", "41% — ещё спокойно")
        check(thirst(0.40), "CALM", "40% — порог, тревоги ещё нет")
        check(thirst(0.39), "WARN", "39% — оранжевая")
        check(thirst(0.20), "WARN", "20% — порог, ещё оранжевая")
        check(thirst(0.19), "ALARM", "19% — уже красная")
        check(thirst(0.00), "ALARM", "0% — красная")
        fun alarm(m: Double) = round2(plant(m).alarm)
        check(alarm(0.50), "0.00", "50% — тревоги нет")
        check(alarm(0.40), "0.00", "40% — ноль на пороге")
        check(alarm(0.30), "0.25", "30% — четверть силы")
        check(alarm(0.20), "0.50", "20% — половина")
        check(alarm(0.10), "0.75", "10% — три четверти")
        check(alarm(0.00), "1.00", "0% — полная")
        var previous = -1.0
        var monotone = true
        for (step in 40 downTo 0) {
            val value = plant(step / 100.0).alarm
            if (value <= previous) monotone = false
            previous = value
        }
        check(monotone, "каждый процент вниз делает тень ярче")
        check(abs(plant(0.20).alarm - plant(0.201).alarm) < 0.01, "на переходе в красное яркость не прыгает")
    }

    @Test
    fun drying() = checks {
        val fern = plant(1.0, 7.0).dried(1.0)
        val cactus = plant(1.0, 57.0).dried(1.0)
        check(round2(fern.moisture), "0.86", "папоротник за сутки теряет седьмую часть")
        check(round2(cactus.moisture), "0.98", "кактус — почти ничего")
        check(round2(plant(0.05, 7.0).dried(100.0).moisture), "0.00", "ниже нуля влажность не уходит")
        check(plant(0.5, 0.0).dried(3.0).moisture == 0.5, "без срока — не сохнет и не делит на ноль")

        val hands = Hands()
        val garden = garden(hands)
        hands.move(86_400 / Garden.SPEED)
        garden.advance()
        check(round2(garden.plant("baksik")!!.moisture), "0.78", "за сутки сада Баксик потерял девятую часть")
        garden.advance(hands.now - 5000)
        check(round2(garden.plant("baksik")!!.moisture), "0.78", "часы назад — сад не молодеет")
    }

    @Test
    fun watering() = checks {
        val garden = garden()
        garden.water("baksik")
        check(round2(garden.plant("baksik")!!.moisture), "1.00", "полив наполняет до краёв")
        check("${garden.plant("baksik")!!.thirst}", "CALM", "и снимает тревогу")
        check(garden.plant("baksik")!!.wateringLabel, "Следующий полив: 9 дней", "срок пересчитался сам")
        garden.rename("baksik", "  Барсик  ")
        check(garden.plant("baksik")!!.name, "Барсик", "имя обрезается по краям")
        garden.rename("baksik", "   ")
        check(garden.plant("baksik")!!.name, "Барсик", "пустое имя не сохраняется")
        garden.remove("baksik")
        check(garden.plant("baksik") == null, "удалённое растение исчезает")
        check("${garden.rooms[0].plants.size}", "7", "и уходит из своей комнаты")
    }

    @Test
    fun lineup() = checks {
        val garden = garden()
        fun lineup(room: Int) = garden.rooms[room].plants.map { it.id }
        val lined = lineup(0)
        val (p1, p2, p3, p4) = lined
        garden.move(p1, p3)
        check(lineup(0).take(4) == listOf(p2, p3, p1, p4), "вперёд — встаёт за тем, над кем держат")
        garden.move(p1, p2)
        check(lineup(0).take(4) == listOf(p1, p2, p3, p4), "назад — встаёт перед ним")
        garden.move(p4, p1)
        check(lineup(0).take(4) == listOf(p4, p1, p2, p3), "с конца в начало")
        check(lineup(0).size == lined.size && lineup(0).toSet() == lined.toSet(), "никто не потерялся")
        val kitchen = lineup(2)
        garden.move(p1, kitchen[0])
        check(lineup(0).take(4) == listOf(p4, p1, p2, p3) && lineup(2) == kitchen, "в чужую комнату не переносит")
        garden.move(p1, p1)
        garden.move("никого-нет", p1)
        check(lineup(0).take(4) == listOf(p4, p1, p2, p3), "своё место и чужой номер ничего не меняют")
        val seen = lineup(0).reversed()
        garden.line(seen)
        check(lineup(0) == seen, "порядок с экрана становится ручным")
        garden.line(listOf(seen[2], seen[0]))
        check(lineup(0) == listOf(seen[2], seen[0], seen[1]) + seen.drop(3), "неназванные встают в хвост")
        garden.line(listOf("никого-нет"))
        check(lineup(0) == listOf(seen[2], seen[0], seen[1]) + seen.drop(3), "чужой номер порядок не трогает")
    }

    @Test
    fun search() = checks {
        val rooms = Seed.rooms()
        check("${Seed.search("лера", rooms).size}", "1", "«лера» находит одно")
        check("${Seed.search("баксик", rooms).size}", "2", "«баксик» находит два")
        check("${Seed.search("монстера", rooms).size}", "2", "ищет и по виду")
        check("${Seed.search("   ", rooms).size}", "0", "пустой запрос ничего не возвращает")
    }

    @Test
    fun journal() = checks {
        val shelf = MemoryShelf()
        val garden = garden(shelf = shelf)
        val before = garden.log.size
        garden.water("pr")
        check("${garden.log.size - before}", "1", "полив добавил запись")
        check(garden.log.last().plant, "pr", "и записал, кого")
        check(shelf.writes > 0, "и сад записался")
        val reopened = Garden(shelf)
        check(reopened.log.size == garden.log.size && reopened.plant("pr")!!.moisture == 1.0, "после перезапуска всё на месте")
        val rooms0 = garden.rooms.size
        val bed0 = garden.rooms[0].plants.size
        garden.add(Plant.new("Ёжик", "Кактус", 30.0), garden.rooms[0].name)
        check("${garden.rooms[0].plants.size - bed0}", "1", "растение встало в комнату")
        garden.add(Plant.new("Пыль", "Фикус", 7.0), "Кабинет")
        check("${garden.rooms.size - rooms0}", "1", "незнакомая комната заводится сама")
        check(garden.rooms.last().name, "Кабинет", "и с тем именем, что дали")
        check(Plant.new("А", "Б", 1.0).id != Plant.new("А", "Б", 1.0).id, "у одинаковых растений номера разные")
        garden.renameOwner("  Тёма  ")
        check(garden.owner, "Тёма", "имя хозяина обрезается")
        garden.renameOwner("   ")
        check(garden.owner, "Тёма", "пустое не сохраняется")
        check(garden(shelf = MemoryShelf()).signed, Seed.stranger, "безымянный сад подписывается «Садовод»")
    }

    @Test
    fun oldFile() = checks {
        val old = """{"owner":"Святослав","savedAt":760000000,"rooms":[{"name":"Спальня","plants":[
            {"id":"x","name":"Икс","species":"Игрек","moisture":0.5,"dryingDays":7,
            "addedOn":{"year":2024,"month":1,"day":1},"photo":"monstera"}]}]}"""
        val garden = Garden(MemoryShelf(old))
        check(garden.owner, "Святослав", "хозяин на месте")
        check("${garden.rooms[0].plants.size}", "1", "растения на месте")
        check("${garden.log.size}", "0", "журнала не было — он пуст, а не падение")
        check(garden.since == 760000000L, "дату сада берём от записи")
        val broken = Garden(MemoryShelf("{битый файл"))
        check(broken.rooms.size == 3, "битый файл — макетный сад, а не падение")
    }

    @Test
    fun removeAndPutBack() = checks {
        val yard = garden()
        val roster = yard.roster
        val bedroom = yard.rooms[0].plants.map { it.id }
        val gone = yard.remove("tapok")!!
        check(gone.room == "Спальня" && gone.index == 2 && gone.roomIndex == 0, "запомнилось, откуда взяли")
        check(yard.plant("tapok") == null, "убранного в саду нет")
        check(yard.roster > roster, "состав сада сменился")
        yard.putBack(gone)
        check(yard.rooms[0].plants.map { it.id } == bedroom, "вернулось ровно на своё место")
        yard.putBack(gone)
        check(yard.rooms[0].plants.count { it.id == "tapok" } == 1, "второй раз не встаёт")
        val lone = yard.remove("murzik")!!
        yard.deleteRoom("Кухня")
        yard.putBack(lone)
        check(yard.rooms.map { it.name } == listOf("Спальня", "Гостиная", "Кухня"), "комната заводится там, где стояла")
        check(yard.rooms[2].plants.map { it.id } == listOf("murzik"), "и в ней — вернувшееся растение")
        check(yard.remove("никого-нет") == null, "чужой номер убрать нельзя")
    }

    @Test
    fun rooms() = checks {
        val yard = garden()
        check(yard.addRoom("  Балкон "), "новая комната заводится")
        check(yard.rooms.last().name == "Балкон" && yard.rooms.last().plants.isEmpty(), "пустой и с обрезанным именем")
        check(!yard.addRoom("балкон"), "занятое имя не годится — без оглядки на регистр")
        check(!yard.addRoom("   "), "пустое тоже")
        check(yard.renameRoom("Балкон", "Лоджия"), "переименовать можно")
        check(!yard.renameRoom("Лоджия", "кухня"), "в чужое имя — нельзя")
        check(yard.renameRoom("Лоджия", "Лоджия"), "своё имя заново — не ошибка")
        check(!yard.renameRoom("Лоджия", " "), "в пустое — нельзя")
        check(!yard.renameRoom("Чулан", "Кладовка"), "несуществующую — тоже")
        yard.moveRoom(3, 0)
        check(yard.rooms.map { it.name } == listOf("Лоджия", "Спальня", "Гостиная", "Кухня"), "последняя встала первой")
        yard.moveRoom(0, 3)
        check(yard.rooms.map { it.name } == listOf("Спальня", "Гостиная", "Кухня", "Лоджия"), "и обратно в конец")
        yard.moveRoom(0, 9)
        yard.moveRoom(-1, 0)
        check(yard.rooms.map { it.name } == listOf("Спальня", "Гостиная", "Кухня", "Лоджия"), "за край не двигается")
        yard.relocate("baksik", "Лоджия")
        check(yard.roomName("baksik") == "Лоджия" && yard.rooms[3].plants.map { it.id } == listOf("baksik"), "переехал")
        val before = yard.rooms.map { r -> r.plants.map { it.id } }
        yard.relocate("baksik", "Лоджия")
        check(yard.rooms.map { r -> r.plants.map { it.id } } == before, "в свою же комнату — ничего не меняется")
        yard.relocate("pr", "Чердак")
        check(yard.rooms.last().name == "Чердак" && yard.rooms.last().plants.map { it.id } == listOf("pr"), "в новую — комната заводится")
        val count = yard.plantCount
        yard.deleteRoom("Кухня")
        check(yard.rooms.none { it.name == "Кухня" } && yard.plantCount == count - 11, "удалённая комната уносит растения")
    }

    @Test
    fun order() = checks {
        val bedroom = Seed.rooms()[0].plants
        check(Settings.Order.MANUAL.arrange(bedroom).map { it.id } == bedroom.map { it.id }, "вручную — как расставили")
        check(
            Settings.Order.THIRSTY.arrange(bedroom).map { it.id } ==
                listOf("boris", "pr", "kompot", "vasilisa", "shuba", "tapok", "shnurok", "baksik"),
            "сначала сухие — по сроку полива",
        )
        check(
            Settings.Order.NAME.arrange(bedroom).map { it.name } ==
                listOf("Баксик", "Борис", "Василиса", "Компот", "Пр", "Тапок", "Шнурок", "Шуба"),
            "по имени — по алфавиту",
        )
        check(
            Settings.Order.NEWEST.arrange(bedroom).map { it.id } ==
                listOf("shuba", "kompot", "tapok", "vasilisa", "pr", "shnurok", "baksik", "boris"),
            "сначала новые — по дню посадки",
        )
        val day = Day(2025, 1, 1)
        val twins = listOf(Plant("a", "Б", "", 0.5, 4.0, day), Plant("b", "А", "", 0.25, 8.0, day))
        check(Settings.Order.THIRSTY.arrange(twins).map { it.id } == listOf("a", "b"), "равные сроки остаются как стояли")
        check(Settings.Order.NEWEST.arrange(twins).map { it.id } == listOf("a", "b"), "и равные дни посадки")
        check(Settings.Order.NAME.arrange(twins).map { it.id } == listOf("b", "a"), "а по имени — по имени")
        val numbered = listOf("Фикус 10", "фикус 2", "Фикус 1").map { Plant(it, it, "", 1.0, 1.0, day) }
        check(
            Settings.Order.NAME.arrange(numbered).map { it.id } == listOf("Фикус 1", "фикус 2", "Фикус 10"),
            "числа в кличках — по значению, а регистр не мешает",
        )
    }

    @Test
    fun due() = checks {
        val due = Seed.due(Seed.rooms())
        check(due.map { it.id } == listOf("sumka", "kefir", "boris"), "у кого «сегодня» — от самого сухого")
        check(Seed.dueLine(due), "Сегодня ждут воды Сумка, Кефир и Борис.", "три имени")
        check(Seed.dueLine(due.take(2)), "Сегодня ждут воды Сумка и Кефир.", "два имени")
        check(Seed.dueLine(due.take(1)), "Сегодня ждёт воды Сумка.", "одно — в единственном")
        check(Seed.dueLine(emptyList()), "Сегодня поливать никого не нужно.", "никого")
        check(
            Seed.dueLine(Seed.rooms()[0].plants.take(7)),
            "Сегодня ждут воды Баксик, Пр, Тапок, Борис и ещё 3 растения.",
            "больше пяти — остальные числом",
        )
    }

    @Test
    fun retime() = checks {
        val fern = plant(4.0 / 7, 7.0).retimed(14.0)
        check(round2(fern.moisture), round2(11.0 / 14), "сохло три дня из недели — из двух остаётся одиннадцать")
        check("${fern.daysUntilWatering}", "11", "срок на карточке тоже")
        check(round2(plant(0.0, 7.0).retimed(28.0).moisture), "0.75", "сухой при месячном сроке — не сухой")
        check(round2(plant(0.5, 10.0).retimed(4.0).moisture), "0.00", "короче, чем уже сохло, — досуха")
        val same = plant(0.3, 7.0).retimed(7.0).retimed(0.0)
        check(round2(same.moisture) == "0.30" && same.dryingDays == 7.0, "тот же или нулевой срок ничего не меняет")

        val garden = garden()
        val roster = garden.roster
        garden.tune("baksik", "  Бакс ", "Роза", 18.0)
        val bax = garden.plant("baksik")!!
        check(bax.name, "Бакс", "кличка обрезается")
        check(bax.species, "Роза", "вид сменился")
        check(bax.dryingDays == 18.0, "срок сменился")
        check(garden.roster > roster, "состав сада сменился")
        garden.tune("baksik", " ", "", 18.0)
        val kept = garden.plant("baksik")!!
        check(kept.name == "Бакс" && kept.species == "Роза", "пустые кличка и вид остаются прежними")
    }

    @Test
    fun notes() = checks {
        val garden = garden()
        garden.note("pr", "  Пересадил в мае.\nУдобрять раз в месяц.  \n")
        check(garden.plant("pr")!!.note ?: "", "Пересадил в мае.\nУдобрять раз в месяц.", "обрезается по краям")
        check(garden.search("удобрять").map { it.id } == listOf("pr"), "поиск находит и по заметке")
        garden.note("pr", "   ")
        check(garden.plant("pr")!!.note == null, "пустая — стёрта")
    }

    @Test
    fun unwater() = checks {
        val hands = Hands()
        val garden = garden(hands)
        val before = garden.plant("sumka")!!.moisture
        val count = garden.log.size
        val moment = hands.now
        val pour = garden.water("sumka", moment)!!
        check(round2(pour.moisture), round2(before), "полив помнит, что было")
        check(pour.name, "Сумка", "и кличку — для плашки")
        hands.move(2.0)
        garden.advance()
        val dried = 1 - garden.plant("sumka")!!.moisture
        garden.unwater(pour)
        check(round2(garden.plant("sumka")!!.moisture), round2(max(0.0, before - dried)), "влажность прежняя, за вычетом высохшего")
        check(garden.log.size == count, "запись ушла из журнала")
        check(garden.water("нет такого") == null, "чужой номер не поливается")
        check(garden.log.size == count, "и в журнал не пишется")
        val first = Watering("pr", moment - 60_000)
        garden.water("pr", first.at)
        garden.water("pr", moment)
        val wet = garden.plant("pr")!!.moisture
        garden.forget(first)
        check(Diary.of(garden.log, "pr").entries == listOf(moment), "ошибочная запись стёрта, другая осталась")
        check(garden.plant("pr")!!.moisture == wet, "а влажность не тронута")
        val gone = garden.remove("pr")!!
        val pourGone = Pour("pr", "Пр", 0.3, moment)
        garden.unwater(pourGone)
        check(garden.plant("pr") == null, "отмена полива убранного растения не воскрешает его")
        garden.putBack(gone)
    }

    @Test
    fun blueprint() = checks {
        val traits = Traits(Channels(90.0, 160.0, 60.0))
        val planted = Plant.new("Новый", "Фикус", 7.0, traits = traits, id = "новый-1")
        check(planted.plan?.seed == "новый-1" && planted.plan?.preset == Preset.FICUS, "по снимку — чертёж с зерном")
        check(Plant.new("Без", "Фикус", 7.0).plan == null, "без снимка чертежа нет")
        check(Plant.new("Без", "Фикус", 7.0).blueprint == Blueprint.stock("Фикус"), "и растёт готовая модель вида")
        val json = MemoryShelf.json
        val back = json.decodeFromString(Plant.serializer(), json.encodeToString(Plant.serializer(), planted))
        check(back.plan == planted.plan, "чертёж переживает запуск")
        val garden = garden()
        garden.add(planted, "Кабинет")
        garden.tune("новый-1", "Новый", "Кактус", 7.0)
        val changed = garden.plant("новый-1")!!.plan
        check(changed?.preset == Preset.CACTUS && changed.traits == traits, "сменили вид — черты остаются")
        garden.unmodel("новый-1")
        check(garden.plant("новый-1")!!.plan == null, "назад к готовой модели")
    }

    @Test
    fun seasons() = checks {
        check(Season.side("RU") == Season.Side.NORTH, "Россия — север")
        check(Season.side("au") == Season.Side.SOUTH, "Австралия — юг")
        check(Season.side("SG") == Season.Side.TROPICS, "Сингапур — у экватора")
        check(Season.side(null) == Season.Side.NORTH && Season.side("") == Season.Side.NORTH, "страна неизвестна — север")
        check(Season.stretch(1, Season.Side.NORTH) > 1.3, "январь на севере — длиннее")
        check(Season.stretch(7, Season.Side.NORTH) < 0.9, "июль на севере — короче")
        check(Season.stretch(7, Season.Side.SOUTH) == Season.stretch(1, Season.Side.NORTH), "южный июль — северный январь")
        check((1..12).all { Season.stretch(it, Season.Side.TROPICS) == 1.0 }, "у экватора срок тот же")
        check(
            Season.growing(5, Season.Side.NORTH) && !Season.growing(12, Season.Side.NORTH) &&
                Season.growing(12, Season.Side.SOUTH),
            "пора роста: весна и лето своего полушария",
        )
        val steps = (1..12).map { Season.stretch(it, Season.Side.NORTH) }
        check(steps.zip(steps.drop(1) + steps[0]).all { abs(it.first - it.second) < 0.25 }, "от месяца к месяцу не прыгает")
        Season.stretch = 1.35
        val wintry = plant(1.0, 10.0)
        check(round2(wintry.period), "13.50", "зимой срок длиннее записанного")
        check(round2(wintry.dried(13.5).moisture), "0.00", "и земля сохнет за зимний срок")
        check(wintry.dryingDays == 10.0, "записанный срок не меняется")
        Season.stretch = 1.0
        check(Season.line(1.35) != null && Season.line(1.15) != null && Season.line(0.85) != null, "зимой, в холод и летом есть строка")
        check(Season.line(1.0) == null && Season.line(0.95) == null, "в межсезонье — молчит")
    }

    @Test
    fun rhythm() = checks {
        var often = plant(0.5, 9.0)
        fun entries(left: List<Double>) = left.mapIndexed { i, l -> Watering("x", i * 1000L, l) }
        check(Rhythm.suggest(often, entries(listOf(0.4, 0.3, 0.35))) == 6.0, "поливают при трети воды — 9 дней до 6")
        check(Rhythm.suggest(often, entries(listOf(0.4, 0.3))) == null, "двух поливов мало")
        check(Rhythm.suggest(often, entries(listOf(0.05, 0.1, 0.0, 0.15))) == null, "поливают у сухой земли — срок верный")
        check(
            Rhythm.suggest(often, entries(listOf(0.4, 0.3, 0.35)) + Watering("y", 0, 0.9)) == 6.0,
            "чужие поливы в счёт не идут",
        )
        check(Rhythm.suggest(often, List(3) { Watering("x", 0) }) == null, "без доли воды ничего не предлагает")
        often = often.copy(quiet = 6.0)
        check(Rhythm.suggest(often, entries(listOf(0.4, 0.3, 0.35))) == null, "отклонённое не повторяется")
        check(Rhythm.suggest(often, entries(listOf(0.6, 0.55, 0.62))) == 4.0, "а новое — предлагается")

        val yard = garden()
        val id = yard.rooms[0].plants[0].id
        val before = yard.plant(id)!!.moisture
        val pour = yard.water(id)!!
        check(round2(yard.log.last().left ?: -1.0) == round2(before), "полив пишет, сколько воды оставалось")
        yard.unwater(pour)
        check(yard.log.none { it.plant == id && it.at == pour.at }, "отмена находит запись и с долей воды")
        val old = MemoryShelf.json.decodeFromString(Watering.serializer(), """{"plant":"a","at":0}""")
        check(old.left == null, "запись без доли воды читается")
    }

    @Test
    fun care() = checks {
        check(
            Care.usual(Preset.CACTUS).feedEvery == 30.0 && Care.usual(Preset.VIOLET).feedEvery == 14.0 &&
                Care.usual(Preset.MONSTERA).repotEvery == 365.0,
            "сроки ухода — по виду",
        )
        var care = Care(feedEvery = 14.0, repotEvery = 365.0).passed(10.0, false)
        check(care.sinceFed == 0.0 && care.sinceRepot == 10.0, "зимой подкормка не считается, а пересадка — да")
        care = care.passed(14.0, true)
        check(care.feedDue && !care.repotDue, "за две недели роста — пора подкормить")
        check(Care(feedEvery = null).feedIn == null && !Care(feedEvery = null).feedDue, "выключенная подкормка не напоминает")
        check(Care(feedEvery = 14.0, sinceFed = 4.0).feedLabel ?: "", "Подкормка через 10 дней", "подпись подкормки")
        check(Care(repotEvery = 365.0, sinceRepot = 0.0).repotLabel ?: "", "Пересадка через 12 месяцев", "подпись пересадки")
        check(Care(repotEvery = 365.0, sinceRepot = 350.0).repotLabel ?: "", "Пересадка через 15 дней", "меньше месяца — днями")

        val hands = Hands()
        val yard = garden(hands)
        val id = yard.rooms[0].plants[0].id
        hands.move(20 * 86_400 / Garden.SPEED)
        yard.advance()
        val grown = yard.plant(id)!!.tending
        check(round2(grown.sinceFed) == "20.00" && round2(grown.sinceRepot) == "20.00", "дни ухода идут вместе с влажностью")
        yard.feed(id)
        check(yard.plant(id)!!.tending.sinceFed == 0.0 && yard.plant(id)!!.tending.sinceRepot > 0, "подкормили — счёт заново")
        hands.move(20 * 86_400 / Garden.SPEED)
        yard.advance()
        yard.repot(id)
        check(yard.plant(id)!!.tending.sinceFed == 0.0 && yard.plant(id)!!.tending.sinceRepot == 0.0, "пересадили — оба счёта заново")
        yard.tend(id, null, Care.days(18))
        check(
            yard.plant(id)!!.tending.feedEvery == null && Care.months(yard.plant(id)!!.tending.repotEvery!!) == 18,
            "сроки ухода правятся из настроек",
        )
    }
}
