import SwiftUI
import UIKit

/// Убранное растение, которое ещё можно вернуть.
///
/// Удаление не спрашивает «вы уверены?»: растение уходит из сада сразу, а
/// здесь пять секунд лежат оно и его место. Снимок с диска выбрасывается
/// только по истечении отсчёта — его одного не восстановить.
@Observable
final class Bin {
    static let shared = Bin()

    private(set) var pending: Removal?

    private(set) var left = 0

    private(set) var since: Date?

    @ObservationIgnored private var run: Task<Void, Never>?

    @ObservationIgnored private weak var garden: Garden?

    private init() {}

    /// Плашка — где стояла карточка, в координатах окна: оттуда разгорается
    /// красное; нулевая — из середины экрана. Прежнее убранное уходит
    /// насовсем сразу: вернуть можно последнее.
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

    /// Зовётся и раньше срока — при следующем удалении и уходе в фон:
    /// выгрузят приложение — и снимок остался бы на диске сиротой.
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

/// Середина окна — запасное место, откуда идут волны. Не `UIScreen.main`: он
/// устарел.
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
    /// Плашка отмены над панелью вкладок — на каждой вкладке: узор тлеет
    /// везде, и без плашки это читалось бы поломкой. Наложением на содержимое
    /// вкладки: его безопасная зона уже включает панель.
    func sproutUndo() -> some View {
        overlay(alignment: .bottom) { UndoToast() }
    }
}

/// Приходит и уходит `blurReplace`; следующее удаление сменяет плашку тем же
/// размытием — у неё новая личность.
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

            // Без своего стекла: стекло на стекле читалось бы кнопкой на
            // кнопке.
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

/// Кольцо убывает по кадрам, число сменяется раз в секунду переходом цифр.
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

    private var spoken: String {
        "Осталось \(left) " + Plant.plural(left, "секунда", "секунды", "секунд")
    }

    private func remaining(at moment: Date) -> CGFloat {
        guard let since else { return 0 }
        let passed = moment.timeIntervalSince(since) / Motion.undoSeconds
        return CGFloat(min(max(1 - passed, 0), 1))
    }
}
