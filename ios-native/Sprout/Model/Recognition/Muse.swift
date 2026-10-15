import Foundation
import FoundationModels

/// Языковая модель Apple прямо в телефоне, без сети. Нужен iPhone 15 Pro или
/// новее с Apple Intelligence, говорящей на языке приложения; без неё экран
/// не показывает подсказок вовсе, а не неработающую кнопку.
///
/// Наставления — по-английски: так модель понимает их лучше всего, а
/// отвечать ей велено на языке приложения.
enum Muse {
    /// Что с моделью на этом телефоне. Решение — одно на всё приложение:
    /// вход в ИИ показывают по `offered`, работает ли он — по `ready`.
    enum State: Equatable {
        /// Отвечает.
        case ready
        /// Телефон не тянет Apple Intelligence: входов в ИИ нет вовсе.
        case hidden
        /// Телефон тянет, но выключена в Настройках.
        case needsEnabling
        /// Модель ещё загружается.
        case loading
        /// Модель есть, но не говорит на языке приложения.
        case noLanguage
    }

    /// ИИ-функция — со своим выключателем в Настройках («Apple Intelligence»).
    enum Feature: CaseIterable {
        /// «Спросить сад».
        case ask
        /// Совет словами по снимку растения.
        case advice
        /// Кличка растению.
        case names

        var on: Bool {
            let settings = Settings.shared
            switch self {
            case .ask: return settings.aiAsk
            case .advice: return settings.aiAdvice
            case .names: return settings.aiNames
            }
        }
    }

    /// Почему модель не отвечает — подпись под выключателем; `nil`, если
    /// отвечает.
    static func reason(for state: State) -> String? {
        switch state {
        case .ready:
            return nil
        case .hidden:
            return Lang.text("Этот телефон не поддерживает Apple Intelligence.")
        case .needsEnabling:
            return Lang.text("Apple Intelligence выключена. Включите её в Настройках телефона → «Apple Intelligence и Siri».")
        case .loading:
            return Lang.text("Модель загружается. Попробуйте чуть позже.")
        case .noLanguage:
            return Lang.text("Apple Intelligence не говорит на языке приложения.")
        }
    }

    static var state: State {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Lang.locale) ? .ready : .noLanguage
        case .unavailable(.deviceNotEligible):
            return .hidden
        case .unavailable(.appleIntelligenceNotEnabled):
            return .needsEnabling
        case .unavailable(.modelNotReady):
            return .loading
        case .unavailable:
            return .hidden
        }
    }

    /// Модель готова ответить прямо сейчас и хоть одна функция включена.
    /// Для конкретной функции — `works(_:)`.
    static var ready: Bool {
        Feature.allCases.contains { $0.on } && state == .ready
    }

    /// Модель готова и функция включена.
    static func works(_ feature: Feature) -> Bool {
        feature.on && state == .ready
    }

    /// Показывать ли входы в ИИ: не показываем, если телефон не годится
    /// совсем или все функции выключены в Настройках. Читается из тела
    /// экрана; обновляется при запуске и возвращении в приложение, см. `Offer`.
    @MainActor
    static var offered: Bool {
        Feature.allCases.contains { $0.on } && Offer.shared.state != .hidden
    }

    /// Показывать ли вход в одну функцию.
    @MainActor
    static func shown(_ feature: Feature) -> Bool {
        feature.on && Offer.shared.state != .hidden
    }

    /// Язык ответа по-английски: «Russian», «Japanese». Им же отвечает
    /// «Спросить сад», см. `Talk`.
    static var language: String {
        let code = Lang.locale.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code)
            ?? "English"
    }

    /// Одну кличку, а не список: нажать «ещё раз» проще, чем выбирать из
    /// пяти.
    static func nickname(for species: String) async -> String? {
        guard works(.names) else { return nil }
        let answer = await say("""
        Invent one short, affectionate nickname for a houseplant of the \
        species "\(species)". The nickname must be in \(language), a single \
        word, capitalized if the language has capitals, fit for a pet and \
        must not repeat the species name. Reply with the nickname only, \
        without quotes or explanations.
        """)
        // Модель иногда добавляет точку или кавычки — подчищаем, и
        // японские с китайскими тоже.
        let word = answer?
            .trimmingCharacters(in: CharacterSet(
                charactersIn: " \n\t.,!«»\"'“”‘’「」『』。、！"))
            .split(whereSeparator: \.isWhitespace)
            .first
        guard let word, word.count <= 24 else { return nil }
        return String(word)
    }

    /// Два-три дружеских предложения о том, что делать, — по находкам
    /// диагностики и тому же рассказу о растении, что у «Спросить сад»
    /// (`Sage.context`). Ответ проверяет приложение: полить влажное модель
    /// не посоветует (`Sage.screen`). Нет модели — нет и абзаца: находки
    /// говорят сами.
    static func advise(_ findings: [Finding], plant: Plant, room: String?,
                       log: [Watering]) async -> String? {
        guard works(.advice) else { return nil }
        let answer = await say(Sage.diagnosis(findings, plant: plant,
                                              room: room, log: log,
                                              language: language))
        return answer.map { Sage.screen($0, plant: plant) }
    }

    /// Сеанс на каждый вопрос: общая память сбивала бы ответы. Без
    /// наставления модель отвечает то по-английски, то абзацами с
    /// заголовками.
    private static func say(_ question: String) async -> String? {
        guard ready else { return nil }
        let session = LanguageModelSession {
            """
            You are an assistant in an app for caring for houseplants. \
            Always answer in \(language), briefly and to the point. Do not \
            greet, apologize or explain what you are doing.
            """
        }
        guard let reply = try? await session.respond(to: question) else {
            return nil
        }
        return reply.content
    }
}

/// Состояние модели, за которым следят экраны: считается при запуске и
/// каждый раз, когда приложение снова становится активным (пользователь мог
/// включить Apple Intelligence в Настройках).
@MainActor
@Observable
final class Offer {
    static let shared = Offer()

    private(set) var state = Muse.state

    func refresh() {
        let now = Muse.state
        if now != state { state = now }
    }
}
