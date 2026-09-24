import Foundation
import FoundationModels

/// Языковая модель Apple прямо в телефоне, без сети. Нужен iPhone 15 Pro или
/// новее с Apple Intelligence, говорящей на языке приложения; без неё экран
/// не показывает подсказок вовсе, а не неработающую кнопку.
///
/// Наставления — по-английски: так модель понимает их лучше всего, а
/// отвечать ей велено на языке приложения.
enum Muse {
    /// Спрашивается один раз: читают из тела экрана, а ответ за сеанс не
    /// меняется.
    static let ready: Bool = {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale(Lang.locale)
    }()

    /// Язык ответа по-английски: «Russian», «Japanese».
    private static var language: String {
        let code = Lang.locale.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code)
            ?? "English"
    }

    /// Одну кличку, а не список: нажать «ещё раз» проще, чем выбирать из
    /// пяти.
    static func nickname(for species: String) async -> String? {
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
