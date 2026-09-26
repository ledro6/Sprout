import SwiftUI

/// Два сада рядом: свой — живой, друга — каким он пришёл в последнем коде.
/// Где больше — зелёным. Чего в коде прежней сборки нет, стоит прочерком.
struct GardenCompare: View {
    let me: Rival
    let friend: Rival

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    header
                    SproutGroup("Сады рядом") {
                        row(Lang.text("Поливы"), me.total, friend.total)
                        SproutDivider()
                        row(Lang.text("Череда"), me.streak, friend.streak)
                        SproutDivider()
                        row(Lang.text("Лучшая череда"), me.best, friend.best)
                        SproutDivider()
                        row(Lang.text("Растения"), me.plants, friend.plants)
                        SproutDivider()
                        row(Lang.text("Виды"), me.kinds, friend.kinds)
                        SproutDivider()
                        row(Lang.text("Ступени медалей"), me.medals,
                            friend.medals)
                        SproutDivider()
                        row(Lang.text("Уровень"), me.level, friend.level)
                        SproutDivider()
                        row(Lang.text("Вовремя, %"), me.aim, friend.aim)
                        SproutDivider()
                        row(Lang.text("Полные недели заданий"), me.weeks,
                            friend.weeks)
                    }
                    Text(Lang.format("Сад друга — на %@. Обновится, когда друг пришлёт код снова.",
                                     friend.stamp.formatted(
                                        .dateTime.day().month(.wide))))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background { SproutBackground() }
            .navigationTitle("Сравнить сады")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            person(me)
            Text("и")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
                .padding(.top, 14)
            person(friend)
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    private func person(_ rival: Rival) -> some View {
        VStack(spacing: 4) {
            Text(rival.name)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(rival.level.map { Gardener.title($0) } ?? "—")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Своё слева, друга справа, что сравниваем — посередине.
    private func row(_ title: String, _ mine: Int?, _ theirs: Int?) -> some View {
        let lead: Int? = if let mine, let theirs, mine != theirs {
            mine > theirs ? 0 : 1
        } else {
            nil
        }
        return HStack(spacing: 8) {
            figure(mine, wins: lead == 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(title)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            figure(theirs, wins: lead == 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func figure(_ value: Int?, wins: Bool) -> some View {
        Text(value.map { $0.formatted() } ?? "—")
            .font(wins ? Typography.detail : Typography.settingRow)
            .foregroundStyle(wins ? Palette.green : Palette.ink)
            .monospacedDigit()
    }
}

/// Челлендж в профиле: что, до какого числа, места и три кнопки — позвать,
/// отправить свой счёт, выйти.
struct RaceCard: View {
    let race: Race
    let places: [(name: String, count: Int)]
    /// Свой код соперника — со счётом челленджа.
    let mine: String
    let leave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowGap) {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(Typography.navTitle)
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(race.title)
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status)
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(places.enumerated()), id: \.offset) { item in
                HStack(spacing: 10) {
                    Text((item.offset + 1).formatted())
                        .font(Typography.figureCaption)
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 16, alignment: .trailing)
                    Text(item.element.name)
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(item.element.count.formatted())
                        .font(Typography.settingRow.weight(.semibold))
                        .foregroundStyle(item.offset == 0 ? Palette.green
                                         : Palette.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
            }
            if places.count < 2 {
                Text("Пока в таблице только вы: друзья появятся, когда пришлют свой код.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ShareLink(item: race.card()) {
            Label("Позвать", systemImage: "person.badge.plus")
                .lineLimit(1)
        }
        .buttonStyle(.glass)
        ShareLink(item: mine) {
            Label("Отправить счёт", systemImage: "square.and.arrow.up")
                .lineLimit(1)
        }
        .buttonStyle(.glass)
        Button(role: .destructive, action: leave) {
            Label("Выйти", systemImage: "xmark")
                .lineLimit(1)
        }
        .buttonStyle(.glass)
    }

    private var status: String {
        let span = race.span()
        let now = Date()
        if now < span.start {
            return Lang.format("Начнётся %@", span.start.formatted(
                .dateTime.day().month(.wide)))
        }
        if now < span.end {
            return Lang.format("Идёт до %@", span.end.addingTimeInterval(-1)
                .formatted(.dateTime.day().month(.wide)))
        }
        guard let first = places.first else { return Lang.text("Закончился") }
        return Lang.format("Закончился. Первое место — %@", first.name)
    }
}
