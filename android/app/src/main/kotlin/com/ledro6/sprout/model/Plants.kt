package com.ledro6.sprout.model

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/** Насколько сухо: ниже 40% тень оранжевая, ниже 20% красная. */
enum class Thirst {
    CALM, WARN, ALARM;

    companion object {
        const val WARN_BELOW = 0.4
        const val ALARM_BELOW = 0.2

        fun of(moisture: Double): Thirst = when {
            moisture < ALARM_BELOW -> ALARM
            moisture < WARN_BELOW -> WARN
            else -> CALM
        }
    }
}

/** День без времени — день посадки. */
@Serializable
data class Day(val year: Int, val month: Int, val day: Int) {
    /** Битый день из файла — сегодня, а не падение. */
    val date: LocalDate
        get() = runCatching { LocalDate.of(year, month, day) }.getOrElse { LocalDate.now() }

    /** Для сортировки «Сначала новые». */
    val number: Int get() = year * 10_000 + month * 100 + day

    companion object {
        fun of(date: LocalDate) = Day(date.year, date.monthValue, date.dayOfMonth)
    }
}

@Serializable
data class Plant(
    val id: String,
    val name: String,
    val species: String,
    /** 0…1; полив возвращает к единице. */
    val moisture: Double,
    /** За сколько суток сада почва высыхает досуха. */
    val dryingDays: Double,
    val addedOn: Day,
    val photo: String = "monstera",
    /** Имя снимка хозяина; у макетных растений пусто. */
    val shot: String? = null,
    val note: String? = null,
    /** Чертёж своей модели — по снимку; нет — готовая модель вида. */
    val plan: Blueprint? = null,
    val care: Care? = null,
    /** Отклонённое предложение срока — чтобы не повторять. */
    val quiet: Double? = null,
) {
    val blueprint: Blueprint get() = plan ?: Blueprint.stock(species)

    val tending: Care get() = care ?: Care.usual(blueprint.preset)

    /** Срок с поправкой на время года. */
    val period: Double get() = dryingDays * Season.stretch

    /** Из влажности, а не хранится: два числа рано или поздно разошлись бы. */
    val daysUntilWatering: Int get() = max(0, (moisture * period).roundedInt())

    val thirst: Thirst get() = Thirst.of(moisture)

    /** 0 на пороге, 1 у сухой земли — без ступеней. */
    val alarm: Double
        get() {
            if (moisture >= Thirst.WARN_BELOW) return 0.0
            return min(1.0, (Thirst.WARN_BELOW - moisture) / Thirst.WARN_BELOW)
        }

    val moistureLabel: String get() = Lang.format("%lld%%", (moisture * 100).roundedInt())

    val wateringLabel: String get() = wateringLabel(daysUntilWatering)

    val addedLabel: String
        get() = Lang.format(
            "Добавлен %@",
            addedOn.date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT).withLocale(Lang.locale)),
        )

    fun dried(days: Double): Plant {
        if (dryingDays <= 0 || days <= 0) return this
        val per = period
        return copy(
            moisture = if (per > 0) max(0.0, moisture - days / per) else moisture,
            care = tending.passed(days, Season.growing),
        )
    }

    /** Новый срок — от того же полива: сколько земля уже сохла, столько осталось. */
    fun retimed(days: Double): Plant {
        if (days <= 0 || days == dryingDays) return this
        val dried = (1 - moisture) * dryingDays
        return copy(dryingDays = days, moisture = min(1.0, max(0.0, 1 - dried / days)))
    }

    /** От клички: у соседних сухих растений пульс не должен совпадать. */
    val pulsePhase: Double
        get() {
            var sum = 0
            var index = 0
            while (index < id.length) {
                val code = id.codePointAt(index)
                sum += code
                index += Character.charCount(code)
            }
            return (sum % 97) / 97.0
        }

    companion object {
        fun wateringLabel(days: Int): String = when {
            days <= 0 -> Lang.text("Следующий полив: сегодня")
            days == 1 -> Lang.text("Следующий полив: завтра")
            else -> Lang.format("Следующий полив: %lld дней", days)
        }

        fun new(
            name: String,
            species: String,
            dryingDays: Double,
            photo: String = "monstera",
            shot: String? = null,
            traits: Traits? = null,
            id: String = UUID.randomUUID().toString(),
            on: LocalDate = LocalDate.now(),
        ) = Plant(
            id = id, name = name, species = species, moisture = 1.0, dryingDays = dryingDays,
            addedOn = Day.of(on), photo = photo, shot = shot,
            plan = traits?.let { Blueprint(Preset.of(species), it, id) },
        )
    }
}

@Serializable
data class Room(val name: String, val plants: List<Plant>) {
    val id: String get() = name
}

/** Что убрали из сада и откуда. */
data class Removal(val plant: Plant, val room: String, val roomIndex: Int, val index: Int)

/** Полив, который ещё можно отменить. */
data class Pour(val plant: String, val name: String, val moisture: Double, val at: Long)

/** Слепок сада для файла. Необязательные поля — ради файлов прежних сборок. */
@Serializable
data class GardenState(
    val owner: String,
    val rooms: List<Room>,
    val savedAt: Long,
    val log: List<Watering> = emptyList(),
    val since: Long = savedAt,
    /** Метка записи — своя у каждого сохранения. */
    val stamp: String? = null,
    /** Поправка на время года в миг записи — виджету. */
    val season: Double? = null,
)

/** Начальные данные — тот же сад, что на iOS. */
object Seed {
    const val OWNER = ""

    val stranger: String get() = Lang.text("Садовод")

    fun greeting(owner: String): String {
        val name = owner.trim()
        return if (name.isEmpty()) Lang.text("Добро пожаловать!")
        else Lang.format("Добро пожаловать, %@!", name)
    }

    fun state(now: Long): GardenState = GardenState(OWNER, rooms(), now, emptyList(), now)

    private fun p(id: String, name: String, species: String, moisture: Double, days: Double, y: Int, m: Int, d: Int) =
        Plant(id, Lang.text(name), Lang.text(species), moisture, days, Day(y, m, d))

    /** На языке телефона: клички, комнаты и виды макета — тоже слова каталога. */
    fun rooms(): List<Room> = listOf(
        Room(
            Lang.text("Спальня"),
            listOf(
                p("baksik", "Баксик", "Тюльпан", 0.89, 9.0, 2024, 11, 2),
                p("pr", "Пр", "Монстера", 0.14, 7.0, 2025, 3, 17),
                p("tapok", "Тапок", "Хлорофитум", 0.62, 6.5, 2025, 5, 12),
                p("boris", "Борис", "Алоэ", 0.08, 5.0, 2024, 9, 30),
                p("shuba", "Шуба", "Папоротник", 0.45, 6.7, 2025, 7, 21),
                p("vasilisa", "Василиса", "Фиалка", 0.52, 4.5, 2025, 4, 3),
                p("kompot", "Компот", "Бегония", 0.27, 6.2, 2025, 5, 30),
                p("shnurok", "Шнурок", "Плющ", 0.71, 8.0, 2024, 12, 14),
            ),
        ),
        Room(
            Lang.text("Гостиная"),
            listOf(
                p("zelenik", "Зеленик", "Фикус", 0.30, 7.0, 2025, 1, 9),
                p("gosha", "Гоша", "Драцена", 0.73, 8.2, 2025, 2, 14),
                p("petrovich", "Петрович", "Кактус", 0.21, 57.0, 2023, 8, 5),
                p("sonya", "Соня", "Орхидея", 0.11, 9.0, 2025, 8, 19),
                p("malysh", "Малыш", "Пальма", 0.64, 11.0, 2024, 7, 22),
                p("grusha", "Груша", "Пеларгония", 0.18, 5.4, 2025, 5, 8),
                p("veter", "Ветер", "Диффенбахия", 0.41, 7.6, 2025, 1, 26),
            ),
        ),
        Room(
            Lang.text("Кухня"),
            listOf(
                p("murzik", "Мурзик", "Монстера", 0.89, 9.0, 2024, 12, 20),
                p("privet", "Привет", "Замиокулькас", 0.14, 7.0, 2025, 2, 4),
                p("lera", "Лера", "Сансевиерия", 0.56, 9.0, 2025, 4, 28),
                p("sumka", "Сумка", "Спатифиллум", 0.01, 6.0, 2025, 6, 1),
                p("baksik-2", "Баксик", "Тюльпан", 0.89, 9.0, 2024, 11, 2),
                p("ukrop", "Укроп", "Розмарин", 0.34, 5.9, 2025, 6, 7),
                p("baton", "Батон", "Хойя", 0.67, 10.4, 2024, 10, 11),
                p("kefir", "Кефир", "Толстянка", 0.05, 6.0, 2025, 3, 3),
                p("chesnok", "Чеснок", "Базилик", 0.38, 3.8, 2025, 8, 2),
                p("banka", "Банка", "Мята", 0.75, 4.2, 2025, 7, 14),
                p("sneg", "Снег", "Каланхоэ", 0.09, 8.8, 2024, 10, 5),
            ),
        ),
    )

    /** «Сегодня» — тем же счётом, что подпись на карточке. */
    fun due(rooms: List<Room>): List<Plant> =
        rooms.flatMap { it.plants }.filter { it.daysUntilWatering == 0 }.sortedBy { it.moisture }

    /** Больше пяти имён не держатся — остальные числом. */
    fun dueLine(plants: List<Plant>): String {
        val names = plants.map { it.name }
        return when (names.size) {
            0 -> Lang.text("Сегодня поливать никого не нужно.")
            1 -> Lang.format("Сегодня ждёт воды %@.", names[0])
            in 2..5 -> Lang.format(
                "Сегодня ждут воды %@.",
                Lang.format("%1\$@ и %2\$@", names.dropLast(1).joinToString(", "), names.last()),
            )
            else -> Lang.format(
                "Сегодня ждут воды %@.",
                Lang.format(
                    "%1\$@ и ещё %2\$@",
                    names.take(4).joinToString(", "),
                    Lang.format("%lld растений", names.size - 4),
                ),
            )
        }
    }

    fun search(query: String, rooms: List<Room>): List<Plant> {
        val text = query.trim().lowercase(Lang.locale)
        if (text.isEmpty()) return emptyList()
        return rooms.flatMap { it.plants }.filter {
            it.name.lowercase(Lang.locale).contains(text) ||
                it.species.lowercase(Lang.locale).contains(text) ||
                (it.note?.lowercase(Lang.locale)?.contains(text) ?: false)
        }
    }
}
