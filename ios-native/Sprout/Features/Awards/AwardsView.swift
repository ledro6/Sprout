import SwiftUI

/// Все награды — сеткой по группам, как в «Фитнесе»: полученные — своим
/// металлом и датой, остальные — сталью и тем, сколько набрано.
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
            AwardSheet(award: award, count: trophies.count(award))
        }
    }

    private var summary: some View {
        let got = cabinet.earned.count
        return Text(Lang.format("Получено %1$lld из %2$lld", got,
                                Award.allCases.count))
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
        let earned = cabinet.earned[award]
        return VStack(spacing: 6) {
            MedalBadge(award: award, earned: earned != nil)
                .frame(width: 84, height: 84)
            Text(award.title)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(earned.map(Self.day) ?? Self.left(award, trophies.count(award)))
                .font(Typography.cardCaption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// «12 мая 2026» — по-местному.
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(Lang.locale))
    }

    /// «3 из 10» у наград со счётом; у разовых — что их ещё ждут.
    static func left(_ award: Award, _ count: Int) -> String {
        award.goal > 1 ? Lang.format("%1$lld из %2$lld", count, award.goal)
            : Lang.text("Ещё впереди")
    }

    private func recount() {
        trophies = Trophies.of(garden.log, rooms: garden.rooms,
                               since: garden.since)
    }
}

/// Одна награда: объёмная медаль — её можно крутить пальцем, — за что она
/// и когда получена, а если ещё нет — сколько набрано.
struct AwardSheet: View {
    let award: Award
    let count: Int

    @Environment(\.dismiss) private var dismiss

    private let cabinet = Cabinet.shared

    var body: some View {
        let earned = cabinet.earned[award]
        NavigationStack {
            VStack(spacing: 20) {
                MedalStage(award: award, earned: earned != nil,
                           spinIn: earned != nil)
                    .frame(height: 300)
                VStack(spacing: 8) {
                    Text(award.title)
                        .font(Typography.welcome)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(award.detail)
                        .font(Typography.settingRow)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let earned {
                        Text(Lang.format("Получена %@", AwardsView.day(earned)))
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else if award.goal > 1 {
                        ProgressView(value: Double(count),
                                     total: Double(award.goal))
                            .tint(Palette.accent)
                            .frame(maxWidth: 220)
                            .padding(.top, 8)
                        Text(AwardsView.left(award, count))
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 28)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
