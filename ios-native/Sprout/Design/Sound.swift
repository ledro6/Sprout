import AVFoundation
import UIKit

/// Звуки приложения. Собраны `tool/make_sounds.py` и лежат в каталоге
/// ресурсов наборами данных. Играют через `Feel` — вместе с откликом в руке,
/// но со своей настройкой.
enum Chime: String, CaseIterable {
    case pour, plant, toss, undo, save, wrong, frolic

    @MainActor
    func play() { Speaker.shared.play(self) }

    /// При запуске: иначе первый звук опоздал бы на разбор файла.
    @MainActor
    static func warm() { Speaker.shared.warm() }
}

/// Проигрыватель на каждый звук, один раз на приложение. Сессия `.ambient`:
/// беззвучный режим телефона звуки глушит, а музыку в наушниках они не
/// прерывают, а подмешиваются.
@MainActor
private final class Speaker {
    static let shared = Speaker()

    private var players: [Chime: AVAudioPlayer] = [:]

    private var open = false

    private init() {}

    func play(_ chime: Chime) {
        guard Settings.shared.sounds else { return }
        begin()
        guard let player = player(chime) else { return }
        // Тот же звук подряд начинается заново, а не ждёт конца прежнего.
        player.currentTime = 0
        player.play()
    }

    func warm() {
        begin()
        for chime in Chime.allCases { _ = player(chime) }
    }

    private func begin() {
        guard !open else { return }
        open = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    /// Нет файла — звук просто не играет: это украшение.
    private func player(_ chime: Chime) -> AVAudioPlayer? {
        if let ready = players[chime] { return ready }
        guard let asset = NSDataAsset(name: "chime-\(chime.rawValue)"),
              let made = try? AVAudioPlayer(
                  data: asset.data, fileTypeHint: AVFileType.wav.rawValue)
        else { return nil }
        made.prepareToPlay()
        players[chime] = made
        return made
    }
}
