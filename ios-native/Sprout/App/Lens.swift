import AppIntents
import CoreImage
import UIKit
import Vision
import VisualIntelligence

// Визуальный интеллект: навели камеру на растение или выделили его на
// снимке экрана — в поиске появляются растения сада, на которые оно похоже,
// со своими фото, комнатой и влажностью. Нажатие открывает растение в
// приложении, там большая кнопка «Полить». Всё на телефоне, без сети.

/// Кадр визуального интеллекта — в растения сада. Такой запрос в приложении
/// может быть только один.
struct PlantLens: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws
        -> [PlantEntity] {
        // Ярлыки визуального интеллекта — те же свидетельства, что ярлыки
        // классификатора, только без уверенности.
        let labels = input.labels.map { Sighting(name: $0, confidence: 1) }
        let frame = input.pixelBuffer.flatMap(Lens.picture)
        return await Lens.shared.match(frame: frame, labels: labels)
    }
}

/// Открыть растение: из поиска визуального интеллекта и отовсюду, где
/// система показывает растения сада.
struct OpenPlant: OpenIntent {
    static let title: LocalizedStringResource = "Открыть растение"

    @Parameter(title: "Растение")
    var target: PlantEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        Summon.shared.plant = target.id
        return .result()
    }
}

/// Сравнение кадра с растениями сада. Отпечатки фото считаются один раз и
/// помнятся, пока приложение живо: визуальный интеллект спрашивает часто, а
/// фото меняются редко — новое фото даёт новый ключ. На главной очереди, как
/// сад; тяжёлое Vision делает у себя.
@MainActor
final class Lens {
    static let shared = Lens()

    private var traces: [String: FeaturePrintObservation] = [:]

    /// Кадр в картинку для Vision.
    nonisolated static func picture(_ pixels: CVReadOnlyPixelBuffer) -> CGImage? {
        pixels.withUnsafeBuffer { buffer in
            let image = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(image, from: image.extent)
        }
    }

    func match(frame: CGImage?, labels: [Sighting]) async -> [PlantEntity] {
        var seen = labels
        if let frame,
           let classes = try? await ClassifyImageRequest().perform(on: frame) {
            seen += classes.map {
                Sighting(name: $0.identifier, confidence: Double($0.confidence))
            }
        }
        // Не растение — молчим: собаку за Баксика не выдаём.
        guard let sight = Likeness.sight(seen) else { return [] }
        var trace: FeaturePrintObservation?
        if let frame {
            trace = try? await GenerateImageFeaturePrintRequest()
                .perform(on: frame)
        }
        // Запрос мог разбудить приложение из фона: сад — с диска.
        let garden = Garden.shared
        garden.reload()
        var candidates: [Likeness.Candidate] = []
        var entities: [Plant.ID: PlantEntity] = [:]
        for room in garden.rooms {
            for plant in room.plants {
                var distance: Double?
                if let trace, let other = await reference(plant) {
                    distance = try? trace.distance(to: other)
                }
                let kin = sight.preset != nil
                    && Preset.known(plant.species) == sight.preset
                candidates.append(Likeness.Candidate(
                    id: plant.id, distance: distance, kin: kin,
                    own: plant.shot != nil))
                entities[plant.id] = PlantEntity(plant, room: room.name)
            }
        }
        return Likeness.rank(candidates).compactMap { entities[$0] }
    }

    /// Отпечаток фото растения: своего снимка, а нет его — картинки вида.
    private func reference(_ plant: Plant) async -> FeaturePrintObservation? {
        let key = plant.id + "|" + (plant.shot ?? plant.photo)
        if let known = traces[key] { return known }
        let picture = plant.shot.flatMap { Snapshot.image($0) }
            ?? UIImage(named: plant.photo)
        guard let image = picture?.cgImage,
              let trace = try? await GenerateImageFeaturePrintRequest()
                  .perform(on: image)
        else { return nil }
        traces[key] = trace
        return trace
    }
}
