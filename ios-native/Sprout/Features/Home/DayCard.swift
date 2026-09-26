import SwiftUI

/// Карточка дня — сверху комнаты: приветствие по времени суток, кто здесь
/// ждёт воды и две живые мелочи — череда дней с поливом и сколько осталось
/// до ближайшей медали. Ждут воды — «Обойти по очереди» запускает обход
/// сада на экране блокировки. Внизу — оранжерея садовника: уровень, титул
/// и задания недели; нажатие открывает всё о садовнике. Значок времени
/// суток дышит; сменились сутки — карточка сама перерисуется, часы —
/// поминутные.
struct DayCard: View {
    let room: Room

    /// Медаль нажали — открыть полку наград.
    let awards: () -> Void

    @Environment(Garden.self) private var garden

    @State private var trophies = Trophies()
    @State private var streak = 0
    @State private var me = Gardener(experience: 0)
    @State private var week: Week?
    @State private var growing = false

    private let cabinet = Cabinet.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            card(Daypart.of(context.date))
        }
        .task(id: garden.log.count) { recount() }
        .sheet(isPresented: $growing) {
            NavigationStack {
                GardenerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Готово") { growing = false }
                        }
                    }
            }
            .environment(garden)
        }
    }

    private func card(_ part: Daypart) -> some View {
        let due = Seed.due(in: [room])
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: part.icon)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30))
                    .symbolEffect(.breathe, isActive: !Power.shared.calm)
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
            SproutDivider()
            gardener
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
        if Settings.shared.weather, let climate = Settings.shared.climate,
           climate.fresh() {
            chip(weatherLine(climate), icon: climate.symbol,
                 tint: Palette.warn, multicolor: true)
        }
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

    /// «+31° · сохнут быстрее»; погода почти не влияет — только градусы.
    private func weatherLine(_ climate: Climate) -> String {
        let pace = climate.pace(outdoor: Climate.outdoor(room.name))
        if pace >= 1.08 {
            return Lang.format("%1$@ · %2$@", climate.degrees,
                               Lang.text("сохнут быстрее"))
        }
        if pace <= 0.92 {
            return Lang.format("%1$@ · %2$@", climate.degrees,
                               Lang.text("сохнут медленнее"))
        }
        return climate.degrees
    }

    private func chip(_ text: String, icon: String, tint: Color,
                      multicolor: Bool = false) -> some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(.numericText())
        } icon: {
            if multicolor {
                Image(systemName: icon).symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: icon).foregroundStyle(tint)
            }
        }
        .font(Typography.settingNote)
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    /// Оранжерея, уровень и задания недели — одной строкой.
    private var gardener: some View {
        Button { growing = true } label: {
            HStack(spacing: 12) {
                GlasshouseView(house: me.glasshouse)
                    .frame(width: 74)
                VStack(alignment: .leading, spacing: 5) {
                    Text(Lang.format("%1$@ · уровень %2$lld", me.title,
                                     me.level))
                        .font(Typography.settingNote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProgressView(value: me.progress)
                        .tint(Palette.green)
                    if let week, !week.challenges.isEmpty {
                        Text(Lang.format("Задания недели: %1$lld из %2$lld",
                                         week.done, week.challenges.count))
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                Image(systemName: "chevron.right")
                    .font(Typography.settingNote)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.number, value: me)
    }

    private func recount() {
        trophies = Trophies.of(garden.log, rooms: garden.rooms,
                               since: garden.since)
        streak = garden.score().streak
        me = Gardener.of(log: garden.log, quests: QuestBook.shared.done,
                         medals: Cabinet.shared.total)
        week = Week.of(Date(), log: garden.log, rooms: garden.rooms)
    }
}
