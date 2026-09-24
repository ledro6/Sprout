import CoreHaptics
import UIKit

/// Отклик в руке и на слух. Весь отклик — рисунки `CoreHaptics`, даже щелчок
/// выбора: системные `UIFeedbackGenerator` не слушают ползунок силы. Рисунки
/// — в модели, см. `Pulse`, `Rain` и `Knock`; звуки — см. `Chime`. Выбор и
/// всходы без звука: выбор щёлкает сам, а всходы идут и при запуске.
@MainActor
enum Feel {
    /// Капли каждый раз новые — зерно случайное.
    static func water() {
        Engine.shared.play(Rain.drops(over: Motion.cheerSeconds,
                                      seed: .random(in: .min ... .max)),
                           long: true)
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
        Engine.shared.play(Knock.toss)
        Chime.toss.play()
    }

    /// Отменили удаление или полив.
    static func back() {
        Engine.shared.play(Knock.back)
        Chime.undo.play()
    }

    /// Выбрали из нескольких — щелчок барабана. Переключателям и системным
    /// меню он не нужен: они отзываются сами.
    static func pick() {
        Engine.shared.play(Knock.pick)
    }

    static func done() {
        Engine.shared.play(Knock.done)
        Chime.save.play()
    }

    static func wrong() {
        Engine.shared.play(Knock.wrong)
        Chime.wrong.play()
    }

    /// Проба силы с ползунка — без звука: пробуют руку.
    static func sample() {
        Engine.shared.play(Knock.done)
    }
}

/// Taptic Engine — один на приложение: запуск движка на каждый полив стоил бы
/// дорого. Засыпает он сам, а `start` на ходу ничего не стоит.
@MainActor
private final class Engine {
    static let shared = Engine()

    /// На iPad и в симуляторе его нет — отклик просто не играет.
    private let supported = CHHapticEngine.capabilitiesForHardware()
        .supportsHaptics

    private var engine: CHHapticEngine?

    /// Новый долгий отклик обрывает прежний: две волны капель читались бы
    /// кашей. Как и новая волна — см. `Cheer.now`. Короткие поверх долгих не
    /// мешают и его не обрывают.
    private var playing: CHHapticPatternPlayer?

    private init() {}

    private var strength: Double { Settings.shared.hapticStrength }

    func play(_ pulse: Pulse, seconds: Double) {
        var taps = pulse.taps(over: seconds)
        if pulse.strike > 0 {
            taps.insert(Tap(at: 0, strength: pulse.strike,
                            edge: pulse.strikeEdge), at: 0)
        }
        if pulse.finish > 0 {
            taps.append(Tap(at: seconds, strength: pulse.finish,
                            edge: pulse.finishEdge))
        }
        play(taps, long: true,
             hum: pulse.hum > 0 ? (pulse: pulse, seconds: seconds) : nil)
    }

    func play(_ taps: [Tap], long: Bool = false,
              hum: (pulse: Pulse, seconds: Double)? = nil) {
        guard supported, strength > 0, !taps.isEmpty else { return }
        do {
            let engine = try alive()
            let player = try engine.makePlayer(with: try pattern(taps, hum: hum))
            if long { try? playing?.stop(atTime: CHHapticTimeImmediate) }
            try player.start(atTime: CHHapticTimeImmediate)
            if long { playing = player }
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
    private func pattern(_ taps: [Tap],
                         hum: (pulse: Pulse, seconds: Double)?) throws
        -> CHHapticPattern {
        var events: [CHHapticEvent] = taps.map { tap in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: Float(Pulse.scaled(tap.strength,
                                                  by: strength))),
                    CHHapticEventParameter(parameterID: .hapticSharpness,
                                           value: Float(tap.edge)),
                ],
                relativeTime: tap.at)
        }
        var curves: [CHHapticParameterCurve] = []
        if let hum {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity,
                                           value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness,
                                           value: Float(hum.pulse.edge)),
                ],
                relativeTime: 0,
                duration: hum.seconds))
            curves.append(CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: hum.pulse.envelope.map {
                    CHHapticParameterCurve.ControlPoint(
                        relativeTime: $0.at * hum.seconds,
                        value: Float(Pulse.scaled(
                            $0.strength * hum.pulse.hum, by: strength)))
                },
                relativeTime: 0))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }
}
