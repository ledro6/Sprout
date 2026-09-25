import Foundation

/// Виды, которые телефон умеет выращивать в объёме, — готовые модели лежат
/// в приложении (см. `Stock`). Любой вид сада сводится к ближайшему из них;
/// модель под своё растение — по кнопке, по снимку или сканом.
enum Preset: String, Codable, CaseIterable, Sendable {
    case monstera, ficus, sansevieria, zamioculcas, spathiphyllum, orchid,
         aloe, cactus, echeveria, jade, dracaena, palm, fern, ivy,
         chlorophytum, violet, begonia, pelargonium, herbs, tulip,
         rose, hoya, mint, rosemary, kalanchoe, anthurium, calathea, pilea,
         alocasia, lily, sunflower, lavender, citrus, haworthia, opuntia,
         yucca, chrysanthemum

    var title: String {
        switch self {
        case .monstera: Lang.text("Монстера")
        case .ficus: Lang.text("Фикус")
        case .sansevieria: Lang.text("Сансевиерия")
        case .zamioculcas: Lang.text("Замиокулькас")
        case .spathiphyllum: Lang.text("Спатифиллум")
        case .orchid: Lang.text("Орхидея")
        case .aloe: Lang.text("Алоэ")
        case .cactus: Lang.text("Кактус")
        case .echeveria: Lang.text("Эхеверия")
        case .jade: Lang.text("Толстянка")
        case .dracaena: Lang.text("Драцена")
        case .palm: Lang.text("Пальма")
        case .fern: Lang.text("Папоротник")
        case .ivy: Lang.text("Плющ")
        case .chlorophytum: Lang.text("Хлорофитум")
        case .violet: Lang.text("Фиалка")
        case .begonia: Lang.text("Бегония")
        case .pelargonium: Lang.text("Пеларгония")
        case .herbs: Lang.text("Пряные травы")
        case .tulip: Lang.text("Тюльпан")
        case .rose: Lang.text("Роза")
        case .hoya: Lang.text("Хойя")
        case .mint: Lang.text("Мята")
        case .rosemary: Lang.text("Розмарин")
        case .kalanchoe: Lang.text("Каланхоэ")
        case .anthurium: Lang.text("Антуриум")
        case .calathea: Lang.text("Калатея")
        case .pilea: Lang.text("Пилея")
        case .alocasia: Lang.text("Алоказия")
        case .lily: Lang.text("Лилия")
        case .sunflower: Lang.text("Подсолнух")
        case .lavender: Lang.text("Лаванда")
        case .citrus: Lang.text("Лимонное дерево")
        case .haworthia: Lang.text("Хавортия")
        case .opuntia: Lang.text("Опунция")
        case .yucca: Lang.text("Юкка")
        case .chrysanthemum: Lang.text("Хризантема")
        }
    }

    /// По вписанному виду. Частное — раньше общего: «каменная роза» —
    /// суккулент, а не роза. Сперва основы из таблицы, потом названия на
    /// языке телефона: «サボテン» — тоже кактус.
    static func of(_ species: String) -> Preset {
        known(species) ?? .spathiphyllum
    }

    /// Вид узнан по названию; нет — название ничего не говорит, и модель
    /// лучше подобрать по снимку.
    static func known(_ species: String) -> Preset? {
        let name = species.lowercased()
        return stem(name) ?? named.first { name.contains($0.stem) }?.preset
    }

    private static func stem(_ name: String) -> Preset? {
        table.first { name.contains($0.stem) }?.preset
    }

    /// Названия самих моделей и видов из `Species` — в переводе. Длинные
    /// раньше коротких: «Rosemary» — травы, хоть в нём и есть «Rose».
    /// Однобуквенные не берём: иероглиф нашёлся бы в любом слове.
    private static let named: [(stem: String, preset: Preset)] =
        (allCases.map { ($0.title.lowercased(), $0) }
         + Species.table.compactMap { row in
             stem(row.species.lowercased()).map {
                 (Lang.text(row.species).lowercased(), $0)
             }
         })
        .filter { $0.stem.count > 1 }
        .sorted { $0.stem.count > $1.stem.count }

    private static let table: [(stem: String, preset: Preset)] = [
        ("монстер", .monstera), ("филодендрон", .monstera),
        ("фикус", .ficus), ("каучук", .ficus), ("деревце", .ficus),
        ("сансевиер", .sansevieria), ("щучий", .sansevieria),
        ("замиокулькас", .zamioculcas), ("долларов", .zamioculcas),
        ("спатифил", .spathiphyllum), ("диффенбах", .spathiphyllum),
        ("антуриум", .anthurium), ("аглаонем", .spathiphyllum),
        ("орхиде", .orchid), ("фаленопсис", .orchid),
        ("алоказ", .alocasia), ("колоказ", .alocasia),
        ("алоэ", .aloe), ("хавортия", .haworthia), ("гастери", .haworthia),
        ("агав", .aloe),
        ("кактус", .cactus), ("опунци", .opuntia), ("маммиллярия", .cactus),
        ("эхевери", .echeveria), ("суккулент", .echeveria),
        ("молодил", .echeveria), ("каменная роза", .echeveria),
        ("толстянк", .jade), ("крассул", .jade), ("денежное", .jade),
        ("каланхоэ", .kalanchoe),
        ("драцен", .dracaena), ("юкк", .yucca), ("нолин", .yucca),
        ("кордилин", .dracaena),
        ("пальм", .palm), ("хамедоре", .palm), ("бамбук", .palm),
        ("папорот", .fern), ("нефролепис", .fern), ("мох", .fern),
        ("хойя", .hoya), ("плющ", .ivy), ("сциндапсус", .ivy),
        ("эпипремнум", .ivy), ("традесканц", .ivy),
        ("калате", .calathea), ("марант", .calathea), ("ктенант", .calathea),
        ("стромант", .calathea),
        ("пиле", .pilea), ("пеперомия", .pilea),
        ("пряност", .herbs), ("пряные", .herbs),
        ("хлорофит", .chlorophytum), ("трав", .chlorophytum),
        ("фиалк", .violet), ("сенполи", .violet),
        ("бегони", .begonia),
        ("пеларгони", .pelargonium), ("герань", .pelargonium),
        ("розмарин", .rosemary),
        ("роз", .rose), ("хризантем", .chrysanthemum),
        ("ромашк", .chrysanthemum), ("гербер", .chrysanthemum),
        ("лаванд", .lavender),
        ("лимон", .citrus), ("мандарин", .citrus), ("апельсин", .citrus),
        ("цитрус", .citrus), ("каламондин", .citrus),
        ("цвет", .pelargonium),
        ("базилик", .herbs), ("мят", .mint),
        ("зелень", .herbs), ("петрушк", .herbs), ("укроп", .herbs),
        ("кустик", .herbs), ("росток", .herbs),
        ("тюльпан", .tulip), ("лили", .lily), ("нарцисс", .tulip),
        ("гиацинт", .tulip), ("крокус", .tulip), ("подсолнух", .sunflower),
        // Латинские родовые имена — их пишут почти на любом языке — и
        // английские названия.
        ("monst", .monstera), ("philodendron", .monstera),
        ("ficus", .ficus), ("rubber", .ficus),
        ("sansevier", .sansevieria), ("trifasciata", .sansevieria),
        ("snake plant", .sansevieria),
        ("zamioculcas", .zamioculcas), ("zz plant", .zamioculcas),
        ("spathiphyll", .spathiphyllum), ("peace lily", .spathiphyllum),
        ("dieffenbach", .spathiphyllum), ("anthurium", .anthurium),
        ("aglaonema", .spathiphyllum),
        ("orchid", .orchid), ("phalaenopsis", .orchid),
        ("alocasia", .alocasia), ("colocasia", .alocasia),
        ("elephant ear", .alocasia),
        ("aloe", .aloe), ("haworth", .haworthia), ("gasteria", .haworthia),
        ("agave", .aloe),
        ("opuntia", .opuntia), ("prickly pear", .opuntia),
        ("cact", .cactus), ("kakt", .cactus), ("mammillaria", .cactus),
        ("echeveria", .echeveria), ("sempervivum", .echeveria),
        ("succulent", .echeveria),
        ("crassula", .jade), ("jade", .jade), ("kalancho", .kalanchoe),
        ("dracaena", .dracaena), ("yucca", .yucca), ("nolina", .yucca),
        ("cordyline", .dracaena),
        ("chamaedorea", .palm), ("palm", .palm), ("bamboo", .palm),
        ("nephrolepis", .fern), ("fern", .fern), ("moss", .fern),
        ("hoya", .hoya), ("hedera", .ivy), ("ivy", .ivy),
        ("scindapsus", .ivy), ("epipremnum", .ivy), ("pothos", .ivy),
        ("tradescantia", .ivy),
        ("calathea", .calathea), ("maranta", .calathea),
        ("ctenanthe", .calathea), ("prayer plant", .calathea),
        ("pilea", .pilea), ("peperomia", .pilea),
        ("chlorophytum", .chlorophytum), ("spider plant", .chlorophytum),
        ("saintpaulia", .violet), ("violet", .violet),
        ("begonia", .begonia),
        ("pelargonium", .pelargonium), ("geranium", .pelargonium),
        ("rosmarinus", .rosemary), ("rosemary", .rosemary),
        ("sunflower", .sunflower), ("helianthus", .sunflower),
        ("chrysanthem", .chrysanthemum), ("daisy", .chrysanthemum),
        ("gerbera", .chrysanthemum),
        ("lavand", .lavender), ("lavender", .lavender),
        ("citrus", .citrus), ("lemon", .citrus), ("mandarin", .citrus),
        ("calamondin", .citrus),
        ("rose", .rose),
        ("flower", .pelargonium),
        ("basil", .herbs), ("mint", .mint), ("mentha", .mint),
        ("parsley", .herbs), ("dill", .herbs), ("herb", .herbs),
        ("tulip", .tulip), ("lily", .lily), ("lilium", .lily),
        ("narcissus", .tulip), ("daffodil", .tulip), ("hyacinth", .tulip),
        ("crocus", .tulip),
    ]
}

extension Plant {
    /// Свой чертёж — снятый при посадке; нет — готовая модель вида.
    var blueprint: Blueprint { plan ?? .stock(species) }
}
