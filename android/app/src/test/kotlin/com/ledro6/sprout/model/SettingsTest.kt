package com.ledro6.sprout.model

import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class SettingsTest {
    @Before
    fun russian() = speak("ru")

    @Test
    fun defaults() = checks {
        val store = MemoryPrefs()
        val fresh = Settings(store)
        check("${fresh.theme}", "SYSTEM", "тема по умолчанию — за системой")
        check("${fresh.look}", "GRID", "плиткой — как в макете")
        check("${fresh.order}", "MANUAL", "в том порядке, как расставили")
        check("${fresh.chosen}", "[0, 1]", "в узоре росток и капля")
        check("${fresh.patternTint}", "GREEN", "узор зелёный")
        check("${fresh.waveTint}", "BLUE", "волна синяя")
        check(!fresh.reminders, "напоминания выключены")
        check(fresh.haptics && round2(fresh.hapticStrength) == "1.00", "отклик включён на полную")
        check(fresh.sounds && fresh.parallax && fresh.sway && fresh.seasons, "звуки, параллакс, разъезд и время года включены")
        check(round2(fresh.threshold), "0.20", "порог — двадцать процентов")
        check(!fresh.toured && !fresh.seen(Walk.STATS), "знакомство и подсказки ещё не показаны")
        check(fresh.avatarShot == null, "фото хозяина нет")
        check(!fresh.lock && !fresh.dynamicColor, "замок и цвета обоев выключены")
        fresh.launched()
        check(fresh.firstRun, "первый запуск — первый")
        check(Settings(store).launches == 1, "счётчик запусков записан")
        val second = Settings(store)
        second.launched()
        check(!second.firstRun, "второй — уже не первый")
    }

    @Test
    fun shapes() = checks {
        val fresh = Settings(MemoryPrefs())
        fresh.toggle(2)
        check("${fresh.chosen}", "[0, 1, 2]", "цветок добавился")
        fresh.toggle(0)
        check("${fresh.chosen}", "[1, 2]", "росток убрался")
        fresh.toggle(1)
        check("${fresh.chosen}", "[2]", "остался один цветок")
        check(!fresh.toggle(2), "последнюю выключить нельзя")
        check(!fresh.toggle(9), "несуществующая ничего не меняет")
        check("${fresh.chosen}", "[2]", "набор тот же")
    }

    @Test
    fun survives() = checks {
        val store = MemoryPrefs()
        val fresh = Settings(store)
        fresh.theme = Settings.Theme.DARK
        fresh.look = Settings.Look.LIST
        fresh.order = Settings.Order.THIRSTY
        fresh.toggle(3)
        fresh.reminders = true
        fresh.threshold = 0.37
        fresh.patternTint = Tint.ROSE
        fresh.waveTint = Tint.AMBER
        fresh.toured = true
        fresh.avatarShot = "me.jpg"
        fresh.lock = true
        fresh.mark(Walk.STATS)
        fresh.mark(Walk.PLANT)
        val reopened = Settings(store)
        check("${reopened.theme}", "DARK", "тема")
        check("${reopened.look}", "LIST", "вид")
        check("${reopened.order}", "THIRSTY", "порядок")
        check("${reopened.chosen}", "[0, 1, 3]", "фигурки")
        check(reopened.reminders, "напоминания")
        check(round2(reopened.threshold), "0.37", "порог — любым процентом")
        check("${reopened.patternTint}", "ROSE", "цвет узора")
        check("${reopened.waveTint}", "AMBER", "цвет волны")
        check(reopened.toured && reopened.lock, "знакомство и замок")
        check(reopened.avatarShot == "me.jpg", "фото хозяина")
        check(reopened.seen(Walk.STATS) && reopened.seen(Walk.PLANT) && !reopened.seen(Walk.ADD), "показанные подсказки")
        reopened.rewalk()
        check(!Settings(store).seen(Walk.STATS), "«показать снова» забывает все")
        fresh.parallax = false
        fresh.sway = false
        fresh.sounds = false
        fresh.seasons = false
        val stilled = Settings(store)
        check(!stilled.parallax && !stilled.sway && !stilled.sounds && !stilled.seasons, "выключенное прочиталось")
        fresh.hapticStrength = 0.35
        check(round2(Settings(store).hapticStrength), "0.35", "сила отклика")
        fresh.hapticStrength = 7.0
        check(round2(Settings(store).hapticStrength), "1.00", "сила не выходит за единицу")
        fresh.hapticStrength = 0.0
        check(!Settings(store).haptics, "ноль — отклика нет")
        fresh.threshold = 3.5
        check(round2(Settings(store).threshold), "0.20", "мусор в пороге — умолчание")
        fresh.threshold = 0.004
        check(round2(Settings(store).threshold), "0.20", "меньше процента — тоже")
        fresh.avatarShot = null
        check(Settings(store).avatarShot == null, "фото убрали")
    }

    @Test
    fun tints() = checks {
        check("${Tint.entries.size}", "11", "одиннадцать оттенков")
        check(Tint.entries.map { it.title }.toSet().size == Tint.entries.size, "названия не повторяются")
        check(Tint.entries.map { it.pale }.toSet().size == Tint.entries.size, "бледные не повторяются")
        check(Tint.entries.map { it.vivid }.toSet().size == Tint.entries.size, "насыщенные тоже")
        fun brightness(c: Channels) = (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255
        val pales = Tint.entries.map { brightness(it.pale) }
        check(pales.max() - pales.min() <= 0.01, "бледные одной светлоты")
        check(Tint.entries.all { brightness(it.vivid) < brightness(it.pale) }, "насыщенная темнее бледной")
        fun chroma(c: Channels) = maxOf(c.red, c.green, c.blue) - minOf(c.red, c.green, c.blue)
        check(Tint.entries.all { chroma(it.vivid) >= 150 }, "насыщенные насыщенны")
        check(Tint.of(99) == null && Tint.of(-1) == null, "мусор в ключе оттенком не станет")
        val rose = Shade(Tint.ROSE)
        val amber = Shade(Tint.AMBER)
        check(Shade.mix(rose, amber, 0.0) == rose && Shade.mix(rose, amber, 1.0) == amber, "концы перехода")
        check(Shade.mix(rose, amber, -5.0) == rose && Shade.mix(rose, amber, 5.0) == amber, "доля за краями")
        val half = Shade.mix(rose, amber, 0.5)
        check("${half.pale.red} ${half.pale.green} ${half.pale.blue}", "255.0 231.5 222.0", "середина по каналам")
    }

    @Test
    fun recents() = checks {
        val store = MemoryPrefs()
        val recent = Recents(store)
        check("${recent.queries.size}", "0", "на чистом месте пусто")
        recent.remember("Баксик")
        recent.remember("Сумка")
        check(recent.queries.joinToString(", "), "Сумка, Баксик", "свежий первым")
        recent.remember("баксик")
        check(recent.queries.joinToString(", "), "баксик, Сумка", "повтор всплывает наверх")
        recent.remember("  Ко  ")
        check(recent.queries.first(), "Ко", "пробелы обрезаются")
        recent.remember("к")
        recent.remember("   ")
        check(recent.queries.first(), "Ко", "одна буква и пустое не запоминаются")
        for (name in listOf("Борис", "Тапок", "Шуба", "Соня", "Гоша")) recent.remember(name)
        check("${recent.queries.size}", "${Recents.KEEP}", "список не растёт дальше отведённого")
        check(recent.queries.first(), "Гоша", "обрезается снизу")
        check(Recents(store).queries.size == Recents.KEEP, "пережил перезапуск")
        recent.forget("гоша")
        check(recent.queries.none { it == "Гоша" }, "забытый уходит, регистр не помеха")
        recent.clear()
        check("${recent.queries.size}", "0", "всё сразу тоже забывается")
    }

    @Test
    fun rivals() = checks {
        val mine = Rival("Святослав", 142, 5, 9, 27, 20_350)
        check(mine.code.startsWith(Rival.MARK), "код начинается меткой")
        check(!mine.code.contains("+") && !mine.code.contains("/") && !mine.code.contains("="), "нет знаков, которые портит переписка")
        val back = Rival.read(mine.code)
        check(back == mine, "код разбирается обратно целиком")
        check(Rival.read(mine.card)?.name ?: "—", "Святослав", "код находится внутри сообщения")
        check(Rival.read("Привет! ${mine.code}. До связи")?.total == 142, "точка после кода в код не входит")
        check(Rival.read("совсем не то") == null && Rival.read("${Rival.MARK}не-код") == null, "без кода и с битым — пусто")
        check(mine.card.contains("142 полива"), "счёт склонён по числу")
        // Код с айфона: base64url того же JSON, что пишет iOS.
        val iphone = "SPROUT1.eyJuIjoi0JDQvdGPIiwidCI6MywicyI6MSwiYiI6MiwicCI6NCwiZCI6MjAwMDB9"
        check(Rival.read(iphone) == Rival("Аня", 3, 1, 2, 4, 20_000), "код с айфона читается")
        check(Rival.read(Rival.mine("", Score(), 0, 0).code) == null, "с пустым именем — не разбирается")

        val store = MemoryPrefs()
        val table = Friends(store)
        table.add(Rival("Аня", 10, 1, 1, 2, 20_350))
        table.add(Rival("Боря", 30, 2, 4, 5, 20_350))
        check(table.rivals.joinToString(", ") { it.name }, "Боря, Аня", "от большего счёта к меньшему")
        table.add(Rival("аня", 99, 3, 3, 2, 20_351))
        check("${table.rivals.size}", "2", "тот же друг — одна строка")
        check(table.rivals.first().name, "аня", "новый счёт встал выше")
        check(Friends(store).rivals.size == 2, "таблица пережила перезапуск")
        check(table.take(mine.card, "святослав") == null, "свой код в соперники не берётся")
        check(table.take("тут кода нет", "Аня") == null, "текст без кода — тоже")
        check(table.take(mine.card, "Аня")?.name ?: "—", "Святослав", "чужой — берётся")
        table.remove("аня")
        check(table.rivals.joinToString(", ") { it.name }, "Святослав, Боря", "убранный уходит")
        store.put("rivals", "{мусор")
        check(Friends(store).rivals.isEmpty(), "битая таблица — пустая, а не падение")
    }
}
