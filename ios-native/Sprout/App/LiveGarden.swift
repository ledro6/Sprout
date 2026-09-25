import ActivityKit
import AppIntents
import Foundation

// Живые действия Sprout — «Обход сада» и отсчёт до отъезда — на экране
// блокировки и в Dynamic Island. Файл общий для приложения и виджета: виджет
// рисует их по этим типам, а кнопки в них — команды, которые система
// выполняет в процессе приложения. Само дело знает только приложение (см.
// `Live`), поэтому команды зовут его через крючок; в виджете он пуст.

struct RoundAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stops: [Round.Stop]
    }

    /// С этого мига поливы считаются поливами обхода.
    var started: Date
}

struct TripAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Все политы перед отъездом.
        var watered: Bool
        /// Скольких поливать соседу.
        var neighbour: Int
        /// Когда сосед придёт в первый раз.
        var visit: Date?
    }

    /// Когда включили отсчёт — от него наливается полоска.
    var started: Date
    var leave: Date
    var back: Date
}

/// Что попросили из живого действия.
enum LiveAct: Sendable {
    case water(Plant.ID)
    case skip(Plant.ID)
    case waterAll
}

@MainActor
enum LiveHook {
    /// Ставит приложение при запуске.
    static var act: (@MainActor (LiveAct) async -> Void)?
}

struct WaterInRound: LiveActivityIntent {
    static let title: LocalizedStringResource = "Полить в обходе"
    static let isDiscoverable = false

    @Parameter(title: "Растение")
    var plant: String

    init() {}

    init(plant: String) {
        self.plant = plant
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveHook.act?(.water(plant))
        return .result()
    }
}

struct SkipInRound: LiveActivityIntent {
    static let title: LocalizedStringResource = "Пропустить в обходе"
    static let isDiscoverable = false

    @Parameter(title: "Растение")
    var plant: String

    init() {}

    init(plant: String) {
        self.plant = plant
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveHook.act?(.skip(plant))
        return .result()
    }
}

struct WaterBeforeTrip: LiveActivityIntent {
    static let title: LocalizedStringResource = "Полить всех перед отъездом"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveHook.act?(.waterAll)
        return .result()
    }
}
