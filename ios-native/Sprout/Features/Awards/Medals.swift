import Observation
import SwiftUI
import UIKit

/// Картинки медалей: барельеф вида и металл считаются один раз, в фоне, и
/// живут до конца запуска. Это z-буфер по треугольникам модели и свет по
/// пикселям, а медалей полтора десятка, каждая в двух видах.
@MainActor
@Observable
final class Medals {
    static let shared = Medals()

    /// Сторона картинки: в сетке медаль — 84 пункта, втрое больше не нужно.
    static let size = 192

    private var images: [String: UIImage] = [:]

    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var reliefs: [Award: Task<[Float], Never>] = [:]

    private init() {}

    /// Готовая картинка — или пусто: тогда она уже считается и появится
    /// сама, картинки наблюдаемые.
    func image(_ award: Award, earned: Bool) -> UIImage? {
        let key = "\(award.rawValue)-\(earned)"
        if let image = images[key] { return image }
        if !asked.contains(key) {
            asked.insert(key)
            Task { await render(award, earned: earned, key: key) }
        }
        return nil
    }

    /// Барельеф для объёмной медали — картой нормалей, см. `MedalCraft`.
    func normals(_ award: Award) async -> Picture {
        let relief = await relief(award)
        let size = Self.size
        return await Task.detached(priority: .userInitiated) {
            Emboss.normals(Emboss.flipped(relief, size: size), size: size)
        }.value
    }

    private func render(_ award: Award, earned: Bool, key: String) async {
        let relief = await relief(award)
        let size = Self.size
        let alloy = award.alloy
        let picture = await Task.detached(priority: .userInitiated) {
            Emboss.medal(relief, size: size, alloy: alloy, earned: earned)
        }.value
        guard let image = Craft.image(picture) else { return }
        images[key] = UIImage(cgImage: image)
    }

    /// Одна задача на вид: полученная и серая медаль ждут один барельеф.
    private func relief(_ award: Award) async -> [Float] {
        if let running = reliefs[award] { return await running.value }
        let size = Self.size
        let preset = award.preset
        let task = Task.detached(priority: .userInitiated) {
            let kit = await Workshop.shared.stock(preset)
            return Emboss.relief(kit, size: size)
        }
        reliefs[award] = task
        return await task.value
    }
}

/// Медаль картинкой; пока считается — бледный кружок того же размера.
struct MedalBadge: View {
    let award: Award
    let earned: Bool

    var body: some View {
        let image = Medals.shared.image(award, earned: earned)
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .transition(.opacity)
            } else {
                Circle().fill(Palette.ink.opacity(0.06))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(earned ? 0.2 : 0.08), radius: 6, y: 3)
        .animation(Motion.appear, value: image != nil)
        .accessibilityHidden(true)
    }
}
