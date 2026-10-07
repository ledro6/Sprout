import SwiftUI

/// Два сада рядом: свой — живой, друга — каким он пришёл в последнем коде.
/// Сравниваются по «Вовремя, %» — лучший зелёным, проигравший никак не
/// выделен; остальное — справкой, без победителя. Чего в коде прежней
/// сборки нет, стоит прочерком.
struct GardenCompare: View {
    let me: Rival
    let friend: Rival

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    header
                    SproutGroup("Сравнение садов") {
                        row(Lang.text("Вовремя, %"), me.aim, friend.aim,
                            best: true) { Lang.format("%lld%%", $0) }
                    }
                    SproutGroup("Для справки") {
                        row(Lang.text("Поливы"), me.total, friend.total) {
                            Lang.format("%lld поливов", $0)
                        }
                        SproutDivider()
                        row(Lang.text("Дней подряд"), me.streak,
                            friend.streak) { Lang.format("%lld дней", $0) }
                        SproutDivider()
                        row(Lang.text("Рекорд дней подряд"), me.best,
                            friend.best) { Lang.format("%lld дней", $0) }
                        SproutDivider()
                        row(Lang.text("Растения"), me.plants, friend.plants) {
                            Lang.format("%lld растений", $0)
                        }
                        SproutDivider()
                        row(Lang.text("Виды"), me.kinds, friend.kinds) {
                            Lang.format("%lld видов", $0)
                        }
                        SproutDivider()
                        row(Lang.text("Медали"), me.medals, friend.medals) {
                            Lang.format("%lld ступеней", $0)
                        }
                        SproutDivider()
                        row(Lang.text("Уровень"), me.level, friend.level) {
                            $0.formatted()
                        }
                        SproutDivider()
                        row(Lang.text("Задания недели"), me.weeks,
                            friend.weeks) {
                            Lang.format("%lld полных недель", $0)
                        }
                    }
                    Text(Lang.format("Сад друга — на %@. Обновится, когда друг пришлёт код снова.",
                                     friend.stamp.formatted(
                                        .dateTime.day().month(.wide))))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                    // Сервера нет — свежий счёт друг пришлёт сам; попросить
                    // можно сообщением.
                    ShareLink(item: Lang.format("%@, пришли, пожалуйста, свежий счёт из Sprout: Профиль → Друзья → «Поделиться».",
                                                friend.name)) {
                        Label("Запросить обновление",
                              systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .font(Typography.settingNote)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background { SproutBackground() }
            .navigationTitle("Сравнить сады")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
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
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Своё слева, друга справа, что сравниваем — посередине. Числа — с
    /// подписью («144 полива»). Лучший зелёным — только там, где `best`.
    private func row(_ title: String, _ mine: Int?, _ theirs: Int?,
                     best: Bool = false,
                     label: @escaping (Int) -> String) -> some View {
        let lead: Int? = if best, let mine, let theirs, mine != theirs {
            mine > theirs ? 0 : 1
        } else {
            nil
        }
        return HStack(spacing: 8) {
            figure(mine.map(label), wins: lead == 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(title)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            figure(theirs.map(label), wins: lead == 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func figure(_ value: String?, wins: Bool) -> some View {
        Text(value ?? "—")
            .font(wins ? Typography.detail : Typography.settingRow)
            .foregroundStyle(wins ? Palette.green : Palette.ink)
            .monospacedDigit()
    }
}

/// Испытание в профиле: что, до какого числа, места, две кнопки — позвать
/// и отправить свой счёт — и отдельно «Выйти из испытания». Первое место —
/// зелёным, остальные не выделены: проигравшего не подсвечиваем.
struct RaceCard: View {
    let race: Race
    let places: [(name: String, count: Int)]
    /// Свой код соперника — со счётом челленджа.
    let mine: String
    let leave: () -> Void

    @State private var quitting = false

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
                        .foregroundStyle(Palette.secondaryText)
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
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            // Выход — отдельно и не рядом с «Отправить счёт», и с вопросом.
            Button(role: .destructive) { quitting = true } label: {
                Label("Выйти из испытания",
                      systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
            .font(Typography.settingNote)
            .confirmationDialog("Выйти из испытания?", isPresented: $quitting,
                                titleVisibility: .visible) {
                Button("Выйти", role: .destructive, action: leave)
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Испытание пропадёт с этого телефона. Вернуться можно, вставив приглашение ещё раз.")
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ShareLink(item: race.card()) {
            Label("Пригласить", systemImage: "person.badge.plus")
                .lineLimit(1)
        }
        .buttonStyle(.glass)
        ShareLink(item: mine) {
            Label("Отправить счёт", systemImage: "square.and.arrow.up")
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
