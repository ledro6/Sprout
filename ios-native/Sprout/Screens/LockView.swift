import SwiftUI

/// Запертый сад — поверх всего, пока система не узнает хозяина. Ключ
/// спрашивает корень при каждом возвращении; кнопка — на случай отмены Face
/// ID.
struct LockView: View {
    private let lock = Lock.shared

    var body: some View {
        ZStack {
            SproutBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 72, height: 72)
                    .sproutPlate(in: Circle())

                Text("Сад заперт")
                    .font(Typography.welcome)
                    .foregroundStyle(Palette.ink)

                Button("Открыть") {
                    Task { await lock.unlock() }
                }
                .buttonStyle(.glass)
                .font(Typography.detail)
                .disabled(lock.asking)
            }
            .padding(.horizontal, Metrics.contentMargin)
        }
        // Нажатия забирает себе, иначе сквозь замок можно ткнуть в карточку.
        .contentShape(Rectangle())
        .onTapGesture {}
        .task { await lock.unlock() }
    }
}
