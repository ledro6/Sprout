import Foundation

/// Выращивает модель по чертежу. Каждый вид — свой рецепт из общих частей:
/// горшок, земля, стебли, листья-карточки с рисунком, мясистые листья,
/// цветы. Всё детерминировано: один чертёж — одна и та же модель.
enum Botany {
    /// `detail` — чёткость рисунков и густота сеток по силе телефона, см.
    /// `Rig`.
    static func grow(_ blueprint: Blueprint, species: String,
                     detail: Rig.Detail = .standard) -> Kit {
        var grower = Grower(blueprint, species: species, detail: detail)
        switch blueprint.preset {
        case .monstera: grower.monstera()
        case .ficus: grower.ficus()
        case .sansevieria: grower.sansevieria()
        case .zamioculcas: grower.zamioculcas()
        case .spathiphyllum: grower.spathiphyllum()
        case .orchid: grower.orchid()
        case .aloe: grower.aloe()
        case .cactus: grower.cactus()
        case .echeveria: grower.echeveria()
        case .jade: grower.jade()
        case .dracaena: grower.dracaena()
        case .palm: grower.palm()
        case .fern: grower.fern()
        case .ivy: grower.ivy()
        case .chlorophytum: grower.chlorophytum()
        case .violet: grower.violet()
        case .begonia: grower.begonia()
        case .pelargonium: grower.pelargonium()
        case .herbs, .mint, .rosemary: grower.herbs()
        case .tulip: grower.tulip()
        case .rose: grower.rose()
        case .hoya: grower.ivy()
        case .kalanchoe: grower.kalanchoe()
        case .anthurium: grower.anthurium()
        case .calathea: grower.calathea()
        case .pilea: grower.pilea()
        case .alocasia: grower.alocasia()
        case .lily: grower.lily()
        case .sunflower: grower.sunflower()
        case .lavender: grower.lavender()
        case .citrus: grower.citrus()
        case .haworthia: grower.haworthia()
        case .opuntia: grower.opuntia()
        case .yucca: grower.yucca()
        case .chrysanthemum: grower.chrysanthemum()
        }
        grower.kit.measure()
        return grower.kit
    }
}
