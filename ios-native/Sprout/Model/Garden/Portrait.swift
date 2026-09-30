import Foundation

/// Портрет растения или хозяина — картинка из системного листа Image
/// Playground. Стиль выбирают в самом листе; отсюда — понятия, с которых он
/// начинает. Файл портрета растения лежит рядом со снимками (`Shots`), в
/// растении — его имя (`Plant.portrait`).
enum Portrait {
    /// Вид — по-английски, если он из знакомых: английский Image Playground
    /// понимает при любом языке приложения. Незнакомый — как вписан. Клички
    /// нет нарочно: «Укроп» или «Батон» нарисовались бы буквально.
    static func concepts(for plant: Plant) -> [String] {
        if let preset = Preset.known(plant.species) { return [english(preset)] }
        let species = plant.species
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [species.isEmpty ? "houseplant" : species]
    }

    /// Хозяину с фото понятия не нужны — портрет идёт по снимку. Без фото —
    /// по имени, и садовод: кружок всё-таки в садовом приложении.
    static func concepts(owner: String, photo: Bool) -> [String] {
        guard !photo else { return [] }
        let name = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? ["gardener"] : [name, "gardener"]
    }

    /// Имя вида — то, по которому его узнают на картинке; где имя модели
    /// значит другое («jade» — камень), — полное.
    static func english(_ preset: Preset) -> String {
        switch preset {
        case .jade: "jade plant"
        case .violet: "african violet"
        case .herbs: "potted herbs"
        case .citrus: "lemon tree"
        case .opuntia: "prickly pear cactus"
        case .palm: "palm tree"
        default: preset.rawValue
        }
    }
}
