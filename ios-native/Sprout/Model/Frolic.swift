import Foundation
import Observation

/// Кутерьма от тряски: фигурки волной сжимаются и вырастают другими, узор с
/// каждым тактом перекрашивается, а потом садится обратно в выбранное. Здесь
/// только арифметика тактов; что рисовать, решает узор.
struct Frolic: Sendable {
    var elapsed: Double

    /// Шесть тактов по 0.7 с: пять беспорядочных и последний, которым узор
    /// садится обратно.
    static let beat = 0.7
    static let beats = 6

    /// На такт больше: дальняя фигурка трогается на такт позже ближней.
    static var seconds: Double { Double(beats + 1) * beat }

    /// Состояние и размер фигурки с этим черёдом. Первая половина такта —
    /// сжатие до нуля в прежнем состоянии, вторая — рост уже в следующем;
    /// сквозь ноль фигурка проскакивает быстро.
    func look(turn: Double) -> (state: Int, scale: Double) {
        let own = elapsed - min(max(turn, 0), 1) * Self.beat
        guard own > 0 else { return (0, 1) }
        let raw = own / Self.beat
        let beat = Int(raw)
        guard beat < Self.beats else { return (Self.beats, 1) }
        let part = raw - Double(beat)
        if part < 0.5 {
            let x = part * 2
            return (beat, 1 - x * x * x)
        }
        let x = (part - 0.5) * 2
        return (beat + 1, 1 - pow(1 - x, 3))
    }

    static func chaotic(_ state: Int) -> Bool {
        state > 0 && state < beats
    }
}

/// Кутерьма как событие. Одна на приложение: фон рисуется в двух местах, и
/// своё время у каждого разошлось бы на кадр.
@Observable
final class Frenzy {
    static let shared = Frenzy()

    private(set) var start: Date?

    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Пока идёт, второй раз не начинается. Отвечает, тронулась ли, — отклик
    /// в руке идёт только с ней.
    @discardableResult
    func begin(at moment: Date = Date()) -> Bool {
        guard start == nil else { return false }
        start = moment
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Frolic.seconds))
            guard !Task.isCancelled else { return }
            start = nil
        }
        return true
    }

    func frolic(at moment: Date) -> Frolic? {
        guard let start else { return nil }
        let elapsed = moment.timeIntervalSince(start)
        return elapsed < Frolic.seconds ? Frolic(elapsed: elapsed) : nil
    }
}
