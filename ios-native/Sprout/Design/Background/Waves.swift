import Foundation
import Observation
import SwiftUI

/// Волна полива. Одна на приложение: фон рисуется в двух местах, и свои волны
/// разошлись бы швом. Хранится начало, а долю на каждый кадр спрашивает
/// `TimelineView` — свой цикл со сном дёргался.
@Observable
final class Cheer {
    static let shared = Cheer()

    private(set) var start: Date?

    private(set) var origin: CGPoint = .zero

    /// Новая волна отменяет старую.
    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    @ObservationIgnored private var waiting: [CGRect] = []
    @ObservationIgnored private var queueRun: Task<Void, Never>?

    /// Встать в очередь за идущей волной — для показа цвета волны. Полив так
    /// не делает: он откликается сразу.
    @MainActor
    func queue(from plate: CGRect) {
        guard start != nil else { return now(from: plate) }
        // Очередь — отклик на нажатия, а не архив: переполненная теряет самую
        // позднюю.
        if waiting.count >= Motion.queued { waiting.removeLast() }
        waiting.append(plate)
        guard queueRun == nil else { return }
        queueRun = Task { @MainActor in
            while !waiting.isEmpty {
                if let step = wave(at: Date()) {
                    try? await Task.sleep(for: .seconds(
                        (1 - step) * Motion.cheerSeconds + Motion.changeGap))
                }
                if Task.isCancelled { break }
                now(from: waiting.removeFirst())
            }
            queueRun = nil
        }
    }

    /// Полили вот здесь (плашка в координатах окна). Волна стартует с форой
    /// на путь от середины плашки до края — под плашкой узора не видно, а без
    /// форы фон трогался позже тени.
    func now(from plate: CGRect) {
        run?.cancel()
        origin = CGPoint(x: plate.midX, y: plate.midY)
        let lead = Self.lead(across: plate)
        start = Date().addingTimeInterval(-lead)
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.cheerSeconds - lead))
            guard !Task.isCancelled else { return }
            start = nil
        }
    }

    /// По вписанной окружности: фронт к началу не выпрыгивает из плашки.
    private static func lead(across plate: CGRect) -> Double {
        let radius = Double(min(plate.width, plate.height)) / 2
        return radius / Double(Metrics.waveReach)
            * (1 - Metrics.popSpan) * Motion.cheerSeconds
    }

    func wave(at moment: Date) -> Double? {
        guard let start else { return nil }
        let step = moment.timeIntervalSince(start) / Motion.cheerSeconds
        return step < 1 ? step : nil
    }
}

/// Узор тлеет красным, пока удаление можно отменить: волна разливается весь
/// отсчёт и к концу заливает экран, потом быстрая волна гасит его. Один на
/// приложение, как `Cheer`; держит начало и конец, долю спрашивает экран.
@Observable
final class Ember {
    static let shared = Ember()

    private(set) var start: Date?

    private(set) var origin: CGPoint = .zero

    /// Не наблюдается: чтобы расписание кадров шло, хватает `start`.
    @ObservationIgnored private var fade: Date?

    /// Гаснет оттуда, докуда успело разгореться.
    @ObservationIgnored private var reached = 0.0

    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Новое удаление — новый отсчёт: красное идёт от новой карточки.
    @MainActor
    func light(from plate: CGRect) {
        run?.cancel()
        origin = CGPoint(x: plate.midX, y: plate.midY)
        fade = nil
        reached = 0
        start = Date()
    }

    @MainActor
    func douse() {
        guard let start, fade == nil else { return }
        reached = min(Date().timeIntervalSince(start) / Motion.undoSeconds, 1)
        fade = Date()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.emberOutSeconds))
            guard !Task.isCancelled else { return }
            self.start = nil
            self.fade = nil
        }
    }

    func smoulder(at moment: Date) -> Smoulder? {
        guard let start else { return nil }
        let rise = max(moment.timeIntervalSince(start) / Motion.undoSeconds, 0)
        guard let fade else {
            let now = min(rise, 1)
            return Smoulder(origin: origin, rise: now, reached: now, fall: 0)
        }
        let fall = moment.timeIntervalSince(fade) / Motion.emberOutSeconds
        guard fall < 1 else { return nil }
        return Smoulder(origin: origin, rise: rise, reached: reached,
                        fall: max(fall, 0))
    }
}

/// Доли тления. `rise` идёт и после отмены — начатые всплески доигрывают,
/// пока их не погасит обратная волна; краснота застыла на `reached`.
struct Smoulder {
    var origin: CGPoint
    var rise: Double
    var reached: Double
    var fall: Double
}

struct Recolour {
    /// Пара целиком: сменить могли и цвет узора, и цвет волны.
    var from: Shade
    var fromWave: Shade

    /// Цель — у перехода, а не из настройки: переход может быть не последним
    /// в очереди.
    var to: Shade
    var toWave: Shade

    var front: Front

    /// Без сглаживания: сглаживает сам узор.
    var step: Double
}

/// Смена цвета узора — перекраска фронтом от нажатого кружка, без роста и
/// ухода: фигурка та же, ей довольно перелиться. Хранится начало, по той же
/// причине, что у `Cheer`.
@Observable
final class Repaint {
    static let shared = Repaint()

    private(set) var start: Date?

    @ObservationIgnored private var painting: Recolour?
    @ObservationIgnored private var waiting: [Recolour] = []
    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Зовётся до смены настройки — прежний цвет надо запомнить. Второе
    /// нажатие встаёт в очередь, а не обрывает первое. Пары «откуда — куда»
    /// сцепляются сами.
    @MainActor
    func begin(base: Tint, wave: Tint, to shape: Tint, toWave: Tint,
               from spot: CGPoint) {
        // Переполнилась очередь — последний ждущий перенимает цель нового:
        // хвост не растёт, конец верный.
        if waiting.count >= Motion.queued, var last = waiting.popLast() {
            last.to = Shade(shape)
            last.toWave = Shade(toWave)
            last.front = .point(spot)
            waiting.append(last)
        } else {
            waiting.append(Recolour(from: Shade(base), fromWave: Shade(wave),
                                    to: Shade(shape), toWave: Shade(toWave),
                                    front: .point(spot), step: 0))
        }
        guard run == nil else { return }
        // Первый переход трогается прямо здесь, а не в задаче: иначе на кадр
        // весь узор вспыхивал новым цветом и откатывался.
        step()
        run = Task { @MainActor in
            while painting != nil {
                // Пока идёт промежуток, доля стоит на единице — узор держит
                // цель отыгравшего.
                try? await Task.sleep(
                    for: .seconds(Motion.repaintSeconds + Motion.changeGap))
                if Task.isCancelled { break }
                step()
            }
            painting = nil
            start = nil
            run = nil
        }
    }

    @MainActor
    private func step() {
        painting = waiting.isEmpty ? nil : waiting.removeFirst()
        start = painting == nil ? nil : Date()
    }

    func recolour(at moment: Date) -> Recolour? {
        guard var now = painting, let start else { return nil }
        let done = moment.timeIntervalSince(start) / Motion.repaintSeconds
        now.step = min(max(done, 0), 1)
        return now
    }
}

/// Смена набора фигурок. Прежний набор держится вместе с новым — пока волна
/// идёт, на экране оба; раскладка у прежнего своя, иначе он перетасовался бы
/// перед уходом.
struct Reshape {
    var from: [Int]
    var fromWeave: Weave

    /// Цель — у перехода: настройка уже может показывать цель последнего
    /// нажатия.
    var to: [Int]
    var toWeave: Weave
    /// Добавили фигурку — из её клетки; убрали — с краёв экрана.
    var front: Front
    var step: Double
}
