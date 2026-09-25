import ActivityKit
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// Живые действия: «Обход сада» и отсчёт до отъезда — на экране блокировки,
// в Dynamic Island и в стопке на Apple Watch. Кнопки в них — команды из
// `LiveGarden.swift`: система выполняет их в приложении.

/// Подложка тёмная: на ней одинаково читается экран блокировки и в светлой
/// теме, и в тёмной, а Dynamic Island и так чёрный.
private enum Night {
    static let round = Color(red: 0.04, green: 0.13, blue: 0.11)
    static let trip = Color(red: 0.06, green: 0.08, blue: 0.2)
    static let sky = Color(red: 0.55, green: 0.72, blue: 1)
    static let sun = Color(red: 1, green: 0.8, blue: 0.32)
    /// Зелень галочки — светлее листа виджета: ей гореть на тёмном.
    static let done = Color(red: 0.42, green: 0.86, blue: 0.5)
}

// MARK: - Обход сада

struct RoundLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundAttributes.self) { context in
            RoundBanner(stops: context.state.stops)
                .activityBackgroundTint(Night.round.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let stops = context.state.stops
            let next = Round.next(stops)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Group {
                        if let next {
                            Ring(fraction: RoundBanner.fraction(stops)) {
                                Face(thumb: next.thumb, side: 36)
                            }
                        } else {
                            Tick(side: 46)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Count(stops: stops)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Tone.water)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        if let next {
                            Text(next.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(next.room)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Сад полит")
                                .font(.headline)
                            Text(Lang.format("Полито %1$lld из %2$lld",
                                             Round.watered(stops), stops.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        if let next {
                            RoundButtons(stop: next, wide: true)
                        }
                        Segments(stops: stops)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Tone.water)
            } compactTrailing: {
                if next == nil {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Night.done)
                } else {
                    Count(stops: stops)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Tone.water)
                }
            } minimal: {
                Ring(fraction: RoundBanner.fraction(stops), width: 2.5) {
                    Image(systemName: next == nil ? "checkmark" : "drop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(next == nil ? Night.done : Tone.water)
                }
            }
            .keylineTint(Tone.water)
        }
        .supplementalActivityFamilies([.small])
    }
}

/// Обход на экране блокировки: кто следующий, кнопки и полоска остановок.
/// В стопке на часах — одной строкой.
struct RoundBanner: View {
    let stops: [Round.Stop]

    @Environment(\.activityFamily) private var family

    static func fraction(_ stops: [Round.Stop]) -> Double {
        stops.isEmpty ? 1 : Double(Round.passed(stops)) / Double(stops.count)
    }

    var body: some View {
        switch family {
        case .small: small
        default: wide
        }
    }

    private var wide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let next = Round.next(stops) {
                    Ring(fraction: Self.fraction(stops)) {
                        Face(thumb: next.thumb, side: 42)
                    }
                    .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Обход сада")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(next.name)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(Lang.format("%1$@ · %2$@", next.room,
                                         Lang.format("%lld%%", next.percent)))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    .id(next.id)
                    .transition(.push(from: .trailing))
                    Spacer(minLength: 4)
                    RoundButtons(stop: next)
                } else {
                    Tick(side: 54)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Сад полит")
                            .font(.title3.weight(.bold))
                        Text(Lang.format("Полито %1$lld из %2$lld",
                                         Round.watered(stops), stops.count))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer(minLength: 0)
                }
            }
            Segments(stops: stops)
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var small: some View {
        HStack(spacing: 8) {
            if let next = Round.next(stops) {
                Ring(fraction: Self.fraction(stops), width: 2.5) {
                    Face(thumb: next.thumb, side: 27)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.name)
                        .font(.headline)
                        .lineLimit(1)
                    Count(stops: stops)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Tone.water)
                }
                Spacer(minLength: 2)
                Button(intent: WaterInRound(plant: next.id)) {
                    Image(systemName: "drop.fill")
                        .accessibilityLabel("Полил")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(Tone.water)
            } else {
                Tick(side: 36)
                Text("Сад полит")
                    .font(.headline)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
    }
}

/// «Пропустить» и «Полил» — команды: обход идёт дальше, приложение не
/// открывается. Сбоку от имени — кружками, как у системного таймера: подпись
/// на другом языке длиннее и съела бы имя; во всю ширину — с подписями.
private struct RoundButtons: View {
    let stop: Round.Stop
    var wide = false

    var body: some View {
        HStack(spacing: wide ? 10 : 8) {
            Button(intent: SkipInRound(plant: stop.id)) {
                if wide {
                    Label("Пропустить", systemImage: "forward.fill")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: "forward.fill")
                        .accessibilityLabel("Пропустить")
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(wide ? .capsule : .circle)
            .tint(.white)
            Button(intent: WaterInRound(plant: stop.id)) {
                if wide {
                    Label("Полил", systemImage: "drop.fill")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: "drop.fill")
                        .accessibilityLabel("Полил")
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(wide ? .capsule : .circle)
            .controlSize(wide ? .regular : .large)
            .tint(Tone.water)
        }
        .font(.subheadline.weight(.bold))
    }
}

/// «2/5» — пройдено из всех.
private struct Count: View {
    let stops: [Round.Stop]

    var body: some View {
        let passed = Round.passed(stops)
        Text(verbatim: "\(passed.formatted())/\(stops.count.formatted())")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(passed)))
            .accessibilityLabel(Lang.format("Полито %1$lld из %2$lld",
                                            Round.watered(stops), stops.count))
    }
}

/// Остановки обхода полоской: политые — синим, пропущенные — бледно,
/// следующая — ярче остальных.
private struct Segments: View {
    let stops: [Round.Stop]

    var body: some View {
        let next = Round.next(stops)?.id
        HStack(spacing: 4) {
            ForEach(stops) { stop in
                Capsule()
                    .fill(colour(stop, next: next))
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func colour(_ stop: Round.Stop, next: Plant.ID?) -> Color {
        switch stop.mark {
        case .watered: Tone.water
        case .skipped: .white.opacity(0.35)
        case .waiting: .white.opacity(stop.id == next ? 0.75 : 0.18)
        }
    }
}

/// Кольцо пройденного вокруг картинки или значка.
private struct Ring<Content: View>: View {
    let fraction: Double
    let width: CGFloat
    let content: Content

    init(fraction: Double, width: CGFloat = 3,
         @ViewBuilder content: () -> Content) {
        self.fraction = fraction
        self.width = width
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(Tone.water,
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content
        }
        .padding(width / 2)
    }
}

/// Растение кружком — картинкой из общей папки или листком.
private struct Face: View {
    let thumb: String?
    let side: CGFloat

    var body: some View {
        Group {
            if let thumb, let file = Store.thumbs?.appendingPathComponent(thumb),
               let image = UIImage(contentsOfFile: file.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: side * 0.42))
                    .foregroundStyle(Night.done)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Night.done.opacity(0.18))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Обход пройден.
private struct Tick: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Night.done.opacity(0.22))
            Image(systemName: "checkmark")
                .font(.system(size: side * 0.4, weight: .bold))
                .foregroundStyle(Night.done)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

// MARK: - Отъезд

struct TripLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripAttributes.self) { context in
            TripBanner(trip: context.attributes, state: context.state,
                       gone: context.isStale)
                .activityBackgroundTint(Night.trip.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let trip = context.attributes
            let state = context.state
            let gone = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Emblem(gone: gone, side: 46)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if gone {
                            Image(systemName: "hand.wave.fill")
                                .foregroundStyle(Night.sun)
                        } else {
                            Text(timerInterval: trip.span, countsDown: true)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Night.sky)
                        }
                    }
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: 110, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(gone ? "Хорошей поездки!" : "До отъезда")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(TripBanner.line(trip, state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Spacer(minLength: 4)
                            if !gone { WaterAll(watered: state.watered) }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "airplane.departure")
                    .foregroundStyle(Night.sky)
            } compactTrailing: {
                if gone {
                    Image(systemName: "hand.wave.fill")
                        .foregroundStyle(Night.sun)
                } else {
                    Text(timerInterval: trip.span, countsDown: true)
                        .monospacedDigit()
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 58, alignment: .trailing)
                        .foregroundStyle(Night.sky)
                }
            } minimal: {
                Image(systemName: gone ? "hand.wave.fill" : "airplane.departure")
                    .foregroundStyle(gone ? Night.sun : Night.sky)
            }
            .keylineTint(Night.sky)
        }
        .supplementalActivityFamilies([.small])
    }
}

extension TripAttributes {
    /// От включения до отъезда; отъезд раньше включения — пустой отрезок, а
    /// не падение.
    var span: ClosedRange<Date> { started ... max(started, leave) }
}

/// Отсчёт на экране блокировки: сколько осталось, полоска до отъезда,
/// «Полить всех» и кого поливать соседу. Уехали — пожелание и дата
/// возвращения.
struct TripBanner: View {
    let trip: TripAttributes
    let state: TripAttributes.ContentState
    let gone: Bool

    @Environment(\.activityFamily) private var family

    /// Когда вернусь и что соседу — одной строкой.
    static func line(_ trip: TripAttributes,
                     _ state: TripAttributes.ContentState) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.wide)
            .locale(Lang.locale)
        let back = Lang.format("Вернусь %@", trip.back.formatted(style))
        let neighbour: String
        if state.neighbour == 0 {
            neighbour = Lang.text("Все дождутся вас сами")
        } else if let visit = state.visit {
            neighbour = Lang.format("Соседу — %1$@, первый раз %2$@",
                                    Lang.format("%lld растений", state.neighbour),
                                    visit.formatted(style))
        } else {
            neighbour = Lang.format("Соседу — %@",
                                    Lang.format("%lld растений", state.neighbour))
        }
        return Lang.format("%1$@ · %2$@", back, neighbour)
    }

    var body: some View {
        switch family {
        case .small: small
        default: wide
        }
    }

    private var wide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Emblem(gone: gone, side: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text(gone ? "Хорошей поездки!" : "До отъезда")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    if gone {
                        Text(Lang.format("Вернусь %@", trip.back.formatted(
                            Date.FormatStyle.dateTime.day().month(.wide)
                                .locale(Lang.locale))))
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(timerInterval: trip.span, countsDown: true)
                            .font(.system(size: 30, weight: .bold,
                                          design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                Spacer(minLength: 4)
                if !gone { WaterAll(watered: state.watered) }
            }
            if !gone {
                ProgressView(timerInterval: trip.span, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(Night.sky)
            }
            Text(Self.line(trip, state))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var small: some View {
        HStack(spacing: 8) {
            Emblem(gone: gone, side: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(gone ? "Хорошей поездки!" : "До отъезда")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                if gone {
                    Text(trip.back.formatted(
                        Date.FormatStyle.dateTime.day().month(.abbreviated)
                            .locale(Lang.locale)))
                        .font(.headline)
                } else {
                    Text(timerInterval: trip.span, countsDown: true)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
    }
}

/// «Полить всех» перед отъездом; полили — галочка.
private struct WaterAll: View {
    let watered: Bool

    var body: some View {
        if watered {
            Label("Все политы", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Night.done)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Button(intent: WaterBeforeTrip()) {
                Label("Полить всех", systemImage: "drop.fill")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Tone.water)
        }
    }
}

/// Самолёт до отъезда, солнце — после.
private struct Emblem: View {
    let gone: Bool
    let side: CGFloat

    var body: some View {
        let tint = gone ? Night.sun : Night.sky
        ZStack {
            Circle()
                .fill(tint.opacity(0.22))
            Image(systemName: gone ? "sun.max.fill" : "airplane.departure")
                .font(.system(size: side * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
