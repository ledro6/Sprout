import SwiftUI

/// Карточка дня — сверху комнаты: приветствие по времени суток, кто здесь
/// ждёт воды и две живые мелочи — череда дней с поливом и сколько осталось
/// до ближайшей медали. Ждут воды — «Обойти по очереди» запускает обход
/// сада на экране блокировки. Значок времени суток дышит; сменились сутки —
/// карточка сама перерисуется, часы — поминутные.
struct DayCard: View {
    let room: Room

    /// Медаль нажали — открыть полку наград.
    let awards: () -> Void

    @Environment(Garden.self) private var garden

    @State private var trophies = Trophies()
    @State private var streak = 0

    private let cabinet = Cabinet.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            card(Daypart.of(context.date))
        }
        .task(id: garden.log.count) { recount() }
    }

    private func card(_ part: Daypart) -> some View {
        let due = Seed.due(in: [room])
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: part.icon)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30))
                    .symbolEffect(.breathe)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.greeting(garden.owner))
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(due.isEmpty
                         ? Lang.text("Здесь все довольны — можно выдохнуть.")
                         : Seed.dueLine(due))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            chips
            if !due.isEmpty, Live.shared.enabled, !Live.shared.rounding {
                Button {
                    Task { await Live.shared.startRound() }
                    Feel.done()
                } label: {
                    Label("Обойти по очереди", systemImage: "figure.walk")
                        .font(Typography.settingNote)
                        .lineLimit(1)
                }
                .buttonStyle(.glass)
                .transition(.blurReplace)
            }
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .animation(Motion.number, value: due.map(\.id))
        .sproutRide()
    }

    /// Череда и медаль — капсулами в ряд, а не влезают — друг под другом.
    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chipList }
            VStack(alignment: .leading, spacing: 8) { chipList }
        }
    }

    @ViewBuilder
    private var chipList: some View {
        if streak > 0 {
            chip(Lang.format("череда %lld", streak), icon: "flame.fill",
                 tint: Palette.warn)
        }
        if let next = cabinet.next(trophies) {
            Button(action: awards) {
                chip(Lang.format("До «%1$@» осталось %2$lld",
                                 next.rank.title, next.left),
                     icon: "medal.fill", tint: Palette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func chip(_ text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .font(Typography.settingNote)
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    private func recount() {
        trophies = Trophies.of(garden.log, rooms: garden.rooms,
                               since: garden.since)
        streak = garden.score().streak
    }
}
