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
        ("cactus", "Кактус", 30),
        ("succulent", "Суккулент", 21),
        ("aloe", "Алоэ", 14),
        ("jade", "Толстянка", 12),
        ("bonsai", "Бонсай", 4),
        ("orchid", "Орхидея", 9),
        ("fern", "Папоротник", 5),
        ("palm", "Пальма", 11),
        ("bamboo", "Бамбук", 6),
        ("ivy", "Плющ", 8),
        ("monstera", "Монстера", 9),
        ("philodendron", "Филодендрон", 8),
        ("ficus", "Фикус", 7),
        ("dracaena", "Драцена", 8),
        ("violet", "Фиалка", 4.5),
        ("tulip", "Тюльпан", 9),
        // Слово, внутри которого есть другое слово списка, стоит выше него:
        // «rosemary» содержит «rose».
        ("rosemary", "Розмарин", 5.9),
        ("rose", "Роза", 5),
        ("lily", "Лилия", 6),
        ("daisy", "Ромашка", 5),
        ("sunflower", "Подсолнух", 4),
        ("geranium", "Пеларгония", 5.4),
        ("begonia", "Бегония", 6.2),
        ("basil", "Базилик", 3.8),
        ("mint", "Мята", 4.2),
        ("herb", "Зелень", 4),
        ("moss", "Мох", 3),
        ("seedling", "Росток", 4),
        ("bush", "Кустик", 8),
        ("shrub", "Кустик", 8),
        ("tree", "Деревце", 12),
        ("grass", "Трава", 4),
        ("houseplant", "Комнатное растение", 7),
        ("flower", "Цветок", 5),
        ("leaf", "Комнатное растение", 7),
        ("plant", "Комнатное растение", 7),
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
            return Guess(species: entry.species, dryingDays: entry.days,
                         confidence: hit.confidence)
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

    /// Обычный срок для вида, вписанного по-русски, — из той же таблицы.
    static func usual(for species: String) -> Double? {
        let name = species.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return table.first {
            $0.species.compare(name, options: .caseInsensitive) == .orderedSame
        }?.days
    }
}
