import CoreHaptics
import UIKit

/// Отклик в руке и на слух. Выбор, успех и ошибка — системные
/// `UIFeedbackGenerator`, их узнаёт любой. Полив, всходы и кутерьма — рисунки
/// `CoreHaptics`: они длятся и угасают вместе с волной, а системные отклики
/// мгновенные. Сами рисунки — в модели, см. `Pulse`; звуки — см. `Chime`.
/// Выбор и всходы без звука: выбор щёлкает сам, а всходы идут и при запуске.
@MainActor
enum Feel {
    static func water() {
        Engine.shared.play(.water, seconds: Motion.cheerSeconds)
        Chime.pour.play()
    }

    static func planted() {
        Engine.shared.play(.bloom, seconds: 0.55)
        Chime.plant.play()
    }

    static func sprout() {
        Engine.shared.play(.sprout, seconds: Motion.bloomSeconds)
    }

    static func frenzy() {
        Engine.shared.play(.frenzy, seconds: Frolic.seconds)
        Chime.frolic.play()
    }

    /// Удалили — растение или запись из истории.
    static func toss() {
        notify(.warning)
        Chime.toss.play()
    }

    /// Отменили удаление или полив.
    static func back() {
        pick()
        Chime.undo.play()
    }

    /// Выбрали из нескольких — щелчок барабана. Переключателям и системным
    /// меню он не нужен: они отзываются сами.
    static func pick() {
        guard Settings.shared.haptics else { return }
        Engine.selection.selectionChanged()
        // Без подготовки первый щелчок опаздывает на десятые доли секунды.
        Engine.selection.prepare()
    }

    static func done() {
        notify(.success)
        Chime.save.play()
    }

    static func wrong() {
        notify(.error)
        Chime.wrong.play()
    }

    private static func notify(_ kind: UINotificationFeedbackGenerator
        .FeedbackType) {
        guard Settings.shared.haptics else { return }
        Engine.notice.notificationOccurred(kind)
        Engine.notice.prepare()
    }
}

/// Taptic Engine — один на приложение: запуск движка на каждый полив стоил бы
/// дорого. Засыпает он сам, а `start` на ходу ничего не стоит.
@MainActor
private final class Engine {
    static let shared = Engine()

    static let selection = UISelectionFeedbackGenerator()
    static let notice = UINotificationFeedbackGenerator()

    /// На iPad и в симуляторе его нет — отклик просто не играет.
    private let supported = CHHapticEngine.capabilitiesForHardware()
        .supportsHaptics

    private var engine: CHHapticEngine?

    /// Новый отклик обрывает прежний: два наложенных гула читались бы кашей.
    /// Как и новая волна — см. `Cheer.now`.
    private var playing: CHHapticPatternPlayer?

    private init() {}

    func play(_ pulse: Pulse, seconds: Double) {
        guard supported, Settings.shared.haptics else { return }
        do {
            let engine = try alive()
            try? playing?.stop(atTime: CHHapticTimeImmediate)
            let player = try engine.makePlayer(
                with: try pattern(for: pulse, seconds: seconds))
            try player.start(atTime: CHHapticTimeImmediate)
            playing = player
        } catch {
            // Отклик — украшение, падать из-за него нечего: движок соберётся
            // заново.
            engine = nil
            playing = nil
        }
    }

    private func alive() throws -> CHHapticEngine {
        if let engine {
            // Мог уснуть сам, а на спящем проигрывание не начнётся.
            try engine.start()
            return engine
        }
        let made = try CHHapticEngine()
        // Звука нет — так движок не трогает звуковую сессию приложения.
        made.playsHapticsOnly = true
        made.isAutoShutdownEnabled = true
        // Сброшенный системой (например, после звонка) движок надо поднять
        // заново, иначе он замолчит навсегда.
        made.resetHandler = { [weak made] in try? made?.start() }
        try made.start()
        engine = made
        return made
    }

    /// Тычки — мгновенные события. Гул — одно долгое событие в полную силу,
    /// форму которому задаёт кривая `hapticIntensityControl`: событие с
    /// заданной силой угасать не умеет.
    private func pattern(for pulse: Pulse,
                         seconds: Double) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        if pulse.strike > 0 {
            events.append(strike(pulse.strike, pulse.strikeEdge, at: 0))
        }
        for tap in pulse.taps(over: seconds) {
            events.append(strike(tap.strength, tap.edge, at: tap.at))
        }
        if pulse.finish > 0 {
            events.append(strike(pulse.finish, pulse.finishEdge,
                                 at: seconds))
        }

        var curves: [CHHapticParameterCurve] = []
        if pulse.hum > 0 {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity,
                                           value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness,
                                           value: Float(pulse.edge)),
                ],
                relativeTime: 0,
                duration: seconds))
            curves.append(CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: pulse.envelope.map {
                    CHHapticParameterCurve.ControlPoint(
                        relativeTime: $0.at * seconds,
                        value: Float($0.strength * pulse.hum))
                },
                relativeTime: 0))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    private func strike(_ force: Double, _ edge: Double,
                        at moment: Double) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity,
                                       value: Float(force)),
                CHHapticEventParameter(parameterID: .hapticSharpness,
                                       value: Float(edge)),
            ],
            relativeTime: moment)
    }
}
