import Foundation

/// Опасно ли растение для кошек и собак. Сведения — из базы ASPCA
/// (Американское общество защиты животных): её ведёт их токсикологический
/// центр, по ней сверяются ветеринары.
///
/// Вид в саду — свободный текст. Сперва ищем названия, которые ведут себя
/// не так, как их модель: «бамбук» в горшке — это драцена, а нолина хоть и
/// похожа на юкку, безопасна. Потом — вид модели. Общие слова («цветок»,
/// «зелень», «суккулент») ничего не говорят, и тогда молчим: лучше не
/// сказать ничего, чем успокоить зря.
enum Toxicity: Sendable {
    /// Ни кошкам, ни собакам.
    case safe
    /// И кошкам, и собакам: рвота, слюна, жжение во рту.
    case toxic
    /// Настоящие лилии и лилейники: у кошки отказывают почки даже от
    /// пыльцы, собаке — расстройство, не больше.
    case lily
    /// Смертельно и тем, и другим: саговник, олеандр.
    case deadly

    static func of(_ species: String) -> Toxicity? {
        let name = species.lowercased()
        if let row = exceptions.first(where: { name.contains($0.stem) }) {
            return row.toxicity
        }
        // Общие слова вычёркиваем, а не останавливаемся на них: в
        // «цветущем кактусе» вид всё-таки есть.
        let plain = vague.reduce(name) { $0.replacingOccurrences(of: $1, with: " ") }
        return Preset.known(plain)?.toxicity
    }

    /// Строка на экран — что и для кого.
    var line: String {
        switch self {
        case .safe: Lang.text("Безопасно для кошек и собак")
        case .toxic: Lang.text("Ядовито для кошек и собак")
        case .lily: Lang.text("Смертельно опасно для кошек")
        case .deadly: Lang.text("Смертельно опасно для кошек и собак")
        }
    }

    var harmful: Bool { self != .safe }

    /// Раньше общих — те, что ведут себя не как их модель. Порядок важен:
    /// «калла» и «лилия мира» — не лилии, а «кошачья трава» — трава.
    private static let exceptions: [(stem: String, toxicity: Toxicity)] = [
        ("саго", .deadly), ("цикас", .deadly), ("sago", .deadly),
        ("cycas", .deadly),
        ("олеандр", .deadly), ("oleander", .deadly), ("nerium", .deadly),
        ("peace lily", .toxic), ("калл", .toxic), ("calla", .toxic),
        ("zantedeschia", .toxic),
        ("ландыш", .toxic), ("lily of the valley", .toxic),
        ("convallaria", .toxic),
        ("лилейник", .lily), ("daylily", .lily), ("hemerocallis", .lily),
        // Похожи по имени на безопасные — и наоборот.
        ("роза пустыни", .toxic), ("адениум", .toxic), ("adenium", .toxic),
        ("desert rose", .toxic),
        ("альпийская фиалка", .toxic), ("цикламен", .toxic),
        ("cyclamen", .toxic),
        ("восков", .safe), ("wax plant", .safe),
        ("пахир", .safe), ("pachira", .safe), ("money tree", .safe),
        ("декабрист", .safe), ("шлюмбергер", .safe),
        ("schlumbergera", .safe), ("christmas cactus", .safe),
        ("бамбук", .toxic), ("bamboo", .toxic),
        ("нолин", .safe), ("nolina", .safe), ("бокарне", .safe),
        ("beaucarnea", .safe), ("ponytail", .safe),
        ("гербер", .safe), ("gerbera", .safe),
        ("ромашк", .toxic), ("chamomile", .toxic),
        ("аспарагус", .toxic), ("asparagus", .toxic),
        ("амариллис", .toxic), ("гиппеаструм", .toxic),
        ("amaryllis", .toxic), ("hippeastrum", .toxic),
        ("азали", .toxic), ("рододендрон", .toxic), ("azalea", .toxic),
        ("rhododendron", .toxic),
        ("пуансетти", .toxic), ("молочай", .toxic), ("poinsettia", .toxic),
        ("euphorbia", .toxic),
        ("кротон", .toxic), ("croton", .toxic), ("codiaeum", .toxic),
        ("шеффлер", .toxic), ("schefflera", .toxic),
        ("сингониум", .toxic), ("syngonium", .toxic),
        ("фиттони", .safe), ("fittonia", .safe),
        ("бромели", .safe), ("гузмани", .safe), ("bromelia", .safe),
        ("guzmania", .safe),
        ("кошачья трава", .safe), ("cat grass", .safe),
        ("базилик", .safe), ("basil", .safe),
        ("укроп", .safe), ("dill", .safe),
        ("тимьян", .safe), ("чабрец", .safe), ("thyme", .safe),
        ("петрушк", .toxic), ("parsley", .toxic),
        ("шнитт", .toxic), ("chive", .toxic), ("allium", .toxic),
        ("орегано", .toxic), ("душиц", .toxic), ("oregano", .toxic),
    ]

    /// Слова, по которым не узнать растение.
    private static let vague = [
        "цвет", "flower", "зелень", "пряност", "пряные", "herb", "кустик",
        "росток", "трав", "деревце", "суккулент", "succulent",
    ]
}

extension Preset {
    /// Пряные травы бывают всякие: базилик безопасен, лук и орегано — нет.
    var toxicity: Toxicity? {
        switch self {
        case .orchid, .cactus, .echeveria, .palm, .fern, .chlorophytum,
             .violet, .rose, .hoya, .rosemary, .calathea, .pilea,
             .sunflower, .haworthia, .opuntia:
            .safe
        case .monstera, .ficus, .sansevieria, .zamioculcas, .spathiphyllum,
             .aloe, .jade, .dracaena, .ivy, .begonia, .pelargonium, .tulip,
             .mint, .kalanchoe, .anthurium, .alocasia, .lavender, .citrus,
             .yucca, .chrysanthemum:
            .toxic
        case .lily: .lily
        case .herbs: nil
        }
    }
}
