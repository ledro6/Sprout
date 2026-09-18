import SwiftUI

/// Запертый сад.
///
/// Закрывает приложение целиком, пока система не узнает хозяина. Узор под
/// ним тот же, что везде, — заперт сад, а не приложение превратилось в
/// чужой служебный экран.
///
/// Ключ спрашивается сам, как только экран появляется, и ещё раз при
/// каждом возвращении в приложение — это делает корень. Кнопка нужна на
/// случай отказа: отменил Face ID, передумал — спросить снова.
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
        // Нажатия забирает себе: под ним стоит собранный сад, и ткнуть в
        // карточку сквозь замок было бы можно.
        .contentShape(Rectangle())
        .onTapGesture {}
        .task { await lock.unlock() }
    }
}
