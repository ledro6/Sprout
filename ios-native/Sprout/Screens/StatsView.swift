import SwiftUI

/// Статистика — заглушка: раздел переделывается. Прежний экран с графиками
/// лежит в истории репозитория, считает по-прежнему `Score`.
struct StatsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SproutHead("Статистика")
                    placeholder
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                }
            }
            .background { SproutBackground() }
            .sproutNotchCover()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text("Статистика скоро вернётся в новом виде.")
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
}
