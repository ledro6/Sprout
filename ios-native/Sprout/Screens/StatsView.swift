import Charts
import SwiftUI

/// Статистика: сколько полили, когда и кому доставалось чаще.
///
/// Считается из журнала поливов, а не из счётчиков, — см. `Score`. Экран
/// сам ничего не складывает: он спрашивает у сада готовый итог и
/// показывает его.
///
/// Собран из тех же плашек, что настройки, — `SproutGroup`, `SproutBlock`,
/// `SproutFigure`, — лежит на том же узоре и подпрыгивает на той же волне
/// полива. Сделать его «экраном с графиками» отдельно от остального
/// приложения было бы проще, но тогда это был бы другой продукт, приделанный
/// сбоку.
struct StatsView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    /// Цвет графика берётся из настроек — не в окружении, см. `Settings`.
    private let settings = Settings.shared

    /// Итог держим в состоянии, а не считаем в теле.
    ///
    /// Сад сушится раз в секунду, и тело, читающее `garden.rooms`,
    /// пересобиралось бы с той же частотой: график перерисовывался бы
    /// ежесекундно, а выбранный столбик срывался бы под пальцем. Поэтому в
    /// теле читается только длина журнала — она меняется ровно тогда, когда
    /// кого-то полили, — а сам пересчёт идёт в обработчике, куда
    /// наблюдение не достаёт.
    @State private var score = Score()

    /// Выбранный на графике день. Пусто — не выбран ни один.
    @State private var picked: Date?

    /// День, от которого уже пускали волну. Нужен, чтобы при протягивании
    /// пальца вдоль графика волна уходила на каждый новый столбик, а не на
    /// каждое движение.
    @State private var waved: Date?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SproutHead("Статистика")
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        if score.total == 0 {
                            blank
                        } else {
                            summary
                            fortnight
                            if !score.rooms.isEmpty { byRoom }
                            if !score.plants.isEmpty { byPlant }
                        }
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .background { SproutBackground() }
            .sproutNotchCover()
            // Панели сверху нет: заголовок раздела живёт в содержимом и
            // уезжает вместе с ним — как на главной.
            .toolbar(.hidden, for: .navigationBar)
        }
        // Пересчёт: при первом появлении, после каждого полива и при
        // возвращении в приложение. Последнее — из-за «сегодня»: приложение
        // может простоять открытым через полночь, и тогда вчерашние поливы
        // всё ещё числились бы сегодняшними.
        .onAppear { recount() }
        .onChange(of: garden.log.count) { _, _ in
            withAnimation(Motion.number) { recount() }
        }
        .onChange(of: phase) { _, now in
            if now == .active { recount() }
        }
    }

    private func recount() { score = garden.score() }

    /// Цвет графика — цвет волны полива из настроек.
    ///
    /// Её, а не цвета узора. Узор — фон, его дело быть еле заметным;
    /// волна — событие полива, и столбики графика ровно поливы и считают.
    /// Поменяли цвет волны в настройках — поменялся и график: это одно и то
    /// же событие, показанное дважды.
    private var colour: Color { Palette.swatch(settings.waveTint) }

    // MARK: - Пока пусто

    private var blank: some View {
        SproutGroup("Итог") {
            Paragraph("Пока ни одного полива. Полейте растение — долгим "
                      + "нажатием на карточку или кнопкой на его экране, — "
                      + "и здесь появится счёт.")
        }
        .sproutRide()
    }

    // MARK: - Итог

    /// Четыре числа сеткой два на два.
    ///
    /// Не рядом в строку: в строке из четырёх ярлык «За неделю» ломается
    /// на две строки уже при обычном размере текста, а при крупном
    /// разъезжается всё.
    private var summary: some View {
        SproutGroup("Итог") {
            Grid(alignment: .leading, horizontalSpacing: 12,
                 verticalSpacing: 18) {
                GridRow {
                    SproutFigure(score.total, "Всего")
                    SproutFigure(score.today, "Сегодня")
                }
                GridRow {
                    SproutFigure(score.week, "За неделю")
                    SproutFigure(score.streak, "Череда, дней",
                                 note: score.best > 0
                                     ? "лучшая — \(score.best)" : nil)
                }
            }
        }
        .sproutRide()
    }

    // MARK: - Две недели

    /// Столбики по дням за две недели.
    ///
    /// Пустые дни в ряду тоже есть — их ставит `Score`. Без них график
    /// врал бы о промежутках: три полива подряд и три полива за месяц
    /// выглядели бы одинаково.
    private var fortnight: some View {
        SproutGroup("Две недели") {
            VStack(alignment: .leading, spacing: 12) {
                Text(dayCaption)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .animation(Motion.number, value: picked)
                chart
            }
        }
        .sproutRide()
    }

    /// Подпись над графиком: что за столбик выбран. Не выбран — подсказка,
    /// что по нему можно нажать.
    private var dayCaption: String {
        guard let chore = chosen else { return "Нажмите на столбик" }
        let day = chore.day.formatted(.dateTime.day().month(.wide))
        guard chore.count > 0 else { return "\(day) — не поливали" }
        let unit = Plant.plural(chore.count, "полив", "полива", "поливов")
        return "\(day) — \(chore.count) \(unit)"
    }

    /// Выбранный столбик. Выбор приходит точкой на оси времени, а столбик
    /// стоит за целые сутки, — сводим их по дню.
    private var chosen: Chore? {
        guard let picked else { return nil }
        return score.days.first { calendar.isDate($0.day, inSameDayAs: picked) }
    }

    private var chart: some View {
        Chart(score.days) { chore in
            BarMark(
                x: .value("День", chore.day, unit: .day),
                y: .value("Поливов", chore.count)
            )
            // Выбранный столбик остаётся в полную силу, остальные глохнут.
            // Пока не выбран ни один — все в полную.
            .foregroundStyle(colour.opacity(faded(chore) ? 0.3 : 1))
            .cornerRadius(4, style: .continuous)
            .accessibilityLabel(chore.day.formatted(.dateTime.day().month()))
            .accessibilityValue("\(chore.count)")
        }
        // Ось значений от нуля: у столбиков она иначе и не бывает —
        // обрезанная снизу, она раздувает разницу между соседними днями.
        .chartYScale(domain: 0 ... ceiling)
        .chartYAxis {
            AxisMarks(position: .leading,
                      values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartXSelection(value: $picked)
        .chartOverlay { proxy in
            // Нажали на столбик — по узору расходится волна из него же.
            // Тот же приём, что у выбора цвета в настройках: показать
            // выбранное там, где его выбрали.
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: chosen?.day) { _, day in
                        guard let day, waved != day else { return }
                        waved = day
                        splash(on: day, proxy: proxy, geometry: geometry)
                        // Щелчок, а не отклик полива: столбик выбирают, а
                        // не поливают, и двухсекундный гул под пальцем,
                        // ведущим вдоль графика, был бы не к месту.
                        Feel.pick()
                    }
            }
        }
        .frame(height: 170)
    }

    /// Потолок оси. Своё число, а не автоматическое: у одного полива в день
    /// автоматический потолок вставал на единицу, и все столбики упирались
    /// в верх плашки.
    private var ceiling: Int {
        (score.days.map(\.count).max() ?? 0) + 1
    }

    private func faded(_ chore: Chore) -> Bool {
        guard let chosen else { return false }
        return chosen.day != chore.day
    }

    /// Пустить волну из выбранного столбика.
    ///
    /// Место столбика знает сам график: `position(forX:)` отдаёт его в
    /// координатах области построения, а та лежит внутри вью, а вью — в
    /// окне. Волна отсчитывается от угла окна, поэтому складываем все три.
    ///
    /// В очередь, а не поверх: палец можно вести вдоль графика, и каждый
    /// новый столбик ставил бы свою волну — они пойдут друг за другом.
    private func splash(on day: Date, proxy: ChartProxy,
                        geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let plot = geometry[anchor]
        let window = geometry.frame(in: .global)
        guard let x = proxy.position(forX: day) else { return }
        // Ширина столбика волне не нужна — нужна точка, из которой она
        // пойдёт; берём узкую полосу по всей высоте области.
        let bar = CGRect(x: window.minX + plot.minX + x - 6,
                         y: window.minY + plot.minY,
                         width: 12, height: plot.height)
        Cheer.shared.queue(from: bar)
    }

    // MARK: - По комнатам

    /// Полосы по комнатам: название, сама полоса и число над ней.
    ///
    /// Своими руками, а не графиком, и это отступление намеренное.
    /// Горизонтальный `BarMark` с подписями по оси и числом за концом
    /// полосы выглядел на телефоне плохо: подписи комнат система рисует
    /// вполсилы, и на светлом узоре они тонули, а число за концом полосы
    /// обрезалось краем плашки, сколько запаса ни давай. Здесь же ровно
    /// три строки, каждая из подписи, дорожки и заполнения, — графику тут
    /// нечего добавить, кроме своих полей.
    private var byRoom: some View {
        SproutGroup("По комнатам") {
            VStack(alignment: .leading, spacing: Metrics.rowGap) {
                ForEach(score.rooms) { tally in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(tally.name)
                                .font(Typography.settingRow)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(tally.count)")
                                .font(Typography.settingRow)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        bar(share(tally))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .sproutRide()
    }

    /// Дорожка и заполнение поверх неё.
    ///
    /// Дорожка нужна: без неё у комнаты с одним поливом полосы почти нет, и
    /// строка читается пустой, а не малой.
    private func bar(_ share: Double) -> some View {
        Capsule()
            .fill(Palette.ink.opacity(0.08))
            .frame(height: 10)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(colour)
                        // Не меньше высоты: короче капсула вырождается в
                        // точку и перестаёт читаться полосой.
                        .frame(width: max(geometry.size.width * share, 10))
                }
            }
            .animation(Motion.number, value: share)
    }

    /// Какую долю от самой политой комнаты занимает эта.
    private func share(_ tally: Tally) -> Double {
        let most = score.rooms.map(\.count).max() ?? 0
        guard most > 0 else { return 0 }
        return Double(tally.count) / Double(most)
    }

    /// Кому достаётся чаще: пятёрка, а не весь сад.
    ///
    /// Пятёрка потому, что это список победителей, а не перепись: три
    /// десятка строк тут никто не дочитает, а нижние из них всё равно
    /// отличались бы на один полив.
    private var byPlant: some View {
        SproutGroup("Кому достаётся больше") {
            VStack(alignment: .leading, spacing: Metrics.rowGap) {
                ForEach(Array(score.plants.prefix(5).enumerated()),
                        id: \.element.id) { item in
                    if item.offset > 0 { SproutDivider() }
                    HStack(spacing: 10) {
                        Text("\(item.offset + 1)")
                            .font(Typography.figureCaption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, alignment: .trailing)
                        Text(item.element.name)
                            .font(Typography.settingRow)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(item.element.count)")
                            .font(Typography.settingRow)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .sproutRide()
    }
}
