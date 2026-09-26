import Charts
import SwiftUI

/// Одно растение в статистике: его цифры, при скольких процентах его
/// поливают, поливы периода точками и ближайшие поливы. Экран растения —
/// кнопкой внизу.
struct PlantBookView: View {
    let plantID: Plant.ID
    let period: Almanac.Period

    @Environment(Garden.self) private var garden

    @State private var book = PlantBook()

    private static let timeAxis = LocalizedStringKey(Lang.key("Когда"))
    private static let levelAxis = LocalizedStringKey(Lang.key("Вода в земле"))

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                if let plant {
                    VStack(spacing: Metrics.groupGap) {
                        header(plant)
                        figures
                            .hintSpot(.bookFigures)
                        aim
                            .hintSpot(.bookAim)
                        history
                            .hintSpot(.bookHistory)
                        upcoming(plant)
                        NavigationLink(value: StatsRoute.plant(plantID)) {
                            Label("Открыть растение", systemImage: "leaf")
                                .font(Typography.detail)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                        .sproutRide()
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .background { SproutBackground() }
            .walk(.book, scroll: reader)
        }
        .navigationTitle(plant?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                WalkButton(walk: .book, bare: true)
            }
        }
        .onAppear(perform: recount)
        .onChange(of: garden.log.count) {
            withAnimation(Motion.number) { recount() }
        }
    }

    private func recount() {
        guard let plant else { return }
        book = PlantBook.of(plant, log: garden.log, period: period,
                            since: garden.since)
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    // MARK: - Шапка

    private func header(_ plant: Plant) -> some View {
        HStack(spacing: 14) {
            PlantPhoto(plant: plant, radius: 16)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.name)
                    .font(Typography.navTitle)
                    .foregroundStyle(Palette.ink)
                Text([plant.species, garden.roomName(of: plant.id) ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                Text(Lang.format("Влажность %@", plant.moistureLabel))
                    .font(Typography.settingNote.weight(.semibold))
                    .foregroundStyle(Palette.level(plant.moisture))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.groupPadding)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    // MARK: - Цифры

    private var figures: some View {
        SproutGroup("Цифры") {
            Grid(alignment: .leading, horizontalSpacing: 12,
                 verticalSpacing: 18) {
                GridRow {
                    StatTile(value: book.inPeriod.formatted(),
                             caption: "За период")
                    StatTile(value: book.total.formatted(), caption: "Всего")
                }
                GridRow {
                    StatTile(value: book.last.map { Diary.label($0) } ?? "—",
                             caption: "Последний полив")
                    StatTile(value: book.average.map { Diary.rhythm($0) }
                                 ?? "—",
                             caption: "В среднем")
                }
            }
        }
        .sproutRide()
    }

    // MARK: - Точность

    private var aim: some View {
        SproutGroup("Когда поливаете") {
            if let typical = book.aim.typical {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Lang.format("Обычно — при %@ воды в земле",
                                     Stats.percent(typical)))
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    TermHint(.accuracy)
                }
                Text(Stats.verdict(Almanac.Aim.zone(typical)))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ZoneBar(aim: book.aim)
                ForEach(Almanac.Aim.Zone.allCases) { zone in
                    ZoneRow(zone: zone, aim: book.aim)
                }
            } else {
                Text("Полейте растение — и здесь появится, сколько воды было в земле в этот миг.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sproutRide()
    }

    // MARK: - История

    /// Как сохла земля — линией: полив поднимает к ста процентам, дальше
    /// она ползёт вниз по сроку, пока не польют снова. Полосы — те же цвета,
    /// что у тени карточки.
    private var history: some View {
        let points = plant.map { Diary.curve(garden.log, plant: $0) } ?? []
        return SproutGroup("История") {
            if points.isEmpty {
                Text("Поливов ещё не было.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
            } else {
                DryingChart(points: points)
            }
        }
        .sproutRide()
    }

    // MARK: - Дальше

    private func upcoming(_ plant: Plant) -> some View {
        SproutGroup("Следующие поливы") {
            HStack(spacing: 8) {
                ForEach(Array(book.dues.enumerated()), id: \.offset) { item in
                    Text(Stats.day(item.element))
                        .font(Typography.settingNote.weight(.semibold))
                        .foregroundStyle(item.offset == 0 ? Palette.accent
                                         : Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(Palette.ink.opacity(0.06)))
                }
            }
            if let days = Rhythm.suggest(for: plant, log: garden.log) {
                Label("Поливаете раньше срока", systemImage: "calendar.badge.clock")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                Text(Lang.format("Похоже, земля сохнет быстрее: %1$@ вместо %2$@.",
                                 Species.periodPhrase(days),
                                 Species.periodPhrase(plant.dryingDays)))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sproutRide()
    }
}
