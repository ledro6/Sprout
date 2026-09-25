import Foundation

/// Что увидела система: ярлык и уверенность. Свой тип, а не наблюдение
/// Vision, — чтобы разбор ярлыков проверялся без телефона.
struct Sighting: Hashable, Sendable {
    var name: String
    var confidence: Double
}

struct Guess: Hashable, Sendable {
    var species: String
    var dryingDays: Double
    var confidence: Double
}

/// Перевод ярлыков классификатора в вид растения. Это подсказка, а не
/// определитель: кактус от папоротника он отличит, замиокулькас от
/// сансевиерии — нет, поэтому оба поля правятся руками.
enum Species {
    /// Слова и сроки сушки — от частного к общему. Идём по списку, а не по
    /// уверенности: самый уверенный ярлык почти всегда самый общий, «plant».
    static let table: [(word: String, species: String, days: Double)] = [
        ("cactus", Lang.key("Кактус"), 30),
        ("succulent", Lang.key("Суккулент"), 21),
        ("aloe", Lang.key("Алоэ"), 14),
        ("jade", Lang.key("Толстянка"), 12),
        ("bonsai", Lang.key("Бонсай"), 4),
        ("orchid", Lang.key("Орхидея"), 9),
        ("fern", Lang.key("Папоротник"), 5),
        ("palm", Lang.key("Пальма"), 11),
        ("bamboo", Lang.key("Бамбук"), 6),
        ("ivy", Lang.key("Плющ"), 8),
        ("monstera", Lang.key("Монстера"), 9),
        ("philodendron", Lang.key("Филодендрон"), 8),
        ("ficus", Lang.key("Фикус"), 7),
        ("dracaena", Lang.key("Драцена"), 8),
        ("violet", Lang.key("Фиалка"), 4.5),
        ("tulip", Lang.key("Тюльпан"), 9),
        // Слово, внутри которого есть другое слово списка, стоит выше него:
        // «rosemary» содержит «rose».
        ("rosemary", Lang.key("Розмарин"), 5.9),
        ("rose", Lang.key("Роза"), 5),
        ("lily", Lang.key("Лилия"), 6),
        ("daisy", Lang.key("Ромашка"), 5),
        ("sunflower", Lang.key("Подсолнух"), 4),
        ("geranium", Lang.key("Пеларгония"), 5.4),
        ("begonia", Lang.key("Бегония"), 6.2),
        ("basil", Lang.key("Базилик"), 3.8),
        ("mint", Lang.key("Мята"), 4.2),
        ("herb", Lang.key("Зелень"), 4),
        ("moss", Lang.key("Мох"), 3),
        ("seedling", Lang.key("Росток"), 4),
        ("bush", Lang.key("Кустик"), 8),
        ("shrub", Lang.key("Кустик"), 8),
        ("tree", Lang.key("Деревце"), 12),
        ("grass", Lang.key("Трава"), 4),
        ("houseplant", Lang.key("Комнатное растение"), 7),
        ("flower", Lang.key("Цветок"), 5),
        ("leaf", Lang.key("Комнатное растение"), 7),
        ("plant", Lang.key("Комнатное растение"), 7),
    ]

    /// Порог низкий нарочно: уверенность делится на тысячи ярлыков, и даже
    /// верный редко берёт больше трети.
    static let floor = 0.06

    /// Пусто — ни одного знакомого слова; придумывать вид тогда нечестно.
    static func read(_ seen: [Sighting], floor: Double = Species.floor)
        -> Guess? {
        let strong = seen.filter { $0.confidence >= floor }
        for entry in table {
            // Наблюдения идут от самого уверенного, поэтому первое найденное
            // — лучшее.
            guard let hit = strong.first(where: {
                $0.name.lowercased().contains(entry.word)
            }) else { continue }
            return Guess(species: Lang.text(entry.species),
                         dryingDays: entry.days, confidence: hit.confidence)
        }
        return nil
    }

    /// Потолок барабана срока: дольше без воды не живёт и кактус.
    static let longest = 60

    /// Дробное — одним знаком и в родительном: «6,5 дня».
    static func periodLabel(_ days: Double) -> String {
        let whole = days.rounded()
        guard abs(days - whole) < 0.05 else {
            return Lang.format("Раз в %@ дня", Lang.decimal(days))
        }
        return Lang.format("Раз в %lld дней", Int(whole))
    }

    /// Срок в середине фразы: «раз в 6 дней».
    static func periodPhrase(_ days: Double) -> String {
        let whole = days.rounded()
        guard abs(days - whole) < 0.05 else {
            return Lang.format("раз в %@ дня", Lang.decimal(days))
        }
        return Lang.format("раз в %lld дней", Int(whole))
    }

    /// Обычный срок для вида из той же таблицы — названного на языке
    /// телефона или по-русски, как в саду, заведённом до смены языка.
    static func usual(for species: String) -> Double? {
        let name = species.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return table.first { row in
            [Lang.text(row.species), row.species].contains {
                $0.compare(name, options: .caseInsensitive) == .orderedSame
            }
        }?.days
    }
}
