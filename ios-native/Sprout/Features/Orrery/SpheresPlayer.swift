import AVFoundation
import SwiftUI

/// Проигрыватель музыки сфер. Звук собирается заранее, в фоне, и играет
/// из памяти — ровно столько, сколько летит месяц. Сессия та же, что у
/// звуков приложения: беззвучный режим глушит.
@MainActor
final class SpheresPlayer {
    private var player: AVAudioPlayer?

    func prepare(_ notes: [Spheres.Note]) async {
        let data = await Task.detached(priority: .userInitiated) {
            Spheres.wav(Spheres.render(notes))
        }.value
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(data: data,
                                    fileTypeHint: AVFileType.wav.rawValue)
        player?.prepareToPlay()
    }

    /// Запускает звук чуть погодя, по часам звуковой карты, и отвечает,
    /// через сколько секунд он станет слышен — с задержкой вывода: у
    /// наушников по Bluetooth она в десятые доли секунды.
    func start(lead: TimeInterval = 0.1) -> TimeInterval {
        guard let player else { return 0 }
        player.play(atTime: player.deviceCurrentTime + lead)
        return lead + AVAudioSession.sharedInstance().outputLatency
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
