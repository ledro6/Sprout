import SwiftUI

/// Блок «Сегодня» сверху комнаты — компактный, в одну-две строки: кому пора
/// пить и кнопка «Полить всех (n)», а пить некому — «Всё в порядке ·
/// ближайший полив — …». Справа — маленькая плашка серии. Садовник и
/// задания недели живут в профиле, приветствие — только в пустом саду.
/// Дача и погода — не больше двух плашек строкой ниже. Сменились сутки —
/// блок сам перерисуется, часы — поминутные.
struct TodayBlock: View {
    let room: Room

    @Environment(Garden.self) private var garden

    @State private var streak = 0
    /// Первый пересчёт — без анимации: вью SwiftUI создаёт заново при каждом
    /// возвращении на экран, и число серии вырастало бы из нуля снова.
    @State private var counted = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            block
        }
        .task(id: garden.log.count) { recount() }
    }

    private var block: some View {
        // Кого поливать — по всему саду, а не по комнате: кнопка нужна,
        // пока есть кого, где бы он ни стоял.
        let due = MoistureStatus.needsWater(in: garden.rooms)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if due.isEmpty {
                        Text(MoistureStatus.calmLine(in: garden.rooms))
                            .font(Typography.settingNote)
                    } else {
                        Text(Lang.format("Полить сегодня: %lld", due.count))
                            .font(Typography.detail)
                    }
                }
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
                if streak > 0 {
                    streakChip
                }
                if !due.isEmpty {
                    Button { pourAll(due) } label: {
                        Text(Lang.format("Полить всех (%lld)", due.count))
                            .font(Typography.settingNote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .transition(.blurReplace)
                }
            }
            .padding(.horizontal, Metrics.groupPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
            .animation(Motion.number, value: due.map(\.id))
            chips
        }
        .sproutRide()
    }

    /// Серия — огонёк и число: подпись целиком читает VoiceOver.
    private var streakChip: some View {
        Label {
            Text(streak.formatted())
                .monospacedDigit()
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: "flame.fill").foregroundStyle(Palette.warn)
        }
        .font(Typography.settingNote.weight(.semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Lang.format("Дней подряд: %lld", streak))
    }

    /// «Полить всех»: поливает только тех, кому пора, одной плашкой «Вернуть».
    private func pourAll(_ due: [Plant]) {
        let done = Bin.shared.waterNeeded(due.map(\.id), in: garden)
        guard done > 0 else { return }
        Cheer.shared.now(from: Screen.middle)
        Feel.water()
    }

    // MARK: - Дача и погода

    /// Плашка дождя на даче — одна, см. `Dacha.rainLine`. Только там, куда
    /// дождь падает, и только когда погода на даче пришла, см. `Dachnik`.
    private var rainLine: String? {
        guard room.atDacha, Settings.shared.weather, Climate.open(room.name)
        else { return nil }
        return Dacha.rainLine(Dachnik.shared.rain)
    }

    /// Не больше двух плашек: на даче «На даче» и дождь (нет дождя — погода),
    /// дома — только погода.
    @ViewBuilder
    private var chips: some View {
        if room.atDacha || weatherShown {
            HStack(spacing: 8) { chipList }
        }
    }

    private var weatherShown: Bool {
        guard rainLine == nil, Settings.shared.weather,
              let climate = Settings.shared.climate else { return false }
        return climate.fresh()
    }

    @ViewBuilder
    private var chipList: some View {
        if room.atDacha {
            chip(Lang.text("На даче"), icon: "house.lodge.fill",
                 tint: Palette.green)
            if let rainLine {
                chip(rainLine, icon: "cloud.rain.fill", tint: Palette.water,
                     multicolor: true)
            }
        }
        if weatherShown, let climate = Settings.shared.climate {
            chip(weatherLine(climate), icon: climate.symbol,
                 tint: Palette.warn, multicolor: true)
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

    private func recount() {
        var quiet = Transaction()
        quiet.disablesAnimations = !counted
        withTransaction(quiet) {
            streak = garden.score().streak
        }
        counted = true
    }
}
