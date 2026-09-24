import Charts
import SwiftUI

/// Куда ведёт статистика: растение в статистике, планетарий, экран растения.
enum StatsRoute: Hashable {
    case book(Plant.ID)
    case orrery
    case plant(Plant.ID)
}

/// Статистика сверху вниз: период, сад сейчас, планетарий, итог, поливы по
/// дням, точность, привычки, прогноз, комнаты и растения. Считает
/// `Almanac`, экран только показывает.
struct StatsView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let settings = Settings.shared

    @State private var period: Almanac.Period = .week

    /// Итог — в состоянии, а не в теле: сад сохнет раз в секунду, и графики
    /// перерисовывались бы ежесекундно, срывая выбранный столбик.
    @State private var book = Almanac()

    @State private var path: [StatsRoute] = []

    @State private var pickedBar: Date?
    /// Дробью: ось прогноза числовая, и выбор приходит точкой на ней.
    @State private var pickedDay: Double?

    @State private var board: Board = .most

    /// Список растений: кого поливают чаще, кого реже, кто суше всех.
    enum Board: String, CaseIterable, Identifiable {
        case most, least, driest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .most: Lang.text("Чаще всех")
            case .least: Lang.text("Реже всех")
            case .driest: Lang.text("Суше всех")
            }
        }
    }

    /// Подписи осей для VoiceOver — ключами каталога.
    private static let dayAxis = LocalizedStringKey(Lang.key("День"))
    private static let countAxis = LocalizedStringKey(Lang.key("Поливов"))
    private static let levelAxis = LocalizedStringKey(Lang.key("Вода в земле"))
    private static let averageAxis = LocalizedStringKey(Lang.key("В среднем"))

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SproutHead("Статистика", walk: .stats)
                        VStack(alignment: .leading,
                               spacing: Metrics.groupGap) {
                            if book.plants.isEmpty && book.total == 0 {
                                blank
                            } else {
                                picker.hintSpot(.statsPeriod)
                                now.hintSpot(.statsNow)
                                NavigationLink(value: StatsRoute.orrery) {
                                    OrreryTeaser()
                                }
                                .buttonStyle(.plain)
                                .sproutRide()
                                .hintSpot(.statsOrrery)
                                summary.hintSpot(.statsSum)
                                waterings
                                aim.hintSpot(.statsAim)
                                habits
                                forecast.hintSpot(.statsAhead)
                                if !rooms.isEmpty { roomsGroup }
                                if !book.plants.isEmpty {
                                    plantsGroup.hintSpot(.statsPlants)
                                }
                            }
                        }
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
                .background { SproutBackground() }
                .sproutNotchCover()
                .toolbar(.hidden, for: .navigationBar)
                .walk(.stats, scroll: reader)
                .navigationDestination(for: StatsRoute.self) { route in
                    switch route {
                    case .book(let id): PlantBookView(plantID: id,
                                                      period: period)
                    case .orrery: OrreryView()
                    case .plant(let id): PlantView(plantID: id)
                    }
                }
            }
        }
        .onAppear { recount() }
        .onChange(of: garden.log.count) {
            withAnimation(Motion.number) { recount() }
        }
        .onChange(of: period) {
            pickedBar = nil
            withAnimation(Motion.number) { recount() }
            Feel.pick()
        }
        // Приложение могло простоять открытым через полночь.
        .onChange(of: phase) { _, now in
            if now == .active { recount() }
        }
        // Сад сохнет — «сейчас» и прогноз живые, но не ежесекундно.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                recount()
            }
        }
    }

    private func recount() {
        book = Almanac.of(garden.log, rooms: garden.rooms, period: period,
                          since: garden.since)
    }

    /// Цвет волны, а не узора: столбики считают поливы.
    private var colour: Color { Palette.swatch(settings.waveTint) }

    // MARK: - Пусто

    private var blank: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text("В саду пока пусто. Посадите первое растение во вкладке «Добавить» — и здесь появятся цифры.")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .sproutRide()
    }

    // MARK: - Период

    private var picker: some View {
        Picker("Период", selection: $period) {
            ForEach(Almanac.Period.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .sproutRide()
    }

    // MARK: - Сейчас

    private var now: some View {
        let state = book.now
        return SproutGroup("Сейчас") {
            HStack(spacing: 18) {
                ThirstRing(state) {
                    VStack(spacing: 0) {
                        Text(Stats.percent(state.content))
                            .font(Typography.figure)
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Text("Довольны")
                            .font(Typography.figureCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: Metrics.statRingSize,
                       height: Metrics.statRingSize)
                VStack(alignment: .leading, spacing: 10) {
                    legend(Palette.green, state.calm, Lang.text("Довольны"))
                    legend(Palette.warn, state.warn, Lang.text("Скоро пить"))
                    legend(Palette.alarm, state.alarm, Lang.text("Ждут воды"))
                }
            }
            MoistureStrip(levels: state.levels)
            if let average = state.average {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(nowLine(average: average, driest: state.driest))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                    TermHint(.moisture)
                }
            }
        }
        .sproutRide()
    }

    private func nowLine(average: Double, driest: String?) -> String {
        let line = Lang.format("Средняя влажность — %@.",
                               Stats.percent(average))
        guard let driest else { return line }
        return line + " " + Lang.format("Суше всех — %@.", driest)
    }

    private func legend(_ color: Color, _ count: Int,
                        _ title: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(count.formatted())
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Итог

    /// Сеткой, а не в строку: в строке из четырёх длинный ярлык ломается уже
    /// при обычном размере текста.
    private var summary: some View {
        SproutGroup("Итог") {
            Grid(alignment: .leading, horizontalSpacing: 12,
                 verticalSpacing: 18) {
                GridRow {
                    StatTile(value: book.total.formatted(),
                             caption: "Поливов",
                             note: changeNote, tone: changeTone,
                             icon: changeIcon)
                    StatTile(value: Lang.format("%1$lld из %2$lld",
                                                book.active, book.length),
                             caption: "Дней с поливом")
                }
                GridRow {
                    StatTile(value: book.streak.formatted(),
                             caption: "Череда, дней",
                             note: book.best > 0
                                 ? Lang.format("лучшая — %lld", book.best)
                                 : nil)
                    StatTile(value: book.aim.known > 0
                                 ? Stats.percent(book.aim.share(.onTime))
                                 : "—",
                             caption: "Вовремя")
                }
            }
        }
        .sproutRide()
    }

    private var changeNote: String? {
        guard let change = book.change else { return nil }
        guard change != 0 else { return Lang.text("как в прошлый раз") }
        return Lang.format("%@ к прошлому периоду",
                           change > 0 ? "+\(change)" : "−\(-change)")
    }

    private var changeTone: Color? {
        guard let change = book.change, change != 0 else { return nil }
        return change > 0 ? Palette.green : Palette.warn
    }

    private var changeIcon: String? {
        guard let change = book.change, change != 0 else { return nil }
        return change > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    // MARK: - Поливы по дням

    private var unit: Calendar.Component { book.byMonth ? .month : .day }

    private var waterings: some View {
        SproutGroup("Поливы") {
            VStack(alignment: .leading, spacing: 12) {
                Text(barCaption)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Motion.number, value: pickedBar)
                if book.total == 0 {
                    Text("За этот период поливов не было.")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                        .transition(.blurReplace)
                } else {
                    bars
                        .transition(.blurReplace)
                }
            }
        }
        .sproutRide()
    }

    /// Выбор приходит точкой на оси времени, столбик стоит за сутки или
    /// месяц — сводим к нему.
    private var chosenBar: Almanac.Bar? {
        guard let pickedBar else { return nil }
        return book.bars.first {
            calendar.isDate($0.start, equalTo: pickedBar, toGranularity: unit)
        }
    }

    private var average: Double {
        Double(book.total) / Double(max(book.bars.count, 1))
    }

    private var barCaption: String {
        if let bar = chosenBar {
            let date = book.byMonth
                ? bar.start.formatted(.dateTime.month(.wide).year())
                : bar.start.formatted(.dateTime.day().month(.wide))
            return bar.count == 0 ? Lang.format("%@ — без поливов", date)
                : Lang.format("%1$@ — %2$@", date,
                              Lang.format("%lld поливов", bar.count))
        }
        let figure = Lang.decimal(average)
        return book.byMonth ? Lang.format("В среднем %@ в месяц", figure)
            : Lang.format("В среднем %@ в день", figure)
    }

    private var bars: some View {
        Chart {
            ForEach(book.bars) { bar in
                BarMark(x: .value(Self.dayAxis, bar.start, unit: unit),
                        y: .value(Self.countAxis, bar.count))
                    .foregroundStyle(colour.opacity(
                        chosenBar == nil || chosenBar == bar ? 1 : 0.3))
                    .cornerRadius(4, style: .continuous)
            }
            if average > 0 {
                RuleMark(y: .value(Self.averageAxis, average))
                    .foregroundStyle(Palette.ink.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        // От нуля: обрезанная снизу ось раздувает разницу между днями.
        .chartYScale(domain: 0 ... book.tallest + 1)
        .chartYAxis {
            AxisMarks(position: .leading,
                      values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: strideUnit, count: strideCount)) { value in
                AxisValueLabel {
                    Text(value.as(Date.self).map(mark) ?? "")
                }
            }
        }
        .chartXSelection(value: $pickedBar)
        .chartOverlay { proxy in
            // Нажали на столбик — волна идёт из него.
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: chosenBar?.start) { _, day in
                        guard let day else { return }
                        splash(on: day, proxy: proxy, geometry: geometry)
                        Feel.pick()
                    }
            }
        }
        .frame(height: Metrics.chartHeight)
    }

    /// Неделя — каждый день буквой, месяц — раз в неделю числом, год —
    /// каждый месяц; долгое «всё время» — пореже.
    private var strideUnit: Calendar.Component { book.byMonth ? .month : .day }

    private var strideCount: Int {
        if book.byMonth { return max(1, book.bars.count / 6) }
        return book.period == .week ? 1 : 7
    }

    private func mark(_ date: Date) -> String {
        if book.byMonth {
            return book.bars.count > 12
                ? date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
                : date.formatted(.dateTime.month(.narrow))
        }
        return book.period == .week
            ? date.formatted(.dateTime.weekday(.narrow))
            : date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Место столбика — сумма трёх систем координат: области построения, вью
    /// и окна.
    private func splash(on day: Date, proxy: ChartProxy,
                        geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let plot = geometry[anchor]
        let window = geometry.frame(in: .global)
        guard let x = proxy.position(forX: day) else { return }
        Cheer.shared.queue(from: CGRect(x: window.minX + plot.minX + x - 6,
                                        y: window.minY + plot.minY,
                                        width: 12, height: plot.height))
    }

    // MARK: - Точность

    private var aim: some View {
        SproutGroup("Точность полива") {
            if let typical = book.aim.typical {
                VStack(alignment: .leading, spacing: 4) {
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
                }
                histogram(typical: typical)
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

    /// Корзины по десять процентов, цветом зоны; черта — обычный остаток.
    private func histogram(typical: Double) -> some View {
        Chart {
            ForEach(Array(book.aim.bins.enumerated()), id: \.offset) { item in
                let zone = Almanac.Aim.zone((Double(item.offset) + 0.5) / 10)
                BarMark(xStart: .value(Self.levelAxis,
                                       Double(item.offset * 10) + 0.8),
                        xEnd: .value(Self.levelAxis,
                                     Double(item.offset * 10 + 10) - 0.8),
                        y: .value(Self.countAxis, item.element))
                    .foregroundStyle(Palette.zone(zone))
                    .cornerRadius(3, style: .continuous)
            }
            RuleMark(x: .value(Self.levelAxis, typical * 100))
                .foregroundStyle(Palette.ink.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        }
        .chartXScale(domain: 0.0 ... 100.0)
        .chartXAxis {
            AxisMarks(values: [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]) { value in
                AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                AxisValueLabel {
                    Text(Stats.percent((value.as(Double.self) ?? 0) / 100))
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 110)
    }

    // MARK: - Привычки

    private var habits: some View {
        SproutGroup("Привычки") {
            if book.total == 0 {
                Text("Когда появятся поливы, здесь будет видно, в какие часы и дни вы поливаете.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 16) {
                    HourClock(hours: book.hours)
                        .frame(width: Metrics.hourClock,
                               height: Metrics.hourClock)
                    VStack(alignment: .leading, spacing: 16) {
                        StatTile(value: book.peakHour.map { Stats.hour($0) }
                                     ?? "—",
                                 caption: "Любимый час")
                        StatTile(value: book.peakDay?.name ?? "—",
                                 caption: "Любимый день")
                    }
                }
                WeekBars(days: book.weekdays)
            }
        }
        .sproutRide()
    }

    // MARK: - Прогноз

    private var chosenDay: Almanac.Ahead? {
        guard let pickedDay else { return nil }
        let offset = Int(pickedDay.rounded())
        return book.ahead.first { $0.offset == offset }
    }

    private var aheadCaption: String {
        if let day = chosenDay {
            return Lang.format("%1$@: %2$@", Stats.day(day.offset),
                               day.count == 0 ? Lang.text("никто не ждёт")
                                   : Stats.names(day.names))
        }
        let today = book.ahead.first?.count ?? 0
        return Lang.format("Сегодня ждут воды: %@",
                           Lang.format("%lld растений", today))
    }

    private var forecast: some View {
        SproutGroup("Прогноз") {
            VStack(alignment: .leading, spacing: 12) {
                Text(aheadCaption)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .animation(Motion.number, value: chosenDay?.offset)
                Chart(book.ahead) { day in
                    BarMark(xStart: .value(Self.dayAxis,
                                           Double(day.offset) - 0.36),
                            xEnd: .value(Self.dayAxis,
                                         Double(day.offset) + 0.36),
                            y: .value(Self.countAxis, day.count))
                        .foregroundStyle(Palette.water.opacity(
                            chosenDay == nil || chosenDay?.offset == day.offset
                                ? 1 : 0.3))
                        .cornerRadius(4, style: .continuous)
                }
                .chartXScale(domain: -0.5 ... Double(Almanac.horizon) - 0.5)
                .chartXSelection(value: $pickedDay)
                .chartXAxis {
                    AxisMarks(values: [0.0, 7.0,
                                       Double(Almanac.horizon - 1)]) { value in
                        AxisValueLabel(anchor: .top) {
                            Text(dayMark(Int((value.as(Double.self) ?? 0)
                                                .rounded())))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading,
                              values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                        AxisValueLabel()
                    }
                }
                .frame(height: 140)
                .onChange(of: chosenDay?.offset) { _, day in
                    if day != nil { Feel.pick() }
                }
            }
        }
        .sproutRide()
    }

    private func dayMark(_ offset: Int) -> String {
        switch offset {
        case 0: Lang.text("Сегодня")
        default: "+\(offset)"
        }
    }

    // MARK: - Комнаты

    /// Суше всех — первой: её и надо увидеть.
    private var rooms: [Almanac.RoomLine] {
        book.rooms.filter { $0.plants > 0 }
            .sorted { ($0.moisture ?? 1) < ($1.moisture ?? 1) }
    }

    private var roomsGroup: some View {
        SproutGroup("Комнаты") {
            ForEach(Array(rooms.enumerated()), id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                room(item.element, driest: item.offset == 0 && rooms.count > 1)
            }
        }
        .sproutRide()
    }

    private func room(_ room: Almanac.RoomLine, driest: Bool) -> some View {
        let level = room.moisture ?? 0
        let details = [Lang.format("%lld растений", room.plants),
                       Lang.format("%lld поливов", room.waterings)]
            + (room.onTime.map { [Lang.format("вовремя %@",
                                              Stats.percent($0))] } ?? [])
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(room.name)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if driest {
                    Text("Суше всех")
                        .font(Typography.figureCaption.weight(.semibold))
                        .foregroundStyle(Palette.alarm)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Palette.alarm.opacity(0.14)))
                }
                Spacer(minLength: 8)
                Text(Stats.percent(level))
                    .font(Typography.detail)
                    .foregroundStyle(Palette.level(level))
                    .contentTransition(.numericText())
            }
            Capsule()
                .fill(Palette.ink.opacity(0.08))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(Palette.level(level))
                            .frame(width: max(geometry.size.width * level, 8))
                    }
                }
            Text(details.joined(separator: " · "))
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
        }
        .animation(Motion.number, value: level)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Растения

    private var ranked: [Almanac.PlantLine] {
        switch board {
        case .most:
            book.plants.sorted {
                ($0.waterings, $1.name) > ($1.waterings, $0.name)
            }
        case .least:
            book.plants.sorted {
                ($0.waterings, $0.name) < ($1.waterings, $1.name)
            }
        case .driest:
            book.plants.sorted { $0.moisture < $1.moisture }
        }
    }

    private var plantsGroup: some View {
        SproutGroup("Растения") {
            Picker("Растения", selection: $board.animation(Motion.arrange)) {
                ForEach(Board.allCases) { board in
                    Text(board.title).tag(board)
                }
            }
            .pickerStyle(.segmented)
            ForEach(Array(ranked.prefix(5).enumerated()),
                    id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                NavigationLink(value: StatsRoute.book(item.element.id)) {
                    plant(item.offset + 1, item.element)
                }
                .buttonStyle(.plain)
                .transition(.blurReplace)
            }
            Text("Нажмите на растение — откроется его статистика.")
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
        }
        .sproutRide()
    }

    private func plant(_ place: Int, _ line: Almanac.PlantLine) -> some View {
        HStack(spacing: 12) {
            Text(place.formatted())
                .font(Typography.detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.name)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text([line.species, line.room].filter { !$0.isEmpty }
                        .joined(separator: " · "))
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(board == .driest ? Stats.percent(line.moisture)
                 : Lang.format("%lld поливов", line.waterings))
                .font(Typography.settingRow)
                .foregroundStyle(board == .driest
                                 ? Palette.level(line.moisture) : Palette.ink)
                .contentTransition(.numericText())
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
