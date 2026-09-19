import CoreHaptics
import UIKit

/// Отклик в руке.
///
/// Два разных механизма, и это не небрежность. Выбор, успех и ошибка —
/// системные отклики `UIFeedbackGenerator`: их узнаёт любой, кто держал
/// айфон, и придумывать для них своё значило бы говорить на своём языке
/// там, где есть общий. А полив, всходы и кутерьма — рисунки `CoreHaptics`
/// с собственной огибающей: у системных откликов длительности нет вовсе,
/// они мгновенные, а здесь отклик должен идти столько же, сколько идёт
/// волна по экрану, и так же угасать.
///
/// Сами рисунки лежат в модели — см. `Pulse`: там одни числа, и их можно
/// прогнать без телефона. Движок отвергает любое значение вне 0…1, и
/// узнать об этом иначе можно было бы только по молчащей руке.
@MainActor
enum Feel {
    /// Полив: удар и долгий уход — ровно столько, сколько идёт волна.
    static func water() { Engine.shared.play(.water, seconds: Motion.cheerSeconds) }

    /// Посадили растение: из ничего нарастает и лопается хлопком.
    static func planted() { Engine.shared.play(.bloom, seconds: 0.55) }

    /// Затрясли: по бугру на каждый такт кутерьмы.
    static func frenzy() { Engine.shared.play(.frenzy, seconds: Frolic.seconds) }

    /// Выбрали что-то из нескольких — цвет, фигурку, тему, день на
    /// графике. Тот же щелчок, которым система отзывается на прокрутку
    /// барабана выбора.
    ///
    /// Переключателям и системным меню он не нужен: `UISwitch` и меню
    /// отзываются сами, и второй щелчок поверх читался бы заиканием.
    static func pick() {
        guard Settings.shared.haptics else { return }
        Engine.selection.selectionChanged()
        // Готовим движок к следующему разу: без этого первый щелчок
        // приходит с задержкой в десятые доли секунды.
        Engine.selection.prepare()
    }

    /// Получилось — соперник встал в таблицу, сад принят из файла.
    static func done() { notify(.success) }

    /// Не получилось — в скопированном не оказалось кода, файл не тот.
    static func wrong() { notify(.error) }

    private static func notify(_ kind: UINotificationFeedbackGenerator
        .FeedbackType) {
        guard Settings.shared.haptics else { return }
        Engine.notice.notificationOccurred(kind)
        Engine.notice.prepare()
    }
}

/// Сам Taptic Engine и всё, что с ним нужно делать.
///
/// Один на приложение: движок у телефона один, и заводить его на каждый
/// полив значило бы платить за запуск всякий раз. Засыпает он сам —
/// `isAutoShutdownEnabled`, — а просыпается на `start`, который ничего не
/// стоит, если движок уже на ходу.
@MainActor
private final class Engine {
    static let shared = Engine()

    static let selection = UISelectionFeedbackGenerator()
    static let notice = UINotificationFeedbackGenerator()

    /// Есть ли в телефоне Taptic Engine. На iPad и в симуляторе — нет, и
    /// отклик там просто не играет.
    private let supported = CHHapticEngine.capabilitiesForHardware()
        .supportsHaptics

    private var engine: CHHapticEngine?

    /// Что играет прямо сейчас. Нужен, чтобы оборвать его новым откликом:
    /// полить можно чаще, чем отклик успевает угаснуть, и два наложенных
    /// гула читались бы кашей, а не двумя поливами. Та же причина, по
    /// которой новая волна отменяет прежнюю, — см. `Cheer.now`.
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
            // Отклик — украшение, и падать из-за него нечего. Движок
            // роняем: в следующий раз соберётся заново.
            engine = nil
            playing = nil
        }
    }

    private func alive() throws -> CHHapticEngine {
        if let engine {
            // Мог уснуть сам — пробуждение стоит недорого, а на спящем
            // проигрывание не начнётся.
            try engine.start()
            return engine
        }
        let made = try CHHapticEngine()
        // Звука у рисунков нет, и обещать движку обратное незачем: так он
        // не трогает звуковую сессию приложения.
        made.playsHapticsOnly = true
        made.isAutoShutdownEnabled = true
        // Система может сбросить движок — например, после звонка. Тогда
        // его надо поднять заново, иначе он замолчит навсегда.
        made.resetHandler = { [weak made] in try? made?.start() }
        try made.start()
        engine = made
        return made
    }

    /// Рисунок в то, что понимает движок.
    ///
    /// Гул — одно долгое событие в полную силу, а всю форму ему задаёт
    /// кривая `hapticIntensityControl`: так и положено, событие с
    /// заданной силой звучало бы ровно и угасать не умело бы.
    private func pattern(for pulse: Pulse,
                         seconds: Double) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        if pulse.strike > 0 {
            events.append(strike(pulse.strike, pulse.strikeEdge, at: 0))
        }
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
        if pulse.finish > 0 {
            events.append(strike(pulse.finish, pulse.finishEdge,
                                 at: seconds))
        }

        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: pulse.envelope.map {
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: $0.at * seconds, value: Float($0.strength))
            },
            relativeTime: 0)
        return try CHHapticPattern(events: events, parameterCurves: [curve])
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
