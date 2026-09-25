import SwiftUI

/// Кого полить — все растения сада от самого сухого, у каждого кольцо
/// влажности цвета его тени. Нажатие — растение и кнопка «Полить».
struct GardenList: View {
    private let band = Wristband.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Кого полить")
                .navigationDestination(for: String.self) { id in
                    PotPage(id: id)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let wrist = band.wrist, !wrist.pots.isEmpty {
            List {
                if wrist.thirsty.isEmpty {
                    Label("Все политы", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(WristTone.done)
                        .listRowBackground(Color.clear)
                }
                ForEach(wrist.pots) { pot in
                    NavigationLink(value: pot.id) {
                        PotRow(pot: pot)
                    }
                }
            }
            .animation(.smooth, value: wrist.pots.map(\.id))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(WristTone.done)
                Text(band.wrist == nil ? "Откройте Sprout — и сад появится здесь."
                     : "В саду пока пусто.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

/// Строка списка: кольцо с процентом, кличка и комната.
private struct PotRow: View {
    let pot: Wrist.Pot

    var body: some View {
        HStack(spacing: 10) {
            Dial(moisture: pot.moisture, width: 4) {
                Text(pot.percent.formatted())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(pot.percent)))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(pot.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(pot.room)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Растение крупно: кольцо влажности, срок и «Полить». Полили — кольцо
/// наливается пружиной, часы отвечают стуком; кнопку жмёт и двойное касание
/// пальцами.
private struct PotPage: View {
    let id: String

    private let band = Wristband.shared

    @State private var poured = 0

    var body: some View {
        if let pot = band.wrist?.pots.first(where: { $0.id == id }) {
            ScrollView {
                VStack(spacing: 8) {
                    Dial(moisture: pot.moisture, width: 9) {
                        VStack(spacing: 0) {
                            Text(Lang.format("%lld%%", pot.percent))
                                .font(.system(size: 26, weight: .bold,
                                              design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(
                                    value: Double(pot.percent)))
                            Image(systemName: "drop.fill")
                                .font(.caption2)
                                .foregroundStyle(WristTone.water)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .animation(.spring(duration: 0.9, bounce: 0.3),
                               value: pot.moisture)
                    Text(pot.room)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pot.label)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                    Button {
                        band.water(pot.id)
                        poured += 1
                    } label: {
                        Label("Полить", systemImage: "drop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WristTone.water)
                    .disabled(pot.moisture >= 0.99)
                    .handGestureShortcut(.primaryAction)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(pot.name)
            .sensoryFeedback(.success, trigger: poured)
        } else {
            Image(systemName: "leaf")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Кольцо влажности: наливается водой, цвет — тень карточки.
private struct Dial<Label: View>: View {
    let moisture: Double
    let width: CGFloat
    let label: Label

    init(moisture: Double, width: CGFloat, @ViewBuilder label: () -> Label) {
        self.moisture = moisture
        self.width = width
        self.label = label()
    }

    var body: some View {
        let tint = WristTone.of(Wrist.Level(moisture: moisture))
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.02, min(moisture, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: width,
                                                 lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .padding(width / 2)
    }
}

enum WristTone {
    static let water = Color(red: 0.25, green: 0.62, blue: 1)
    static let done = Color(red: 0.42, green: 0.86, blue: 0.5)

    static func of(_ level: Wrist.Level) -> Color {
        switch level {
        case .calm: water
        case .warn: .orange
        case .alarm: .red
        }
    }
}
