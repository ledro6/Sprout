import UIKit
import Vision

/// Глаз приложения: что на снимке.
///
/// Классификатор Apple, тот же, что ищет картинки в Фото. Считает
/// полностью на телефоне, работает без сети и ничего никуда не отправляет
/// — политика конфиденциальности Sprout остаётся верной дословно.
///
/// В симуляторе классификатор не работает — отвечает ошибкой, — и это не
/// поломка приложения. На телефоне работает начиная с A12; у iPhone 13 Pro
/// это A15, то есть с запасом.
enum Eye {
    /// Посмотреть на снимок. Не вышло — пустой ответ: подсказка вещь
    /// необязательная, и вместо неё экран просто оставляет поля пустыми.
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

    /// Он же, но сразу догадкой о растении.
    static func guess(_ image: UIImage) async -> Guess? {
        Species.read(await look(at: image))
    }
}
