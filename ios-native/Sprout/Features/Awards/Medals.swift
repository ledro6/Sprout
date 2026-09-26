import Observation
import SwiftUI
import UIKit

/// Картинки медалей: барельеф вида и металл считаются один раз, в фоне, и
/// живут до конца запуска. Это z-буфер по треугольникам модели и свет по
/// пикселям, а ступеней — несколько десятков, каждая в двух видах.
@MainActor
@Observable
final class Medals {
    static let shared = Medals()

    /// Сторона картинки: в сетке медаль — 84 пункта, втрое больше — с
    /// запасом на чеканку, иначе звёзды и жемчуг слипаются.
    static let size = 384

    /// Сторона текстур объёмной медали: на весь экран крупнее сетки.
    static let depth = 1024

    private var images: [String: UIImage] = [:]

    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var reliefs: [String: Task<[Float], Never>] = [:]
    @ObservationIgnored private var studio: Task<Picture, Never>?

    private init() {}

    /// Готовая картинка — или пусто: тогда она уже считается и появится
    /// сама, картинки наблюдаемые.
    func image(_ rank: Rank, earned: Bool) -> UIImage? {
        let key = "\(rank.id)-\(earned)"
        if let image = images[key] { return image }
        if !asked.contains(key) {
            asked.insert(key)
            Task { await render(rank, earned: earned, key: key) }
        }
        return nil
    }

    /// Поле объёмной медали — картой нормалей, см. `MedalCraft`.
    func normals(_ rank: Rank) async -> Picture {
        let relief = await relief(rank.award, size: Self.depth)
        let size = Self.depth
        let level = rank.level
        return await Task.detached(priority: .userInitiated) {
            let plate = Emboss.field(relief, size: size, level: level,
                                     radius: Float(size) / 2 - 1)
            return Emboss.normals(Emboss.flipped(plate.heights, size: size),
                                  size: size)
        }.value
    }

    /// Оборот: кольца и жемчуг из `Emboss`, буквы — выпуклые, с фаской.
    func back(_ letters: [Float]) async -> Picture {
        let size = Self.depth
        return await Task.detached(priority: .userInitiated) {
            let unit = Float(size) / 192
            let soft = Emboss.blur(Emboss.blur(letters, size: size), size: size)
            let heights = zip(Emboss.back(size: size), soft).map { plate, ink in
                max(plate, unit + 1.6 * unit * ink)
            }
            return Emboss.normals(Emboss.flipped(heights, size: size),
                                  size: size)
        }.value
    }

    /// Студия для отражений — одна на все медали.
    func room() async -> Picture {
        if let studio { return await studio.value }
        let task = Task.detached(priority: .userInitiated) {
            Emboss.studio(width: 512)
        }
        studio = task
        return await task.value
    }

    private func render(_ rank: Rank, earned: Bool, key: String) async {
        let relief = await relief(rank.award, size: Self.size)
        let size = Self.size
        let level = rank.level
        let picture = await Task.detached(priority: .userInitiated) {
            Emboss.medal(relief, size: size, level: level, earned: earned)
        }.value
        guard let image = Craft.image(picture) else { return }
        images[key] = UIImage(cgImage: image)
    }

    /// Одна задача на вид и размер: все ступени и серая медаль ждут один
    /// барельеф.
    private func relief(_ award: Award, size: Int) async -> [Float] {
        let key = "\(award.rawValue)-\(size)"
        if let running = reliefs[key] { return await running.value }
        let preset = award.preset
        let task = Task.detached(priority: .userInitiated) {
            let kit = await Workshop.shared.stock(preset)
            return Emboss.relief(kit, size: size)
        }
        reliefs[key] = task
        return await task.value
    }
}

/// Медаль картинкой; пока считается — бледный кружок того же размера.
/// Готовая вырастает на месте — как карточка растения.
struct MedalBadge: View {
    let rank: Rank
    let earned: Bool

    var body: some View {
        let image = Medals.shared.image(rank, earned: earned)
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .transition(.scale(scale: Motion.scale * 0.7)
                        .combined(with: .opacity))
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
