import SwiftUI

/// Погода под переключателем: что за окном и как это меняет сроки, или что
/// мешает её узнать. Ниже — знак Apple Weather и ссылка на источники:
/// WeatherKit требует показывать их рядом с погодой.
struct WeatherLine: View {
    @Environment(\.colorScheme) private var scheme

    private let settings = Settings.shared
    private let weatherman = Weatherman.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trouble = weatherman.trouble {
                Label(text(trouble), systemImage: "exclamationmark.triangle")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let climate = settings.climate, climate.fresh() {
                Label {
                    Text(Lang.format("%1$@ за окном. %2$@", climate.degrees,
                                     climate.line()
                                        ?? Lang.text("На сроки почти не влияет.")))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: climate.symbol)
                        .symbolRenderingMode(.multicolor)
                }
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
            } else if weatherman.busy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Узнаю погоду…")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
            }
            if let mark = weatherman.mark, let legal = weatherman.legal {
                HStack(spacing: 10) {
                    AsyncImage(url: scheme == .dark ? mark.dark : mark.light) {
                        image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(height: 12)
                    Link("Источники погоды", destination: legal)
                        .font(Typography.settingNote)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.number, value: weatherman.busy)
    }

    private func text(_ trouble: Weatherman.Trouble) -> String {
        switch trouble {
        case .place:
            Lang.text("Нет доступа к месту — разрешите его в Настройках → Sprout → Геопозиция. Хватит примерного.")
        case .service:
            Lang.text("Погода не пришла. Если приложение собрано из Xcode, добавьте ему возможность WeatherKit и включите службу WeatherKit у App ID.")
        }
    }
}
