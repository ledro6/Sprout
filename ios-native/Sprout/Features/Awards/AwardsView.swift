import SwiftUI

/// Все награды — сеткой по группам, как в «Фитнесе»: у каждой — медаль
/// текущего уровня, её название и точки уровней под ним; не полученные —
/// сталью и тем, сколько набрано до следующей ступени.
struct AwardsView: View {
    @Environment(Garden.self) private var garden

    /// Не в окружении: полку читает и корень, где празднуют новую медаль.
    private let cabinet = Cabinet.shared

    @State private var trophies = Trophies()
    @State private var open: Award?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12,
                                    alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.groupGap) {
                summary
                ForEach(Award.Group.allCases) { group in
                    shelf(group)
                }
            }
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background { SproutBackground() }
        .navigationTitle("Награды")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recount() }
        .onChange(of: garden.log.count) { _, _ in recount() }
        .sheet(item: $open) { award in
            AwardSheet(award: award,
                       count: cabinet.count(award, in: trophies))
        }
    }

    private var summary: some View {
        Text(Lang.format("Получено %1$lld из %2$lld", cabinet.total,
                         Award.total))
            .font(Typography.settingNote)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .padding(.leading, 6)
    }

    private func shelf(_ group: Award.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(Typography.groupTitle)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(group.awards) { award in
                    Button { open = award } label: { cell(award) }
                        .buttonStyle(.plain)
                }
            }
            .padding(Metrics.groupPadding)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
        }
    }

    private func cell(_ award: Award) -> some View {
        let level = cabinet.level(award)
        let rank = Rank(award, max(level, 1))
        return VStack(spacing: 6) {
            MedalBadge(rank: rank, earned: level > 0)
                .frame(width: 84, height: 84)
            Text(rank.title)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Pips(award: award, level: level)
            Text(Self.status(award, level: level,
                             count: cabinet.count(award, in: trophies),
                             cabinet: cabinet))
                .font(Typography.cardCaption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Под медалью: верхняя ступень — когда получена; иначе — сколько
    /// набрано до следующей.
    static func status(_ award: Award, level: Int, count: Int,
                       cabinet: Cabinet) -> String {
        if level >= award.levels,
           let date = cabinet.date(Rank(award, award.levels)) {
            return day(date)
        }
        return left(Rank(award, level + 1), count)
    }

    /// «12 мая 2026» — по-местному.
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(Lang.locale))
    }

    /// «3 из 10» у ступеней со счётом; у разовых — что их ещё ждут.
    static func left(_ rank: Rank, _ count: Int) -> String {
        rank.goal > 1 ? Lang.format("%1$lld из %2$lld", min(count, rank.goal),
                                    rank.goal)
            : Lang.text("Ещё впереди")
    }

    private func recount() {
        trophies = Trophies.of(garden.log, rooms: garden.rooms,
                               since: garden.since)
    }
}

/// Точки уровней: полученные — металлом своей ступени, остальные — пустые.
struct Pips: View {
    let award: Award
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1 ... award.levels, id: \.self) { step in
                let tone = Rank(award, step).alloy.body
                Circle()
                    .fill(step <= level
                          ? Color(red: tone.red / 255, green: tone.green / 255,
                                  blue: tone.blue / 255)
                          : Palette.ink.opacity(0.12))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(Lang.format("Уровень %1$lld из %2$lld", level,
                                        award.levels))
    }
}

/// Одна награда: объёмная медаль — её можно крутить пальцем, — за что она
/// и лестница уровней. Нажали ступень — медаль сменяется на неё: полученная
/// своим металлом, будущая — сталью.
struct AwardSheet: View {
    let award: Award
    let count: Int

    @Environment(\.dismiss) private var dismiss

    private let cabinet = Cabinet.shared

    @State private var picked: Int?

    private var shown: Rank {
        Rank(award, picked ?? max(cabinet.level(award), 1))
    }

    var body: some View {
        let rank = shown
        let earned = cabinet.date(rank)
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MedalStage(rank: rank, earned: earned != nil, date: earned)
                        .id(rank)
                        .frame(height: 300)
                    VStack(spacing: 8) {
                        Text(rank.title)
                            .font(Typography.welcome)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                        Text(rank.detail)
                            .font(Typography.settingRow)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let earned {
                            Text(Lang.format("Получена %@", AwardsView.day(earned)))
                                .font(Typography.settingNote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } else if rank.goal > 1 {
                            ProgressView(value: Double(min(count, rank.goal)),
                                         total: Double(rank.goal))
                                .tint(Palette.accent)
                                .frame(maxWidth: 220)
                                .padding(.top, 8)
                            Text(AwardsView.left(rank, count))
                                .font(Typography.settingNote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 28)
                    .animation(Motion.number, value: rank)
                    ladder
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// Ступени по порядку: медаль, название и дата или сколько осталось.
    private var ladder: some View {
        SproutGroup("Уровни") {
            ForEach(1 ... award.levels, id: \.self) { level in
                let rank = Rank(award, level)
                let date = cabinet.date(rank)
                Button {
                    withAnimation(Motion.pill) { picked = level }
                    Feel.pick()
                } label: {
                    HStack(spacing: 12) {
                        MedalBadge(rank: rank, earned: date != nil)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rank.title)
                                .font(Typography.settingRow)
                                .foregroundStyle(Palette.ink)
                            Text(date.map(AwardsView.day)
                                 ?? AwardsView.left(rank, count))
                                .font(Typography.settingNote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 8)
                        if rank == shown {
                            Image(systemName: "checkmark")
                                .font(Typography.settingNote.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(rank == shown ? .isSelected : [])
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
    }
}
