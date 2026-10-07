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

                // Не узнал — повтор и код-пароль; заблокирован — только
                // код-пароль: системный лист сам предложит его ввести.
                switch lock.trouble {
                case .missed?:
                    note(Lang.text("Не удалось распознать."))
                    Button("Попробовать ещё раз") {
                        Task { await lock.unlock() }
                    }
                    .buttonStyle(.glass)
                    .font(Typography.detail)
                    .disabled(lock.asking)
                    Button("Ввести код-пароль") {
                        Task { await lock.unlock() }
                    }
                    .font(Typography.settingNote)
                    .disabled(lock.asking)
                case .lockout?:
                    note(Lang.text("Слишком много попыток. Введите код-пароль."))
                    Button("Ввести код-пароль") {
                        Task { await lock.unlock() }
                    }
                    .buttonStyle(.glass)
                    .font(Typography.detail)
                    .disabled(lock.asking)
                case nil:
                    Button("Открыть") {
                        Task { await lock.unlock() }
                    }
                    .buttonStyle(.glass)
                    .font(Typography.detail)
                    .disabled(lock.asking)
                }
            }
            .padding(.horizontal, Metrics.contentMargin)
        }
        // Нажатия забирает себе, иначе сквозь замок можно ткнуть в карточку.
        .contentShape(Rectangle())
        .onTapGesture {}
        .task { await lock.unlock() }
        .animation(Motion.enter, value: lock.trouble)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.settingNote)
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
