import Charts
import SwiftUI

/// Статистика: сколько полили, когда и кому доставалось чаще. Считает
/// `Score`, экран только показывает.
struct StatsView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let settings = Settings.shared

    /// Итог — в состоянии, а не в теле: сад сушится раз в секунду, и график
    /// перерисовывался бы ежесекундно, срывая выбранный столбик. Тело читает
    /// только длину журнала.
    @State private var score = Score()

    @State private var picked: Date?

    /// Волна уходит на каждый новый столбик под пальцем, а не на каждое
    /// движение.
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
                                .transition(.blurReplace)
                        } else {
                            summary
                                .transition(.blurReplace)
                            fortnight
                            if !score.rooms.isEmpty {
                                byRoom.transition(.blurReplace)
                            }
                            if !score.plants.isEmpty {
                                byPlant.transition(.blurReplace)
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
        }
        // Пересчёт и при возвращении в приложение: оно могло простоять
        // открытым через полночь.
        .onAppear { recount() }
        .onChange(of: garden.log.count) { _, _ in
            withAnimation(Motion.number) { recount() }
        }
        .onChange(of: phase) { _, now in
            if now == .active { recount() }
        }
    }

    private func recount() { score = garden.score() }

    /// Цвет волны, а не узора: столбики считают поливы.
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

    /// Сеткой, а не в строку: в строке из четырёх ярлык «За неделю» ломается
    /// уже при обычном размере текста.
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

    private var dayCaption: String {
        guard let chore = chosen else { return "Нажмите на столбик" }
        let day = chore.day.formatted(.dateTime.day().month(.wide))
        guard chore.count > 0 else { return "\(day) — не поливали" }
        let unit = Plant.plural(chore.count, "полив", "полива", "поливов")
        return "\(day) — \(chore.count) \(unit)"
    }

    /// Выбор приходит точкой на оси времени, столбик стоит за сутки — сводим
    /// по дню.
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
            .foregroundStyle(colour.opacity(faded(chore) ? 0.3 : 1))
            .cornerRadius(4, style: .continuous)
            .accessibilityLabel(chore.day.formatted(.dateTime.day().month()))
            .accessibilityValue("\(chore.count)")
        }
        // От нуля: обрезанная снизу ось раздувает разницу между днями.
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
            // Нажали на столбик — волна идёт из него.
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: chosen?.day) { _, day in
                        guard let day, waved != day else { return }
                        waved = day
                        splash(on: day, proxy: proxy, geometry: geometry)
                        // Щелчок, а не гул полива: столбик выбирают, а не
                        // поливают.
                        Feel.pick()
                    }
            }
        }
        .frame(height: 170)
    }

    /// Своё число: у одного полива в день автоматический потолок вставал на
    /// единицу, и столбики упирались в верх.
    private var ceiling: Int {
        (score.days.map(\.count).max() ?? 0) + 1
    }

    private func faded(_ chore: Chore) -> Bool {
        guard let chosen else { return false }
        return chosen.day != chore.day
    }

    /// Место столбика — сумма трёх систем координат: области построения, вью
    /// и окна. В очередь: палец ведут вдоль графика.
    private func splash(on day: Date, proxy: ChartProxy,
                        geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let plot = geometry[anchor]
        let window = geometry.frame(in: .global)
        guard let x = proxy.position(forX: day) else { return }
        let bar = CGRect(x: window.minX + plot.minX + x - 6,
                         y: window.minY + plot.minY,
                         width: 12, height: plot.height)
        Cheer.shared.queue(from: bar)
    }

    // MARK: - По комнатам

    /// Полосы своими руками, а не `BarMark`: подписи комнат система рисует
    /// вполсилы, и число за концом полосы обрезалось краем плашки.
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
                    .transition(.blurReplace)
                }
            }
        }
        .sproutRide()
    }

    /// Дорожка нужна: без неё строка с одним поливом читается пустой.
    private func bar(_ share: Double) -> some View {
        Capsule()
            .fill(Palette.ink.opacity(0.08))
            .frame(height: 10)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(colour)
                        // Короче высоты капсула вырождается в точку.
                        .frame(width: max(geometry.size.width * share, 10))
                }
            }
            .animation(Motion.number, value: share)
    }

    private func share(_ tally: Tally) -> Double {
        let most = score.rooms.map(\.count).max() ?? 0
        guard most > 0 else { return 0 }
        return Double(tally.count) / Double(most)
    }

    /// Пятёрка, а не весь сад: это список победителей, а не перепись.
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
                            .contentTransition(.numericText())
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
                    .transition(.blurReplace)
                }
            }
        }
        .sproutRide()
    }
}
