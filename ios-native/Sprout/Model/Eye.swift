import UIKit
import Vision

/// Что на снимке: классификатор Apple, прямо на телефоне и без сети. В
/// симуляторе не работает — это не поломка.
enum Eye {
    /// Не вышло — пустой ответ: подсказка необязательна.
    static func look(at image: UIImage) async -> [Sighting] {
        guard let frame = image.cgImage else { return [] }
        let request = ClassifyImageRequest()
        guard let seen = try? await request.perform(on: frame) else {
            return []
        }
        return seen.map {
            Sighting(name: $0.identifier, confidence: Double($0.confidence))
        }
    }

    static func guess(_ image: UIImage) async -> Guess? {
        Species.read(await look(at: image))
    }
}
