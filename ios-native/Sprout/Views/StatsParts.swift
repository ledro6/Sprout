import SwiftUI

extension Palette {
    /// Цвет растения по влажности — как его тень на карточке, только
    /// спокойные зелёные: в статистике «всё хорошо» тоже надо показать.
    static func level(_ moisture: Double) -> Color {
        switch Thirst(moisture: moisture) {
        case .calm: green
        case .warn: warn
        case .alarm: alarm
        }
    }

    /// Зоны точности: заранее — синяя вода, вовремя — оранжевая тень,
    /// в последний момент — красная, досуха — тёмно-красная.
    static func zone(_ zone: Almanac.Aim.Zone) -> Color {
        switch zone {
        case .early: water
        case .onTime: warn
        case .lastMoment: alarm
        case .dry: parched
        }
    }
}

/// Кольцо «сада сейчас»: доли довольных, ждущих скоро и ждущих уже —
/// дугами подряд, как кольца «Активности». В середине — главное число.
struct ThirstRing<Center: View>: View {
    let now: Almanac.Now
    let center: Center

    @State private var grown = false

    init(_ now: Almanac.Now, @ViewBuilder center: () -> Center) {
        self.now = now
        self.center = center()
    }

    private var parts: [(Double, Color)] {
        let total = Double(max(now.count, 1))
        return [(Double(now.calm) / total, Palette.green),
                (Double(now.warn) / total, Palette.warn),
                (Double(now.alarm) / total, Palette.alarm)]
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.ink.opacity(0.08), lineWidth: Metrics.statRing)
            ForEach(Array(parts.enumerated()), id: \.offset) { item in
                let start = parts.prefix(item.offset).reduce(0) { $0 + $1.0 }
                Circle()
                    .trim(from: start, to: grown ? start + item.element.0 : start)
                    .stroke(item.element.1,
                            style: StrokeStyle(lineWidth: Metrics.statRing,
                                               lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            center
        }
        .padding(Metrics.statRing / 2)
        .onAppear {
            withAnimation(Motion.enter.delay(0.15)) { grown = true }
        }
        .animation(Motion.number, value: now)
    }
}

/// Влажность каждого растения чёрточкой, от самого сухого: весь сад одним
/// взглядом.
struct MoistureStrip: View {
    let levels: [Double]

    var body: some View {
        GeometryReader { geometry in
            let count = max(levels.count, 1)
            let gap: CGFloat = count > 40 ? 1 : 2
            let width = max((geometry.size.width - gap * CGFloat(count - 1))
                            / CGFloat(count), 1)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(levels.enumerated()), id: \.offset) { item in
                    Capsule()
                        .fill(Palette.level(item.element))
                        .frame(width: width,
                               height: max(geometry.size.height
                                           * CGFloat(item.element), width))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: Metrics.stripHeight)
        .animation(Motion.number, value: levels)
        .accessibilityHidden(true)
    }
}

/// Число с ярлыком и, если есть, заметкой под ним — клетка итога.
struct StatTile: View {
    let value: String
    let caption: LocalizedStringKey
    var note: String?
    var tone: Color?
    var icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.figure)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
            if let note {
                HStack(spacing: 3) {
                    if let icon {
                        Image(systemName: icon)
                            .font(Typography.figureCaption.weight(.bold))
                    }
                    Text(note)
                        .font(Typography.figureCaption)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(tone ?? .secondary)
                .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.number, value: value)
        .accessibilityElement(children: .combine)
    }
}

/// Доли зон одной полосой — как на экране памяти в настройках телефона.
struct ZoneBar: View {
    let aim: Almanac.Aim

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Almanac.Aim.Zone.allCases) { zone in
                    let share = aim.share(zone)
                    if share > 0 {
                        Rectangle()
                            .fill(Palette.zone(zone))
                            .frame(width: max(geometry.size.width
                                              * CGFloat(share) - 2, 3))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: Metrics.zoneBar)
        .background(Capsule().fill(Palette.ink.opacity(0.08)))
        .animation(Motion.number, value: aim)
        .accessibilityHidden(true)
    }
}

/// Строка зоны: цвет, название, что было в земле и доля.
struct ZoneRow: View {
    let zone: Almanac.Aim.Zone
    let aim: Almanac.Aim

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Palette.zone(zone))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.title)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                Text(zone.range)
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Stats.percent(aim.share(zone)))
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(Lang.format("%lld поливов", aim.count(zone)))
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Часы полива: сутки кругом, у каждого часа — лепесток длиной в число
/// поливов. Полночь сверху, полдень снизу, как на циферблате в 24 часа.
struct HourClock: View {
    let hours: [Int]

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = side * 0.2
            let outer = side * 0.5 - 12
            let most = CGFloat(max(hours.max() ?? 0, 1))
            let peak = hours.max() ?? 0
            let base = Path(ellipseIn: CGRect(x: middle.x - inner,
                                              y: middle.y - inner,
                                              width: inner * 2,
                                              height: inner * 2))
            context.stroke(base, with: .color(Palette.ink.opacity(0.12)),
                           lineWidth: 1)
            for hour in 0 ..< 24 {
                let angle = CGFloat(hour) / 24 * 2 * .pi - .pi / 2
                let reach = inner + (outer - inner)
                    * CGFloat(hours[hour]) / most
                let from = CGPoint(x: middle.x + cos(angle) * (inner + 3),
                                   y: middle.y + sin(angle) * (inner + 3))
                let to = CGPoint(x: middle.x + cos(angle) * max(reach, inner + 4),
                                 y: middle.y + sin(angle) * max(reach, inner + 4))
                var petal = Path()
                petal.move(to: from)
                petal.addLine(to: to)
                let lit = hours[hour] == peak && peak > 0
                context.stroke(petal,
                               with: .color(hours[hour] == 0
                                            ? Palette.ink.opacity(0.1)
                                            : lit ? Palette.accent
                                                : Palette.accent.opacity(0.45)),
                               style: StrokeStyle(lineWidth: side / 34,
                                                  lineCap: .round))
            }
            for (hour, label) in [(0, "0"), (6, "6"), (12, "12"), (18, "18")] {
                let angle = CGFloat(hour) / 24 * 2 * .pi - .pi / 2
                let point = CGPoint(x: middle.x + cos(angle) * (outer + 8),
                                    y: middle.y + sin(angle) * (outer + 8))
                context.draw(Text(label)
                                .font(Typography.figureCaption)
                                .foregroundStyle(.secondary),
                             at: point)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Дни недели столбиками, любимый — ярче.
struct WeekBars: View {
    let days: [Almanac.Weekday]

    var body: some View {
        let most = max(days.map(\.count).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(day.count == most && day.count > 0
                              ? Palette.accent
                              : Palette.accent.opacity(day.count == 0
                                                       ? 0.12 : 0.45))
                        .frame(height: max(CGFloat(day.count) / CGFloat(most)
                                           * Metrics.weekBars, 6))
                        .frame(height: Metrics.weekBars, alignment: .bottom)
                    Text(day.symbol)
                        .font(Typography.figureCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.name)
                .accessibilityValue(Lang.format("%lld поливов", day.count))
            }
        }
        .animation(Motion.number, value: days)
    }
}

/// Календарь поливов: столбец — неделя, клетка — день; чем больше поливов,
/// тем гуще цвет волны. Нажатая клетка обведена, её дата — в подписи.
struct WateringCalendar: View {
    let cells: [Almanac.Cell]
    let colour: Color
    @Binding var picked: Date?

    var body: some View {
        let weeks = stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0 ..< min($0 + 7, cells.count)])
        }
        let most = max(cells.map(\.count).max() ?? 0, 1)
        let today = cells.last?.day
        HStack(alignment: .top, spacing: 3) {
            ForEach(weeks.indices, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(weeks[week]) { cell in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cell.count == 0
                                  ? Palette.ink.opacity(0.07)
                                  : colour.opacity(0.3 + 0.7
                                      * Double(cell.count) / Double(most)))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if picked == cell.day || today == cell.day {
                                    RoundedRectangle(cornerRadius: 3,
                                                     style: .continuous)
                                        .strokeBorder(picked == cell.day
                                                      ? Palette.ink
                                                      : Palette.ink.opacity(0.35),
                                                      lineWidth: 1.5)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(Motion.pill) {
                                    picked = picked == cell.day ? nil : cell.day
                                }
                                Feel.pick()
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .animation(Motion.number, value: cells)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Календарь поливов")
        .accessibilityValue(Lang.format("%lld поливов",
                                        cells.reduce(0) { $0 + $1.count }))
    }
}

/// Слова и числа статистики, общие для её экранов.
enum Stats {
    static func percent(_ share: Double) -> String {
        Lang.format("%lld%%", Int((share * 100).rounded()))
    }

    /// «Сегодня», «Завтра», «Через 5 дней» — день сада от сейчас.
    static func day(_ offset: Int) -> String {
        switch offset {
        case ...0: Lang.text("Сегодня")
        case 1: Lang.text("Завтра")
        default: Lang.format("Через %@", Lang.format("%lld дней", offset))
        }
    }

    /// Клички через запятую; больше четырёх — «и ещё …».
    static func names(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case 2 ... 5:
            Lang.format("%1$@ и %2$@", names.dropLast().joined(separator: ", "),
                        names[names.count - 1])
        default:
            Lang.format("%1$@ и ещё %2$@", names.prefix(4).joined(separator: ", "),
                        Lang.format("%lld растений", names.count - 4))
        }
    }

    /// Час по-местному: у кого «19:00», у кого «7 PM».
    static func hour(_ hour: Int, calendar: Calendar = .current) -> String {
        let moment = calendar.date(bySettingHour: hour, minute: 0, second: 0,
                                   of: Date()) ?? Date()
        return moment.formatted(Date.FormatStyle(calendar: calendar,
                                                 timeZone: calendar.timeZone)
            .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Lang.locale))
    }

    /// Минута суток по-местному: «6:40» или «6:40 AM».
    static func time(_ minute: Int, calendar: Calendar = .current) -> String {
        let moment = calendar.date(bySettingHour: minute / 60,
                                   minute: minute % 60, second: 0,
                                   of: Date()) ?? Date()
        return moment.formatted(Date.FormatStyle(calendar: calendar,
                                                 timeZone: calendar.timeZone)
            .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Lang.locale))
    }

    /// Что значит обычный остаток воды при поливе.
    static func verdict(_ zone: Almanac.Aim.Zone) -> String {
        switch zone {
        case .early:
            Lang.text("Можно не спешить: земля ещё влажная, тени на карточке нет.")
        case .onTime:
            Lang.text("В самый раз: карточка как раз светится оранжевым.")
        case .lastMoment:
            Lang.text("Поздновато: карточка уже горит красным.")
        case .dry:
            Lang.text("Земля успевает пересохнуть — поливайте чуть раньше.")
        }
    }
}
