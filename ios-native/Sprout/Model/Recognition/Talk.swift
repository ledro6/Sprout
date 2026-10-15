import Foundation
import FoundationModels
import Observation

/// Разговор «Спросить сад»: вопросы хозяина и ответы языковой модели Apple
/// прямо на телефоне, без сети, потоком — слово за словом. Память — на лист:
/// закрыли его или начали новый разговор — модель забыла. О саде она узнаёт
/// сама, инструментами, когда вопрос того требует (`GardenTool`,
/// `PlantTool`); тексты для них собирает `Sage`.
@MainActor
@Observable
final class Talk {
    /// Реплика: вопрос хозяина или ответ модели — пустой, пока не пошли
    /// слова.
    struct Line: Identifiable, Equatable {
        let id = UUID()
        let asked: Bool
        var text: String
    }

    /// Что помешало ответить.
    enum Trouble: Equatable {
        /// Окно модели кончилось — поможет только новый разговор.
        case long
        /// Модель на такое не отвечает.
        case refused
        /// Модель смолчала.
        case empty
        case failed

        init(_ error: any Error) {
            guard let failure = error as? LanguageModelSession.GenerationError
            else {
                self = .failed
                return
            }
            switch failure {
            case .exceededContextWindowSize: self = .long
            case .guardrailViolation, .refusal: self = .refused
            default: self = .failed
            }
        }

        var text: String {
            switch self {
            case .long:
                Lang.text("Разговор получился длинным — начните новый.")
            case .refused:
                Lang.text("На такой вопрос модель не отвечает — спросите иначе.")
            case .empty:
                Lang.text("Модель ничего не ответила — спросите иначе.")
            case .failed:
                Lang.text("Не получилось.")
            }
        }
    }

    private(set) var lines: [Line] = []

    /// Идёт ответ — следующий вопрос ждёт: сеанс отвечает по одному.
    private(set) var busy = false

    private(set) var trouble: Trouble?

    /// О ком разговор, если лист открыли с экрана растения.
    let focus: Plant.ID?

    /// Сеанс — с первым вопросом, а не с листом: лист собирается заново на
    /// каждом такте сада, и сеанс на каждый такт был бы лишним.
    @ObservationIgnored private var session: LanguageModelSession?

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Номер вопроса: ответ на прежний, если его не успели остановить, в
    /// новый разговор не ложится.
    @ObservationIgnored private var turn = 0

    /// О ком последний вопрос: ответ о нём проверяется — полить влажное
    /// модель не посоветует (`Sage.screen`).
    @ObservationIgnored private var subject: Plant?

    init(focus: Plant.ID? = nil) {
        self.focus = focus
    }

    func ask(_ text: String) {
        guard !busy, let question = Sage.question(text) else { return }
        turn += 1
        let mine = turn
        let session = self.session ?? begin()
        subject = Sage.subject(question, in: Garden.shared.rooms, focus: focus)
        trouble = nil
        lines.append(Line(asked: true, text: question))
        lines.append(Line(asked: false, text: ""))
        busy = true
        task = Task { await answer(question, in: session, turn: mine) }
    }

    /// «Попробовать ещё раз»: последний вопрос — заново, без прежней
    /// попытки на экране.
    func retry() {
        guard !busy, let index = lines.lastIndex(where: \.asked) else { return }
        let question = lines[index].text
        lines.removeSubrange(index...)
        trouble = nil
        ask(question)
    }

    /// «Новый разговор»: сеанс заново — модель забывает прежние вопросы.
    func reset() {
        stop()
        session = nil
        lines = []
        trouble = nil
    }

    /// Лист закрыли — ответ дальше не нужен; начатый пустым — долой.
    func stop() {
        turn += 1
        task?.cancel()
        task = nil
        busy = false
        if let last = lines.last, !last.asked, last.text.isEmpty {
            lines.removeLast()
        }
    }

    /// Наставление знает, с какого растения открыт лист: вопрос «а его
    /// когда полить?» — о нём, и знает о нём то же, что «Что с ним?».
    private func begin() -> LanguageModelSession {
        let garden = Garden.shared
        let plant = focus.flatMap { garden.plant(id: $0) }
        let made = LanguageModelSession(
            tools: [GardenTool(), PlantTool(focus: focus)],
            instructions: Sage.instructions(language: Muse.language,
                                            focus: plant, rooms: garden.rooms,
                                            log: garden.log))
        session = made
        return made
    }

    /// Каждый кусок потока — ответ целиком на эту минуту, а не прибавка.
    private func answer(_ question: String, in session: LanguageModelSession,
                        turn mine: Int) async {
        do {
            for try await snapshot in session.streamResponse(to: question) {
                guard mine == turn else { return }
                if let last = lines.indices.last {
                    lines[last].text = Sage.screen(snapshot.content,
                                                   plant: subject)
                }
            }
        } catch {
            guard mine == turn else { return }
            trouble = Trouble(error)
        }
        guard mine == turn else { return }
        busy = false
        // Модель смолчала — пустой строки не оставляем, говорит плашка.
        if let last = lines.last, !last.asked,
           last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeLast()
            if trouble == nil { trouble = .empty }
        }
    }
}

/// Весь сад коротко — инструмент модели: она зовёт его сама, когда вопрос
/// о саде. Сад читается на главной очереди, как у Siri.
struct GardenTool: Tool {
    let name = "gardenOverview"

    let description = """
        Lists the rooms and plants of the user's garden with soil moisture \
        and days until watering, and who needs water today or tomorrow.
        """

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { Sage.overview(Garden.shared.rooms) }
    }
}

/// Одно растение по кличке — инструмент модели.
struct PlantTool: Tool {
    let name = "plantDetails"

    let description = """
        Tells about one plant of the user's garden by its nickname: species, \
        room, soil moisture, last and next watering, care, soil sensor, \
        safety for pets and the owner's note.
        """

    /// Растение, с которого открыли лист: среди тёзок — оно.
    let focus: Plant.ID?

    @Generable
    struct Arguments {
        @Guide(description: "The plant's nickname as the user wrote it")
        var nickname: String
    }

    func call(arguments: Arguments) async throws -> String {
        let nickname = arguments.nickname
        let focus = self.focus
        return await MainActor.run {
            let garden = Garden.shared
            return Sage.details(nickname, in: garden.rooms, log: garden.log,
                                focus: focus)
        }
    }
}
