import Foundation

/// Вид из каталога: название и то, что приложение о нём уже знает.
/// Срок полива — из таблицы классификатора (`Species.table`), подкормка,
/// пересадка и мелкий уход — сроки вида (`Care.usual`), питомцы — из
/// `Toxicity`. Чего в этих данных нет — того нет и на странице: свет,
/// температуру и влажность воздуха приложение по видам не хранит, а
/// придумывать их нечестно.
struct Specimen: Identifiable, Hashable, Sendable {
    /// Название на языке приложения.
    var title: String
    /// Готовая модель вида — по ней же и сроки ухода.
    var preset: Preset

    var id: String { title }

    /// Раз в сколько дней поливать; пусто — срока в данных нет, и барабан
    /// при посадке не трогаем.
    var watering: Double? { Species.usual(for: title) }

    /// Сроки, которые растение получит при посадке, — те же, что подставит
    /// экран «Добавить».
    var care: Care { Care.usual(for: preset) }

    /// Мелкий уход, который виду нужен, — со сроками, в порядке `Duty`.
    var duties: [(duty: Duty, days: Double)] {
        Duty.allCases.compactMap { duty in
            duty.usual(for: preset).map { (duty, $0) }
        }
    }

    var toxicity: Toxicity? { Toxicity.of(title) }
}

/// Каталог видов: готовые модели (`Preset`) и виды, которые узнаёт
/// классификатор (`Species`), — без общих слов вроде «Цветок» или
/// «Деревце»: это не вид. Работает без сети — всё уже в приложении.
enum Herbarium {
    /// Общие ярлыки классификатора: по ним вид не узнать.
    private static let vague: Set<String> = [
        Lang.key("Суккулент"), Lang.key("Зелень"), Lang.key("Росток"),
        Lang.key("Кустик"), Lang.key("Деревце"), Lang.key("Трава"),
        Lang.key("Цветок"), Lang.key("Комнатное растение"),
    ]

    /// Все виды по алфавиту. Вид из таблицы классификатора, который своим
    /// названием сводится к готовой модели («Филодендрон» — к монстере),
    /// — отдельной строкой; не сводится ни к одной («Бонсай») — его нет:
    /// сроков ухода для него не найти.
    static var all: [Specimen] {
        var seen = Set<String>()
        var out: [Specimen] = []
        for preset in Preset.allCases {
            let title = preset.title
            guard seen.insert(fold(title)).inserted else { continue }
            out.append(Specimen(title: title, preset: preset))
        }
        for row in Species.table where !vague.contains(row.species) {
            let title = Lang.text(row.species)
            guard let preset = Preset.known(title),
                  seen.insert(fold(title)).inserted
            else { continue }
            out.append(Specimen(title: title, preset: preset))
        }
        return out.sorted { fold($0.title) < fold($1.title) }
    }

    /// Для сравнения: без регистра, без пробелов по краям и «ё» как «е» —
    /// «Ёлка» найдётся и по «елка».
    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{0451}", with: "\u{0435}")
    }

    /// Найденное — от лучшего совпадения: всё название, его начало, начало
    /// слова в нём, кусок внутри — и, наконец, вид, к которому запрос
    /// сводится по основам `Preset` («щучий хвост» — сансевиерия). Пустой
    /// запрос — весь каталог.
    static func search(_ query: String, in list: [Specimen]? = nil)
        -> [Specimen] {
        let list = list ?? all
        let asked = fold(query)
        guard !asked.isEmpty else { return list }
        let kin = asked.count >= 3 && !general(asked)
            ? Preset.known(asked) : nil
        let scored = list.compactMap { specimen -> (Specimen, Int)? in
            rank(asked, specimen, kin: kin).map { (specimen, $0) }
        }
        return scored.sorted {
            $0.1 != $1.1 ? $0.1 < $1.1 : fold($0.0.title) < fold($1.0.title)
        }.map(\.0)
    }

    /// Меньше — лучше; пусто — не подходит.
    private static func rank(_ asked: String, _ specimen: Specimen,
                             kin: Preset?) -> Int? {
        let title = fold(specimen.title)
        if title == asked { return 0 }
        if title.hasPrefix(asked) { return 1 }
        let words = title.split { !$0.isLetter && !$0.isNumber }
        if words.contains(where: { $0.hasPrefix(asked) }) { return 2 }
        if asked.count >= 2, title.contains(asked) { return 3 }
        // По основе — только сама готовая модель, а не все виды при ней:
        // «филодендрон» ведёт к монстере, но не к бамбуку.
        if let kin, specimen.preset == kin, title == fold(kin.title) {
            return 4
        }
        return nil
    }

    /// Запрос похож на общий ярлык — «цветы», «травка»: по основам он свёлся
    /// бы к случайной модели.
    private static func general(_ asked: String) -> Bool {
        let words = asked.split { !$0.isLetter }.map(String.init)
        return vague.map { fold(Lang.text($0)) }.contains { name in
            words.contains { word in
                name.hasPrefix(word) || word.hasPrefix(String(name.prefix(4)))
            }
        }
    }
}
