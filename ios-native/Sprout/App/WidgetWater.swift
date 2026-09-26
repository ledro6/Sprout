import AppIntents
import WidgetKit

// Полив из виджета. Файл общий для приложения и виджета: система выполняет
// команду то в одном, то в другом, а сад в обоих случаях — один, в общей
// папке (`Store`). В приложении это тот же `Garden.shared`, что видят
// экраны; в виджете — свой, прочитанный из того же файла.

struct WaterFromWidget: AppIntent {
    static let title: LocalizedStringResource = "Полить из виджета"
    /// В «Командах» не нужна: для голоса есть «Полить растение».
    static let isDiscoverable = false

    @Parameter(title: "Растение")
    var plant: String

    init() {}

    init(plant: String) {
        self.plant = plant
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Сада на диске нет — поливать нечего, и макетный сад не заводим.
        guard let state = Store.read() else { return .result() }
        // Сроки — с поправками приложения: своих настроек у виджета нет.
        Season.stretch = state.season ?? 1
        Climate.settle(state.climate, on: true)
        let garden = Garden.shared
        garden.reload()
        garden.advance()
        _ = garden.water(plant)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
