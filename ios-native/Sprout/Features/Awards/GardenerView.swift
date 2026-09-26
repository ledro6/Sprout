import SwiftUI

/// Садовник: оранжерея, уровень и титул, задания недели, лестница титулов
/// и откуда берётся опыт. Открывается с карточки дня и из профиля.
struct GardenerView: View {
    @Environment(Garden.self) private var garden

    @State private var me = Gardener(experience: 0)
    @State private var week: Week?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.groupGap) {
                hero
                quests
                ladder
                sources
            }
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background { SproutBackground() }
        .navigationTitle("Садовник")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: garden.log.count) { recount() }
    }

    private func recount() {
        me = Gardener.of(log: garden.log, quests: QuestBook.shared.done,
                         medals: Cabinet.shared.total)
        week = Week.of(Date(), log: garden.log, rooms: garden.rooms)
    }

    // MARK: - Оранжерея и уровень

    private var hero: some View {
        VStack(spacing: 10) {
            GlasshouseView(house: me.glasshouse, animated: true)
                .frame(maxWidth: 360)
                .padding(.bottom, 4)
            Text(me.title)
                .font(Typography.welcome)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            Text(Lang.format("Уровень %lld", me.level))
                .font(Typography.detail)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            ProgressView(value: me.progress)
                .tint(Palette.green)
                .frame(maxWidth: 260)
                .accessibilityLabel(Lang.format("До следующего уровня: %lld",
                                                me.left))
            Text(Lang.format("До следующего уровня: %lld", me.left))
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .animation(Motion.number, value: me)
    }

    // MARK: - Задания недели

    private var quests: some View {
        SproutGroup("Задания недели") {
            if let week, !week.challenges.isEmpty {
                ForEach(Array(week.challenges.enumerated()), id: \.element.id) {
                    item in
                    if item.offset > 0 { SproutDivider() }
                    QuestRow(challenge: item.element)
                }
                SproutDivider()
                Text(Lang.format("Новые задания — %@", week.end.formatted(
                    .dateTime.weekday(.wide))))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Выполните все задания четырёх недель за одно время года — и на полке появится медаль сезона.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Посадите первое растение — и появятся задания.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Титулы

    private var ladder: some View {
        SproutGroup("Титулы") {
            ForEach(1 ... Gardener.titles, id: \.self) { level in
                if level > 1 { SproutDivider() }
                HStack(spacing: 12) {
                    Text(level.formatted())
                        .font(Typography.figureCaption.weight(.semibold))
                        .foregroundStyle(level <= me.level ? .white
                                         : Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(level <= me.level
                                                  ? Palette.green
                                                  : Color.secondary.opacity(0.15)))
                    Text(Gardener.title(level))
                        .font(Typography.settingRow)
                        .foregroundStyle(level <= me.level ? Palette.ink
                                         : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 8)
                    if level == me.level {
                        Text("Сейчас")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.green)
                    } else if level > me.level {
                        Text(Gardener.threshold(level).formatted())
                            .font(Typography.settingNote)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Опыт

    private var sources: some View {
        SproutGroup("Откуда опыт") {
            source(Lang.text("Полив"), Gardener.pour)
            SproutDivider()
            source(Lang.text("Полив вовремя — сверху"), Gardener.aim)
            SproutDivider()
            source(Lang.text("Задание недели"), Gardener.quest)
            SproutDivider()
            source(Lang.text("Ступень медали"), Gardener.medal)
        }
    }

    private func source(_ title: String, _ points: Int) -> some View {
        HStack {
            Text(title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(Lang.format("+%lld", points))
                .font(Typography.settingRow.weight(.semibold))
                .foregroundStyle(Palette.green)
                .monospacedDigit()
        }
    }
}

/// Задание: кольцо набранного со значком, что сделать и что считается.
struct QuestRow: View {
    let challenge: Challenge

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: challenge.progress)
                    .stroke(challenge.done ? Palette.green : Palette.accent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: challenge.done ? "checkmark"
                      : challenge.quest.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(challenge.done ? Palette.green
                                     : challenge.failed ? Color.secondary
                                     : Palette.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(Typography.settingRow)
                    .foregroundStyle(challenge.failed ? Color.secondary
                                     : Palette.ink)
                    .strikethrough(challenge.failed)
                    .fixedSize(horizontal: false, vertical: true)
                Text(challenge.quest.detail)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(Typography.settingNote.weight(.semibold))
                    .foregroundStyle(challenge.done ? Palette.green
                                     : challenge.failed ? .red : Palette.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .animation(Motion.number, value: challenge)
    }

    private var status: String {
        if challenge.done { return Lang.text("Сделано") }
        if challenge.failed { return Lang.text("Сорвано на этой неделе") }
        return Lang.format("%1$lld из %2$lld", challenge.count, challenge.goal)
    }
}
