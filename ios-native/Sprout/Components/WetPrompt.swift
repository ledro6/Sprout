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

    /// «Маша уже полила 5 мин назад. Всё равно полить?» — перед своим поливом.
    struct Again: Identifiable {
        let id: Plant.ID
        let title: String
        let go: @MainActor () -> Void
    }

    var again: Again?

    /// Недавно полил кто-то из семьи: сперва вопрос, потом `go` (обычно —
    /// `water`, который при влажной земле спросит ещё раз).
    func askAgain(_ recent: Watering, go: @escaping @MainActor () -> Void) {
        again = Again(id: recent.plant, title: Family.again(recent), go: go)
    }

    /// Полить — или сначала спросить. Отклик (`then`) — у того, кто
    /// поливал: откуда пускать волну, знает он; зовётся, только если
    /// полилось.
    func water(_ id: Plant.ID, in garden: Garden,
               source: Journal.Source = .card,
               then: @escaping @MainActor () -> Void) {
        guard garden.wetCheck(id) != nil else {
            if Bin.shared.water(id, in: garden) {
                Journal.shared.waterTap(source)
                then()
            }
            return
        }
        ask(id, in: garden) {
            if Bin.shared.water(id, in: garden, anyway: true) {
                Journal.shared.waterTap(source)
                then()
            }
        }
    }

    /// Спросить про влажную землю; `go` — на «Всё равно полить».
    func ask(_ id: Plant.ID, in garden: Garden,
             go: @escaping @MainActor () -> Void) {
        guard let moisture = garden.wetCheck(id),
              let plant = garden.plant(id: id) else { return }
        Journal.shared.note(.waterGuardShown)
        question = Question(id: id, moisture: moisture,
                            estimated: plant.estimated, go: {
            Journal.shared.note(.waterGuardConfirmed)
            go()
        })
    }
}

/// Системный алерт вопроса. Две ступени идут друг за другом: сперва
/// «Маша уже полила…» (`again`), потом «Земля ещё влажная» (`question`) —
/// второй поднимается, когда первый уже ушёл.
struct WetPrompt: ViewModifier {
    let ask: Overflow

    func body(content: Content) -> some View {
        content
            .alert(
                ask.again?.title ?? "",
                isPresented: Binding(get: { ask.again != nil },
                                     set: { if !$0 { ask.again = nil } }),
                presenting: ask.again) { again in
                Button("Полить") {
                    // Следом может спросить защита от перелива: даём
                    // первому алерту уйти, а не ставим задержку.
                    Task { @MainActor in
                        await Task.yield()
                        again.go()
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
            .alert(
                ask.question?.title ?? "",
                isPresented: Binding(get: { ask.question != nil },
                                     set: { if !$0 { ask.question = nil } }),
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
