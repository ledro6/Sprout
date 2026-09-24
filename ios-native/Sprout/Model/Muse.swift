import Foundation
import FoundationModels

/// Языковая модель Apple прямо в телефоне, без сети. Нужен iPhone 15 Pro или
/// новее с Apple Intelligence; без неё экран не показывает подсказок вовсе, а
/// не неработающую кнопку.
enum Muse {
    /// Спрашивается один раз: читают из тела экрана, а ответ за сеанс не
    /// меняется.
    static let ready: Bool = {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }()

    /// Одну кличку, а не список: нажать «ещё раз» проще, чем выбирать из
    /// пяти.
    static func nickname(for species: String) async -> String? {
        let answer = await say("""
        Придумай одну короткую ласковую кличку для комнатного растения \
        вида «\(species)». Кличка должна быть по-русски, одним словом, с \
        большой буквы, годиться домашнему любимцу и не повторять название \
        вида. Ответь только кличкой, без кавычек и без пояснений.
        """)
        // Модель иногда добавляет точку или кавычки — подчищаем.
        let word = answer?
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t.,«»\"'"))
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
            Ты помощник в приложении для ухода за комнатными растениями. \
            Отвечай только по-русски, коротко и по делу. Не здоровайся, \
            не извиняйся и не объясняй, что ты делаешь.
            """
        }
        guard let reply = try? await session.respond(to: question) else {
            return nil
        }
        return reply.content
    }
}
