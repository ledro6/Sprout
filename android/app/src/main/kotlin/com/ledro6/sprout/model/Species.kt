package com.ledro6.sprout.model

import kotlin.math.abs

/** Что увидела система: ярлык и уверенность. */
data class Sighting(val name: String, val confidence: Double)

data class Guess(val species: String, val dryingDays: Double, val confidence: Double)

/**
 * Перевод ярлыков классификатора в вид растения. Это подсказка, а не
 * определитель: кактус от папоротника он отличит, замиокулькас от
 * сансевиерии — нет, поэтому оба поля правятся руками.
 */
object Species {
    data class Row(val word: String, val species: String, val days: Double)

    /** Слова и сроки — от частного к общему, как на iOS. */
    val table: List<Row> = listOf(
        Row("cactus", Lang.key("Кактус"), 30.0),
        Row("succulent", Lang.key("Суккулент"), 21.0),
        Row("aloe", Lang.key("Алоэ"), 14.0),
        Row("jade", Lang.key("Толстянка"), 12.0),
        Row("bonsai", Lang.key("Бонсай"), 4.0),
        Row("orchid", Lang.key("Орхидея"), 9.0),
        Row("fern", Lang.key("Папоротник"), 5.0),
        Row("palm", Lang.key("Пальма"), 11.0),
        Row("bamboo", Lang.key("Бамбук"), 6.0),
        Row("ivy", Lang.key("Плющ"), 8.0),
        Row("monstera", Lang.key("Монстера"), 9.0),
        Row("philodendron", Lang.key("Филодендрон"), 8.0),
        Row("ficus", Lang.key("Фикус"), 7.0),
        Row("dracaena", Lang.key("Драцена"), 8.0),
        Row("violet", Lang.key("Фиалка"), 4.5),
        Row("tulip", Lang.key("Тюльпан"), 9.0),
        // «rosemary» содержит «rose» — поэтому выше.
        Row("rosemary", Lang.key("Розмарин"), 5.9),
        Row("rose", Lang.key("Роза"), 5.0),
        Row("lily", Lang.key("Лилия"), 6.0),
        Row("daisy", Lang.key("Ромашка"), 5.0),
        Row("sunflower", Lang.key("Подсолнух"), 4.0),
        Row("geranium", Lang.key("Пеларгония"), 5.4),
        Row("begonia", Lang.key("Бегония"), 6.2),
        Row("basil", Lang.key("Базилик"), 3.8),
        Row("mint", Lang.key("Мята"), 4.2),
        Row("herb", Lang.key("Зелень"), 4.0),
        Row("moss", Lang.key("Мох"), 3.0),
        Row("seedling", Lang.key("Росток"), 4.0),
        Row("bush", Lang.key("Кустик"), 8.0),
        Row("shrub", Lang.key("Кустик"), 8.0),
        Row("tree", Lang.key("Деревце"), 12.0),
        Row("grass", Lang.key("Трава"), 4.0),
        Row("houseplant", Lang.key("Комнатное растение"), 7.0),
        Row("flower", Lang.key("Цветок"), 5.0),
        Row("leaf", Lang.key("Комнатное растение"), 7.0),
        Row("plant", Lang.key("Комнатное растение"), 7.0),
    )

    /** Порог низкий нарочно: уверенность делится на сотни ярлыков. */
    const val FLOOR = 0.06

    /** Пусто — ни одного знакомого слова; придумывать вид тогда нечестно. */
    fun read(seen: List<Sighting>, floor: Double = FLOOR): Guess? {
        val strong = seen.filter { it.confidence >= floor }
            .sortedByDescending { it.confidence }
        for (entry in table) {
            val hit = strong.firstOrNull { it.name.lowercase().contains(entry.word) } ?: continue
            return Guess(Lang.text(entry.species), entry.days, hit.confidence)
        }
        return null
    }

    /** Потолок барабана срока: дольше без воды не живёт и кактус. */
    const val LONGEST = 60

    /** Дробное — одним знаком и в родительном: «6,5 дня». */
    fun periodLabel(days: Double): String {
        val whole = days.rounded()
        if (abs(days - whole) >= 0.05) return Lang.format("Раз в %@ дня", Lang.decimal(days))
        return Lang.format("Раз в %lld дней", whole.toInt())
    }

    fun periodPhrase(days: Double): String {
        val whole = days.rounded()
        if (abs(days - whole) >= 0.05) return Lang.format("раз в %@ дня", Lang.decimal(days))
        return Lang.format("раз в %lld дней", whole.toInt())
    }

    /** Обычный срок для вида — на языке телефона или по-русски. */
    fun usual(species: String): Double? {
        val name = species.trim()
        if (name.isEmpty()) return null
        return table.firstOrNull { row ->
            Lang.text(row.species).equals(name, ignoreCase = true) ||
                row.species.equals(name, ignoreCase = true)
        }?.days
    }
}
