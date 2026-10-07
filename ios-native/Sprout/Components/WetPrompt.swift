import SwiftUI

/// «Земля ещё влажная» — один вопрос на все входы полива в приложении:
/// капля на карточке, «Полить сейчас», планетарий, AR, метка на горшке.
/// Решает модель (`Garden.wetCheck`); здесь только лист и то, что делать
/// после ответа. Без «Всё равно полить» полив не записывается.
@MainActor
@Observable
final class Overflow {
    /// Вопрос для корня приложения. Полноэкранный AR держит свой: поверх
    /// обложки корень лист не покажет.
    static let shared = Overflow()

    struct Question: Identifiable {
        let id: Plant.ID
        let moisture: Double
        let estimated: Bool
        /// «Всё равно полить».
        let go: @MainActor () -> Void

        /// «Земля ещё влажная (≈72%)».
        var title: String {
            Lang.format("Земля ещё влажная (%@)",
                        MoistureStatus.percent(moisture, estimated: estimated))
        }
    }

    var question: Question?

    /// Полить — или сначала спросить. Отклик (`then`) — у того, кто
    /// поливал: откуда пускать волну, знает он; зовётся, только если
    /// полилось.
    func water(_ id: Plant.ID, in garden: Garden,
               then: @escaping @MainActor () -> Void) {
        guard garden.wetCheck(id) != nil else {
            if Bin.shared.water(id, in: garden) { then() }
            return
        }
        ask(id, in: garden) {
            if Bin.shared.water(id, in: garden, anyway: true) { then() }
        }
    }

    /// Спросить про влажную землю; `go` — на «Всё равно полить».
    func ask(_ id: Plant.ID, in garden: Garden,
             go: @escaping @MainActor () -> Void) {
        guard let moisture = garden.wetCheck(id),
              let plant = garden.plant(id: id) else { return }
        question = Question(id: id, moisture: moisture,
                            estimated: plant.estimated, go: go)
    }
}

/// Лист вопроса: «Всё равно полить» и «Отмена».
struct WetPrompt: ViewModifier {
    let ask: Overflow

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text(ask.question?.title ?? ""),
                isPresented: Binding(get: { ask.question != nil },
                                     set: { if !$0 { ask.question = nil } }),
                titleVisibility: .visible,
                presenting: ask.question) { question in
                Button("Всё равно полить") { question.go() }
                Button("Отмена", role: .cancel) {}
            } message: { _ in
                Text("Лишний полив вреден корням")
            }
    }
}

extension View {
    func wetPrompt(_ ask: Overflow = .shared) -> some View {
        modifier(WetPrompt(ask: ask))
    }
}
