import Foundation

/// Раскладка узора: какая фигурка стоит в узле сетки.
///
/// Номер фигурки сдвигается на постоянный шаг вбок и вниз; шаги взаимно
/// просты с числом фигурок, поэтому одинаковые не стоят рядом, а в ряду
/// встречаются все (шаг 2 при четырёх фигурках дал бы полосы). При двух
/// фигурках раскладок всего две — шахматная и она же со сдвигом. Шаги свои на
/// каждый запуск.
struct Weave: Equatable {
    var stepX = 1
    var stepY = 1

    var shift = 0

    init() {}

    init(count: Int, twistX: Int, twistY: Int, start: Int) {
        guard count > 1 else { return }
        let steps = (1 ..< count).filter { Self.divisor($0, count) == 1 }
        stepX = steps[abs(twistX) % steps.count]
        stepY = steps[abs(twistY) % steps.count]
        shift = abs(start) % count
    }

    /// Узлы в ряду нумеруются сплошь, `2·столбец + гнездо`: в ячейке два
    /// гнезда.
    func index(column: Int, slot: Int, row: Int, of count: Int) -> Int {
        guard count > 1 else { return 0 }
        let node = 2 * column + slot
        let raw = (stepX * node + stepY * row + shift) % count
        return raw < 0 ? raw + count : raw
    }

    private static func divisor(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : divisor(b, a % b)
    }
}
