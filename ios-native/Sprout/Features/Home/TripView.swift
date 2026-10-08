import SwiftUI

/// «Уезжаю»: даты поездки, кто дождётся, а кого полить соседу и в какие
/// дни. Считается так, будто перед отъездом полили всех, — поэтому первая
/// кнопка именно это и делает. Памятку соседу отдаёт системный лист
/// «Поделиться».
struct TripView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var leave = Trip.departure()
    @State private var back = Calendar.current.date(
        byAdding: .day, value: 8, to: Date()) ?? Date()

    /// Полили перед отъездом — кнопка гаснет, чтобы не лить второй раз.
    @State private var watered = false

    @State private var replanning: Task<Void, Never>?

    @State private var button = Spot()

    private var days: Int { Trip.days(from: leave, to: back) }

    private var needs: [Trip.Need] { Trip.needs(in: garden.rooms, days: days) }

    /// Вернуться раньше, чем уехал, нельзя: подпись под полем, кнопки гаснут.
    private var backward: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: back) < calendar.startOfDay(for: leave)
    }

    /// Кому пора пить перед отъездом: «скоро» и «сухо». Влажных и тех, кто в
    /// порядке, массовый полив не трогает.
    private var thirsty: [Plant] {
        MoistureStatus.bulk(garden.rooms.flatMap(\.plants))
    }

    /// Остальные: не в поливе и не в списке соседу — дождутся сами.
    private var rest: Int {
        let all = garden.rooms.flatMap(\.plants).map(\.id)
        let busy = Set(thirsty.map(\.id)).union(needs.map(\.plant.id))
        return all.filter { !busy.contains($0) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        dates
                            .hintSpot(.tripDates)
                        plan
                            .hintSpot(.tripPlan)
                        actions
                            .hintSpot(.tripActions)
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
                .background { SproutBackground() }
                // Плашка «Вернуть» — вставкой в нижнюю зону листа.
                .sproutUndo()
                .walk(.trip, scroll: reader)
            }
            .navigationTitle("Уезжаю")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .animation(Motion.enter, value: needs.map(\.plant.id))
        // Идёт отсчёт — «Уезжаю» открывается на его поездке.
        .onAppear {
            if let plan = Live.shared.plan {
                leave = plan.leave
                back = plan.back
            }
        }
        .onChange(of: leave) { _, _ in
            replan()
        }
        .onChange(of: back) { _, _ in replan() }
    }

    private var dates: some View {
        SproutGroup("Когда") {
            // Со временем: до него идёт отсчёт на экране блокировки.
            DatePicker("Уезжаю", selection: $leave, in: Date()...,
                       displayedComponents: [.date, .hourAndMinute])
                .font(Typography.settingRow)
            SproutDivider()
            DatePicker("Вернусь", selection: $back, in: Date()...,
                       displayedComponents: .date)
                .font(Typography.settingRow)
            if backward {
                Label("Возвращение не может быть раньше отъезда.",
                      systemImage: "exclamationmark.circle")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            } else {
                Text(Lang.format("Поездка — %lld дней", days))
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .contentTransition(.numericText())
            }
        }
        .sproutRide()
    }

    @ViewBuilder
    private var plan: some View {
        if needs.isEmpty {
            SproutGroup("Сад") {
                Label("Соседу ничего не нужно",
                      systemImage: "checkmark.circle")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.blurReplace)
            .sproutRide()
        } else {
            SproutGroup("Кого полить соседу") {
                ForEach(Array(needs.enumerated()), id: \.element.plant.id) { item in
                    if item.offset > 0 { SproutDivider() }
                    visit(item.element)
                }
            }
            .transition(.blurReplace)
            .sproutRide()
        }
    }

    private func visit(_ need: Trip.Need) -> some View {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        let dates = need.visits.compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: leave)?
                .formatted(style)
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(need.plant.name)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Text(Lang.format("%1$@ · полить: %2$@", need.room,
                             dates.joined(separator: ", ")))
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Metrics.actionGap) {
            Button(action: waterAll) {
                Group {
                    if !thirsty.isEmpty {
                        Label(Lang.format("Полить тех, кому нужно перед отъездом (%lld)",
                                          thirsty.count),
                              systemImage: "drop.fill")
                    } else if watered {
                        Label("Все политы", systemImage: "checkmark")
                    } else {
                        Label("Поливать сейчас некого", systemImage: "checkmark")
                    }
                }
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.accentFill)
            .controlSize(.extraLarge)
            .disabled(thirsty.isEmpty || backward)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { button.rect = $0 }

            if rest > 0 {
                Text(Lang.format("Остальные (%lld) дождутся сами", rest))
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
            }

            if !needs.isEmpty && !backward {
                ShareLink(item: Trip.memo(needs, leave: leave, back: back)) {
                    Label("Отправить памятку соседу",
                          systemImage: "square.and.arrow.up")
                        .font(Typography.detail)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }

            countdown
        }
        .sproutRide()
    }

    /// Отсчёт до отъезда — живое действие на экране блокировки и в Dynamic
    /// Island, с кнопкой «Полить всех». Живёт оно восемь часов, поэтому до
    /// дальнего отъезда появляется само, за восемь часов до него.
    @ViewBuilder
    private var countdown: some View {
        let live = Live.shared
        if live.enabled && !backward {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    if live.counting {
                        Task { await live.endTrip() }
                    } else {
                        Task { await live.startTrip(leave: leave, back: back) }
                        Feel.done()
                    }
                } label: {
                    Group {
                        if live.counting {
                            Label("Убрать отсчёт", systemImage: "timer")
                        } else {
                            Label("Отсчёт на экране блокировки",
                                  systemImage: "timer")
                        }
                    }
                    .font(Typography.detail)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                if leave.timeIntervalSinceNow > Trip.countdownSpan {
                    Text("Отсчёт появится на экране блокировки за 8 часов до отъезда.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Даты поменяли, пока идёт отсчёт, — он переходит на новые. Не на каждый
    /// оборот барабана: секунда тишины — и только тогда.
    private func replan() {
        guard Live.shared.counting else { return }
        replanning?.cancel()
        let leave = leave
        let back = back
        replanning = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await Live.shared.startTrip(leave: leave, back: back)
        }
    }

    /// Всех разом, одной плашкой «Вернуть» на восемь секунд: на каждое
    /// растение плашка была бы очередью. Только кому пора пить — влажные и
    /// в норме не участвуют. Список соседу пересчитывается сам: он
    /// считается из сада.
    private func waterAll() {
        guard Bin.shared.waterNeeded(in: garden) > 0 else { return }
        withAnimation(Motion.appear) { watered = true }
        Cheer.shared.now(from: button.rect)
        Feel.water()
        Cabinet.shared.deed(.traveler)
    }
}
