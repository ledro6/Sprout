import Foundation

/// «Это ваш Баксик?» — визуальный интеллект показывает растения сада, на
/// которые навели камеру. Кто в кадре, решают два свидетельства: сходство
/// кадра с фото растения и вид, который узнал классификатор. Своё фото
/// весомее картинки вида: по нему одну монстеру отличишь от другой.
enum Likeness {
    /// Что в кадре: растение ли вообще, и какое, если вид узнан.
    struct Sight: Equatable, Sendable {
        var preset: Preset?
    }

    struct Candidate: Equatable, Sendable {
        var id: Plant.ID
        /// Расстояние отпечатков кадра и фото растения; пусто — сравнить не
        /// с чем.
        var distance: Double?
        /// Вид растения тот же, что узнал классификатор.
        var kin: Bool
        /// Фото — снимок хозяина, а не картинка вида.
        var own: Bool
    }

    /// Слова классификатора про растение вообще, а не про вид.
    static let broad: Set<String> = [
        "houseplant", "flower", "leaf", "plant", "tree", "bush", "shrub",
        "grass", "herb", "seedling",
    ]

    /// Больше трёх не показываем: поиск ждёт короткого и быстрого ответа.
    static let shown = 3
    /// Дальше этого — не похоже, даже если вид совпал.
    static let cutoff = 1.25
    /// Совпавший вид приближает на столько.
    static let kinship = 0.25
    /// Картинка вида — слабое свидетельство: у всех монстер она одна.
    static let stock = 0.1

    /// Ярлыки классификатора и визуального интеллекта — в то, что в кадре.
    /// Список видов идёт от частного к общему: первое частное слово и есть
    /// вид, общие только говорят, что это растение. Ничего растительного —
    /// пусто: собаку за Баксика не выдаём.
    static func sight(_ seen: [Sighting],
                      floor: Double = Species.floor) -> Sight? {
        let strong = seen.filter { $0.confidence >= floor }
            .map { $0.name.lowercased() }
        var plant = false
        for entry in Species.table {
            guard strong.contains(where: { $0.contains(entry.word) }) else {
                continue
            }
            if broad.contains(entry.word) {
                plant = true
            } else {
                return Sight(preset: Preset.known(entry.species))
            }
        }
        return plant ? Sight(preset: nil) : nil
    }

    /// Меньше — похожее.
    static func score(_ candidate: Candidate) -> Double {
        var score = candidate.distance ?? 1
        if candidate.kin { score -= kinship }
        if !candidate.own { score += stock }
        return score
    }

    /// Самые похожие — первыми, не больше трёх.
    static func rank(_ candidates: [Candidate]) -> [Plant.ID] {
        var scored: [(id: Plant.ID, score: Double)] = []
        for candidate in candidates {
            let value = score(candidate)
            if value < cutoff { scored.append((candidate.id, value)) }
        }
        scored.sort { $0.score < $1.score }
        return scored.prefix(shown).map(\.id)
    }
}
