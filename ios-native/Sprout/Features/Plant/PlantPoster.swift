import SwiftUI
import UIKit

// Открытка для друзей: растение или вся оранжерея одной картинкой 4:5,
// 1080 × 1350 — в Сообщения, ленту, историю. Рисует `ImageRenderer`, а он
// не умеет ни Liquid Glass, ни материалов: стекло плашки — градиентом и
// бликом по краю. Узор фона — тот же, что на экранах, неподвижный; тема —
// как в приложении сейчас.

/// Что на открытке.
enum Poster: Hashable {
    case plant(Plant.ID)
    case garden
}

/// Лист с готовой открыткой и кнопкой «Поделиться». Картинка рисуется один
/// раз, когда лист открылся, и заново — если сменилась тема.
struct PosterSheet: View {
    let poster: Poster

    @Environment(Garden.self) private var garden
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer(minLength: 0)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22,
                                                    style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                        .accessibilityLabel(Text(caption))
                        .transition(.blurReplace)
                    let picture = Image(uiImage: image)
                    ShareLink(item: picture,
                              preview: SharePreview(caption, image: picture)) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.large)
                } else {
                    ProgressView()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background { SproutBackground() }
            .navigationTitle(poster == .garden ? "Моя оранжерея" : "Карточка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetClose { dismiss() }
                }
            }
        }
        .animation(Motion.appear, value: image == nil)
        .task(id: scheme) { image = render() }
    }

    private var caption: String {
        switch poster {
        case .plant(let id):
            Lang.format("%@ в Sprout", garden.plant(id: id)?.name ?? "")
        case .garden:
            Lang.text("Моя оранжерея в Sprout")
        }
    }

    /// На главной очереди — `ImageRenderer` иначе не умеет. Масштаб явный:
    /// у экрана он свой, а картинка должна выйти ровно 1080 × 1350.
    @MainActor
    private func render() -> UIImage? {
        let content: AnyView
        let grower = Gardener.of(log: garden.log, quests: QuestBook.shared.done,
                                 medals: Cabinet.shared.total)
        let streak = Postcard.streak(garden.score().streak)
        switch poster {
        case .plant(let id):
            guard let plant = garden.plant(id: id) else { return nil }
            content = AnyView(PlantPoster(
                plant: plant,
                photo: Snapshot.cover(plant),
                room: garden.roomName(of: id),
                days: Postcard.days(since: plant.addedOn, to: Date(),
                                    calendar: .current),
                streak: streak, grower: grower))
        case .garden:
            content = AnyView(GardenPoster(
                owner: garden.owner, grower: grower,
                plants: garden.plantCount, rooms: garden.rooms.count,
                days: Postcard.days(from: garden.since, to: Date(),
                                    calendar: .current),
                streak: streak))
        }
        let renderer = ImageRenderer(content: content
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Lang.locale))
        renderer.scale = CGFloat(Postcard.scale)
        renderer.proposedSize = ProposedViewSize(
            width: CGFloat(Postcard.width), height: CGFloat(Postcard.height))
        return renderer.uiImage
    }
}

// MARK: - Открытки

/// Растение: снимок или портрет, кличка, вид, сколько в саду, серия поливов
/// и титул садовника.
struct PlantPoster: View {
    let plant: Plant
    let photo: UIImage?
    let room: String?
    let days: Int
    let streak: Int?
    let grower: Gardener

    var body: some View {
        PosterFrame {
            picture
                .frame(maxWidth: .infinity)
                .frame(height: 214)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            PosterPlate {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: plant.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: species)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                HStack(alignment: .top, spacing: 12) {
                    PosterFigure(caption: Lang.text("В саду"),
                                 value: Postcard.age(days))
                    if let streak {
                        PosterFigure(caption: Lang.text("Дней подряд без перерыва"),
                                     value: streak.formatted())
                    } else {
                        PosterFigure(caption: Lang.format("Уровень %lld",
                                                          grower.level),
                                     value: grower.title)
                    }
                }
            }
        }
    }

    /// Вид и комната одной строкой; вида нет — одна комната.
    private var species: String {
        let kind = plant.species.trimmingCharacters(in: .whitespaces)
        guard let room, !room.isEmpty else { return kind }
        return kind.isEmpty ? room : Lang.format("%1$@ · %2$@", kind, room)
    }

    /// Портрет или снимок — во весь кадр. Нет их — рисунок вида на мягком
    /// зелёном; нет и рисунка — росток Sprout.
    @ViewBuilder
    private var picture: some View {
        if let photo {
            Color.clear.overlay {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            ZStack {
                LinearGradient(colors: [Palette.greenSoft, Palette.leaf.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if UIImage(named: plant.photo) != nil {
                    Image(plant.photo)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    SproutLogo(height: 96, aspect: SproutLogo.plain)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// Вся оранжерея: рисунок по уровню, титул, сколько растений и дней.
struct GardenPoster: View {
    let owner: String
    let grower: Gardener
    let plants: Int
    let rooms: Int
    let days: Int
    let streak: Int?

    var body: some View {
        PosterFrame {
            VStack(alignment: .leading, spacing: 4) {
                Text(Lang.text("Моя оранжерея"))
                    .font(.system(size: 13, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.secondaryText)
                Text(verbatim: owner.isEmpty ? grower.title : owner)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            PosterPlate {
                GlasshouseView(house: grower.glasshouse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                HStack(alignment: .top, spacing: 12) {
                    PosterFigure(caption: Lang.format("Уровень %lld", grower.level),
                                 value: grower.title)
                    PosterFigure(caption: Lang.text("Растений"),
                                 value: plants.formatted())
                }
                HStack(alignment: .top, spacing: 12) {
                    PosterFigure(caption: Lang.text("В саду"),
                                 value: Postcard.age(days))
                    if let streak {
                        PosterFigure(caption: Lang.text("Дней подряд без перерыва"),
                                     value: streak.formatted())
                    } else {
                        PosterFigure(caption: Lang.text("Комнат"),
                                     value: rooms.formatted())
                    }
                }
            }
        }
    }
}

// MARK: - Части

/// Холст открытки: фон с узором, содержимое и знак Sprout внизу.
private struct PosterFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Palette.background
            if Settings.shared.pattern { PosterPattern() }
            VStack(spacing: 14) {
                content
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    SproutLogo(height: 22, aspect: SproutLogo.plain)
                    Text(verbatim: "Sprout")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
            }
            .padding(22)
        }
        .frame(width: CGFloat(Postcard.width), height: CGFloat(Postcard.height))
        .clipped()
    }
}

/// Узор экранов — неподвижный: без волн, всходов и наклона, взошедший.
@MainActor
private struct PosterPattern: View {
    var body: some View {
        let shapes = Festive.shared.motif.dress(Settings.shared.chosen)
        SproutPattern(waves: [],
                      canvas: .zero,
                      bloomFront: Launch.shared.bloomFront,
                      bloom: 1,
                      shapes: shapes,
                      weave: Launch.shared.weave(for: shapes.count),
                      swap: nil,
                      repaint: nil,
                      frolic: nil,
                      baseShade: Settings.shared.patternHue.shade,
                      waveShade: Settings.shared.waveColour.shade,
                      lag: [],
                      era: 0,
                      ember: nil,
                      garland: nil)
    }
}

/// Стеклянная плашка. Настоящее стекло `ImageRenderer` не рисует — его
/// изображают фон с прозрачностью сверху вниз, блик по краю и тень.
private struct PosterPlate<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                     style: .continuous)
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(LinearGradient(
                    colors: [Palette.background.opacity(0.94),
                             Palette.background.opacity(0.78)],
                    startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    colors: [.white.opacity(scheme == .dark ? 0.35 : 0.95),
                             .white.opacity(0.08),
                             .white.opacity(scheme == .dark ? 0.2 : 0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                   lineWidth: 1.2)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.12),
                    radius: 16, y: 8)
    }
}

/// Число крупно и подпись под ним.
private struct PosterFigure: View {
    let caption: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(verbatim: caption)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
