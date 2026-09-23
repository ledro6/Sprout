import SwiftUI
import UIKit

/// Убранное растение, которое ещё можно вернуть.
///
/// Удаление больше не спрашивает «вы уверены?» — оно убирает растение
/// сразу и пять секунд держит его здесь. Спросить заранее значило бы
/// останавливать каждого, кто удаляет нарочно, ради того, кто нажал не
/// туда; дать вернуть — останавливать только его.
///
/// Растение за эти секунды из сада уже ушло: экраны, поиск, статистика,
/// Siri — все видят сад без него. Здесь лежит только то, чего из сада не
/// восстановить: оно само и его место. Снимок с диска выбрасывается,
/// когда отсчёт кончился, — не раньше: снимок единственное, что пришлось
/// бы снимать заново.
///
/// Один на приложение: плашка отмены висит на каждой вкладке, и
/// показывать они должны одно и то же.
@Observable
final class Bin {
    static let shared = Bin()

    /// Что сейчас можно вернуть. Пусто — нечего.
    private(set) var pending: Removal?

    /// Сколько целых секунд осталось — число в кольце.
    private(set) var left = 0

    /// Когда убрали: от этого убывает кольцо.
    private(set) var since: Date?

    /// Отсчёт. Вернули — отменяется.
    @ObservationIgnored private var run: Task<Void, Never>?

    /// Куда возвращать. Слабо: сад живёт дольше корзины, а не наоборот.
    @ObservationIgnored private weak var garden: Garden?

    private init() {}

    /// Убрать растение и начать отсчёт.
    ///
    /// Плашка — где на экране стояла карточка, в координатах окна: оттуда
    /// по узору разгорается красное. Нулевая — значит, карточку не успели
    /// замерить, и красное идёт из середины экрана, а не из угла.
    ///
    /// Прежнее убранное, если отсчёт по нему ещё шёл, уходит насовсем
    /// сразу: плашка одна, и возвращать можно последнее — так же, как
    /// «Отменить» в любом приложении отменяет последнее действие.
    @MainActor
    func toss(_ id: Plant.ID, from plate: CGRect, in garden: Garden) {
        commit()
        guard let gone = withAnimation(Motion.appear, { garden.remove(id) })
        else { return }
        self.garden = garden
        pending = gone
        since = Date()
        left = Int(Motion.undoSeconds)
        Ember.shared.light(from: plate == .zero ? Screen.middle : plate)
        // Тем, кто не видит плашки, говорим вслух: иначе отсчёт шёл бы
        // мимо них.
        let line = "Растение «\(gone.plant.name)» удалено. Его можно вернуть."
        UIAccessibility.post(notification: .announcement, argument: line)
        run = Task { @MainActor [weak self] in
            for second in stride(from: Int(Motion.undoSeconds) - 1,
                                 through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                guard second > 0 else {
                    self.commit()
                    return
                }
                withAnimation(Motion.number) { self.left = second }
            }
        }
    }

    /// Вернуть — на то же место в той же комнате.
    @MainActor
    func undo() {
        guard let gone = pending else { return }
        run?.cancel()
        withAnimation(Motion.appear) { garden?.putBack(gone) }
        pending = nil
        since = nil
        Ember.shared.douse()
        Feel.pick()
    }

    /// Отсчёт кончился — растение уходит насовсем, со снимком.
    ///
    /// Зовётся и раньше срока: когда удаляют следующее растение и когда
    /// приложение уходит в фон. Выгрузить его оттуда могут в любой миг, и
    /// снимок убранного растения остался бы на диске навсегда — сад о нём
    /// уже ничего не знает.
    @MainActor
    func commit() {
        guard let gone = pending else { return }
        run?.cancel()
        if let shot = gone.plant.shot { Shots.drop(shot) }
        pending = nil
        since = nil
        Ember.shared.douse()
    }
}

/// Середина экрана — запасное место, откуда идут волны, когда карточку не
/// успели замерить.
///
/// Через окно, а не через `UIScreen.main`: тот помечен устаревшим ещё в
/// iOS 16, и приложение работает не с экраном, а со своим окном. Тем же
/// путём корень берёт глубину выреза.
enum Screen {
    static var middle: CGRect {
        let bounds = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .bounds ?? .zero
        return CGRect(x: bounds.midX - 1, y: bounds.midY - 1,
                      width: 2, height: 2)
    }
}

extension View {
    /// Плашка отмены — у нижнего края, над панелью вкладок.
    ///
    /// Висит на каждой вкладке, а не на одной главной: отсчёт идёт, куда
    /// бы хозяин ни ушёл, и узор тлеет на любой вкладке. Тлеющий фон без
    /// плашки читался бы поломкой — непонятно, что горит и как это
    /// остановить.
    ///
    /// Наложением на содержимое вкладки, а не на весь `TabView`: у
    /// содержимого нижняя безопасная зона уже включает панель вкладок, и
    /// плашка сама встаёт над ней, какой бы высоты панель ни была.
    func sproutUndo() -> some View {
        overlay(alignment: .bottom) { UndoToast() }
    }
}

/// Плашка «Растение удалено · Вернуть» — пока идёт отсчёт.
///
/// Появляется и уходит системным размытием (`blurReplace`): текст здесь
/// не выезжает и не проявляется, а собирается из расфокуса — тем же
/// переходом, которым система меняет цифры. Удалили следующее — плашка
/// сменяется тем же размытием: у неё новая личность.
private struct UndoToast: View {
    private let bin = Bin.shared

    var body: some View {
        ZStack {
            if let gone = bin.pending {
                plate(gone)
                    .id(gone.plant.id)
                    .transition(.blurReplace)
            }
        }
        .animation(Motion.toast, value: bin.pending?.plant.id)
    }

    private func plate(_ gone: Removal) -> some View {
        HStack(spacing: 12) {
            Countdown(since: bin.since, left: bin.left)

            VStack(alignment: .leading, spacing: 1) {
                Text("Растение удалено")
                    .font(Typography.toastTitle)
                    .foregroundStyle(Palette.ink)
                Text(gone.plant.name)
                    .font(Typography.toastNote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Без своего стекла: плашка уже стеклянная, а стекло на стекле
            // читалось бы кнопкой, которую положили на другую кнопку.
            Button { bin.undo() } label: {
                Text("Вернуть")
                    .font(Typography.toastAction)
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.bottom, Metrics.toastGap)
        .accessibilityElement(children: .contain)
    }
}

/// Кольцо отсчёта и число секунд в нём.
///
/// Кольцо убывает ровно, по кадрам, а число сменяется раз в секунду
/// системным переходом цифр — вниз, как и положено отсчёту. Красное, как
/// и узор за плашкой: это одно и то же время.
private struct Countdown: View {
    let since: Date?
    let left: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.alarm.opacity(0.22), lineWidth: Metrics.ringLine)
            TimelineView(.animation(paused: since == nil)) { frame in
                Circle()
                    .trim(from: 0, to: remaining(at: frame.date))
                    .stroke(Palette.alarm,
                            style: StrokeStyle(lineWidth: Metrics.ringLine,
                                               lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text("\(left)")
                .font(Typography.toastCount)
                .monospacedDigit()
                .foregroundStyle(Palette.alarm)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: Metrics.ring, height: Metrics.ring)
        .accessibilityLabel(spoken)
    }

    /// «Осталось 3 секунды» — для тех, кто кольца не видит.
    private var spoken: String {
        "Осталось \(left) " + Plant.plural(left, "секунда", "секунды", "секунд")
    }

    private func remaining(at moment: Date) -> CGFloat {
        guard let since else { return 0 }
        let passed = moment.timeIntervalSince(since) / Motion.undoSeconds
        return CGFloat(min(max(1 - passed, 0), 1))
    }
}
