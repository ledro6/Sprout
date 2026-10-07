import Foundation

/// Состояние земли одним словом — одна правда на всё приложение: карточки,
/// карточка дня, обход, Siri, напоминания, виджет, часы, «Спросить сад»,
/// статистика и планетарий берут статус и сроки отсюда, а не считают
/// по-своему. Файл без типов сада — его собирают и часы, у которых сада нет;
/// растение и сад — в `Status+Plant.swift`.
///
/// Пороги по влажности 0…1:
/// - `wet` — от 60 % («влажно — не поливать»); у вида порог может быть свой,
///   см. `Preset.wetFrom`;
/// - `ok` — 40–59 %;
/// - `soon` — 20–39 %;
/// - `urgent` — меньше 20 %;
/// - `unknown` — числа нет вовсе. У растения в саду влажность есть всегда:
///   и у нового — её задаёт вопрос «Последний полив» при посадке, см.
///   `Start`. «Проверьте землю» — для того, чего не знает никто: ответ «не
///   помню» на этот вопрос, пока хозяин не потрогал землю.
enum MoistureStatus: String, Codable, CaseIterable, Sendable {
    case wet, ok, soon, urgent, unknown

    /// Ниже — «скоро пить»: тень на карточке оранжевеет.
    static let soonBelow = 0.4
    /// Ниже — «сухо, полить сегодня»: тень краснеет.
    static let urgentBelow = 0.2
    /// От этого — «влажно, не поливать», если у вида нет своего порога.
    static let wetFrom = 0.6

    init(moisture: Double?, wetFrom: Double? = nil) {
        guard let moisture, moisture.isFinite else {
            self = .unknown
            return
        }
        switch moisture {
        case ..<Self.urgentBelow: self = .urgent
        case ..<Self.soonBelow: self = .soon
        case ..<(wetFrom ?? Self.wetFrom): self = .ok
        default: self = .wet
        }
    }

    // MARK: - Сроки

    /// Дней до полива — из влажности и срока высыхания: столько осталось
    /// сохнуть до сухой земли.
    static func days(moisture: Double, period: Double) -> Int {
        max(0, Int((moisture * period).rounded()))
    }

    /// Полить сегодня: сухо (`urgent`) — или срок уже вышел. Второе бывает у
    /// растений с коротким сроком: у двухдневного 24 % — это ноль дней.
    /// Этим набором живут «Ждут воды» на карточке дня, обход, Siri,
    /// напоминания, виджет и часы — см. `MoistureStatus.needsWater`.
    static func due(moisture: Double, period: Double) -> Bool {
        MoistureStatus(moisture: moisture) == .urgent
            || days(moisture: moisture, period: period) == 0
    }

    /// Подпись срока: «Полить сегодня», «Скоро: завтра», «Полив через 5
    /// дней». Влажность посчитана, а не измерена, — «примерно». Сухому —
    /// всегда «сегодня», никогда не «завтра».
    static func nextWatering(moisture: Double, period: Double,
                             estimated: Bool) -> String {
        if due(moisture: moisture, period: period) {
            return Lang.text("Полить сегодня")
        }
        let days = Self.days(moisture: moisture, period: period)
        if MoistureStatus(moisture: moisture) == .soon {
            if days == 1 {
                return estimated ? Lang.text("Скоро: примерно завтра")
                    : Lang.text("Скоро: завтра")
            }
            return estimated
                ? Lang.format("Скоро: примерно через %lld дней", days)
                : Lang.format("Скоро: через %lld дней", days)
        }
        return estimated ? Lang.format("Полив примерно через %lld дней", days)
            : Lang.format("Полив через %lld дней", days)
    }

    // MARK: - Защита от перелива

    /// Поливать ли: земля ещё влажная — переспросить. Пока только считает;
    /// спрашивать будут кнопки полива.
    enum Guard: Equatable, Sendable {
        case allow
        /// Влажность, при которой спросили, 0…1.
        case warn(Double)
    }

    static func wateringGuard(moisture: Double,
                              wetFrom: Double? = nil) -> Guard {
        MoistureStatus(moisture: moisture, wetFrom: wetFrom) == .wet
            ? .warn(moisture) : .allow
    }

    // MARK: - Как показать

    /// Цвет статуса — именем токена, а не цветом: модель без SwiftUI, а
    /// значения токенов живут в `Palette` (и у виджета, и у часов — свои).
    enum Tone: Sendable {
        case water, green, warn, alarm, secondary
    }

    var tone: Tone {
        switch self {
        case .wet: .water
        case .ok: .green
        case .soon: .warn
        case .urgent: .alarm
        case .unknown: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .wet: "drop.fill"
        case .ok: "checkmark.circle.fill"
        case .soon: "clock.fill"
        case .urgent: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var word: String {
        switch self {
        case .wet: Lang.text("Влажно — не поливать")
        case .ok: Lang.text("Норма")
        case .soon: Lang.text("Скоро пить")
        case .urgent: Lang.text("Сухо — полить сегодня")
        case .unknown: Lang.text("Проверьте землю")
        }
    }

    /// Процент на экране: измерен датчиком — как есть, посчитан — со знаком
    /// «≈». Число то же, что у статуса: округлённое к пяти разошлось бы с
    /// порогами («≈40 %» и «скоро пить»).
    static func percent(_ moisture: Double, estimated: Bool) -> String {
        let whole = Int((moisture * 100).rounded())
        return estimated ? Lang.format("≈%lld%%", whole)
            : Lang.format("%lld%%", whole)
    }

    /// Откуда число: «Датчик» или «Расчёт».
    static func source(estimated: Bool) -> String {
        estimated ? Lang.text("Расчёт") : Lang.text("Датчик")
    }
}
