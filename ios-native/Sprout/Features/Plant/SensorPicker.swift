import SwiftUI

/// Подключить датчик: Flower Care, что рядом по Bluetooth, и датчики
/// влажности из «Дома». Нажали — датчик привязан и сразу опрошен.
struct SensorPicker: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    private let sensors = Sensors.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    group(.flora, title: "Рядом по Bluetooth",
                          empty: sensors.denied
                            ? Lang.text("Нужен доступ к Bluetooth, чтобы найти датчик.")
                            : sensors.blind
                                ? Lang.text("Bluetooth выключен. Включите его в Пункте управления.")
                                : sensors.scanning
                                    ? Lang.text("Ищу… Поднесите телефон к горшку.")
                                    : Lang.text("Датчиков Flower Care не видно. Поднесите телефон ближе и поищите снова."),
                          settings: sensors.denied)
                    // Пока «Дом» не ответил, «нет» было бы неправдой: ищем,
                    // как по Bluetooth.
                    group(.home, title: "Из приложения «Дом»",
                          empty: sensors.homeless
                            ?? (sensors.asking && sensors.scanning
                                ? Lang.text("Ищу…")
                                : Lang.text("Датчиков в «Доме» не найдено. Добавьте датчик в приложении «Дом» или выберите из списка выше.")),
                          settings: sensors.homeDenied)
                    Text("Датчик в горшке показывает настоящую влажность земли: проценты растения берутся с него, а полив, замеченный датчиком, сам ложится в журнал.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background { SproutBackground() }
            .navigationTitle("Датчик влажности")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sensors.search()
                        Feel.pick()
                    } label: {
                        if sensors.scanning {
                            ProgressView()
                        } else {
                            Label("Искать снова", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(sensors.scanning)
                }
            }
        }
        .onAppear { sensors.search() }
        .onDisappear { sensors.stop() }
        .animation(Motion.number, value: sensors.found)
    }

    private func group(_ kind: Sensor.Kind, title: LocalizedStringKey,
                       empty: String, settings: Bool) -> some View {
        let found = sensors.found.filter { $0.kind == kind }
        return SproutGroup(title) {
            if found.isEmpty {
                Text(empty)
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if settings {
                    Button("Открыть Настройки", action: openSettings)
                        .buttonStyle(.glass)
                }
            }
            ForEach(Array(found.enumerated()), id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                Button { link(item.element) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind == .flora ? "sensor.fill"
                              : "homekit")
                            .font(Typography.settingRow)
                            .foregroundStyle(Palette.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.element.name)
                                .font(Typography.settingRow)
                                .foregroundStyle(Palette.ink)
                                .dataLines()
                            if let detail = item.element.detail {
                                // «Рядом / Далеко» — словом; децибелы —
                                // мелкой припиской для любопытных.
                                HStack(spacing: 6) {
                                    Text(detail)
                                        .font(Typography.settingNote)
                                        .foregroundStyle(Palette.secondaryText)
                                    if let signal = item.element.signal {
                                        Text(signal)
                                            .font(Typography.cardCaption)
                                            .foregroundStyle(Palette.secondaryText)
                                            .monospacedDigit()
                                    }
                                }
                                .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "plus.circle.fill")
                            .font(Typography.navTitle)
                            .foregroundStyle(Palette.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString)
        else { return }
        UIApplication.shared.open(url)
    }

    private func link(_ found: Sensors.Found) {
        garden.link(plantID, sensor: Sensor(kind: found.kind, id: found.id,
                                          name: found.name))
        sensors.stop()
        sensors.poll(plantID)
        Feel.done()
        dismiss()
    }
}
