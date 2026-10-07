import SwiftUI

/// Как показать статус влажности: цвет из токенов `Palette`, значок SF
/// Symbols и слово. Пороги и слова — в модели (`MoistureStatus`); здесь
/// только цвет, чтобы значения токенов можно было менять в одном месте.
struct StatusStyle {
    let color: Color
    let symbol: String
    let word: String

    init(_ status: MoistureStatus) {
        color = Self.color(status.tone)
        symbol = status.symbol
        word = status.word
    }

    /// Единственное место, где тон статуса становится цветом.
    static func color(_ tone: MoistureStatus.Tone) -> Color {
        switch tone {
        case .water: Palette.water
        case .green: Palette.green
        case .warn: Palette.warn
        case .alarm: Palette.alarm
        case .secondary: Color.secondary
        }
    }
}

func statusStyle(_ status: MoistureStatus) -> StatusStyle {
    StatusStyle(status)
}

/// Статус строкой: значок цвета статуса и слово.
struct StatusLabel: View {
    let status: MoistureStatus

    var body: some View {
        let style = StatusStyle(status)
        Label {
            Text(style.word)
        } icon: {
            Image(systemName: style.symbol)
                .foregroundStyle(style.color)
        }
    }
}
