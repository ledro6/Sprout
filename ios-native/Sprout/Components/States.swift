import SwiftUI
import UIKit

/// Состояния, которые встречаются редко, но должны говорить по-человечески:
/// пусто, нет доступа, не вышло, ждёт отправки. Одна вёрстка на все —
/// значок, слова и одно-два действия, — чтобы редкое не выглядело чужим.
struct StateNote<Actions: View>: View {
    let icon: String
    let text: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
                .font(Typography.settingNote)
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Системные Настройки приложения: разрешения возвращают только там.
enum SystemSettings {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString)
        else { return }
        UIApplication.shared.open(url)
    }
}

/// Пустой сад: с чего начать.
struct EmptyGarden: View {
    let add: () -> Void
    /// «Показать пример» — сад-пример, пока растений нет.
    var sample: (() -> Void)?

    var body: some View {
        StateNote(icon: "leaf",
                  text: Lang.text("В саду пока пусто. Добавьте первое растение.")) {
            HStack(spacing: 10) {
                Button("Добавить", action: add)
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                if let sample {
                    Button("Показать пример", action: sample)
                }
            }
        }
    }
}

/// Нет доступа к камере или Bluetooth — что нужно и куда идти.
struct AccessNote: View {
    enum Need {
        case camera, bluetooth

        var text: String {
            switch self {
            case .camera:
                Lang.text("Нужен доступ к камере, чтобы сфотографировать растение.")
            case .bluetooth:
                Lang.text("Нужен доступ к Bluetooth, чтобы найти датчик.")
            }
        }

        var icon: String {
            switch self {
            case .camera: "camera"
            case .bluetooth: "antenna.radiowaves.left.and.right"
            }
        }
    }

    let need: Need

    var body: some View {
        StateNote(icon: need.icon, text: need.text) {
            Button("Открыть Настройки") { SystemSettings.open() }
        }
    }
}

/// Apple Intelligence нет — сказать честно, что делать, и что полив
/// работает и так. Сеть здесь ни при чём: модель — на телефоне.
struct ModelAbsent: View {
    var body: some View {
        StateNote(icon: "apple.intelligence",
                  text: Lang.text("Apple Intelligence выключена или недоступна на этом устройстве. Включите её в Настройках → Apple Intelligence и Siri; если пункта нет, телефон её не поддерживает. Полив и сад работают и без неё.")) {
            EmptyView()
        }
    }
}

/// Долгая работа с фото: что происходит и как передумать.
struct WorkingNote: View {
    var text = Lang.text("Разбираю фото…")
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(text)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
            Button("Отмена", action: cancel)
                .font(Typography.settingNote)
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Что-то не вышло — без подробностей, которые ничего не скажут, и с
/// повтором.
struct FailedNote: View {
    let retry: () -> Void

    var body: some View {
        StateNote(icon: "exclamationmark.circle",
                  text: Lang.text("Не получилось.")) {
            Button("Попробовать ещё раз", action: retry)
        }
    }
}

/// Сад не синхронизируется: плашка в «Семье», подробности — по нажатию.
struct SyncTrouble: View {
    let detail: String

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Сад не синхронизируется. Проверьте iCloud.",
                  systemImage: "exclamationmark.icloud")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.warn)
                .fixedSize(horizontal: false, vertical: true)
            if open {
                Text(detail)
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            } else {
                Button("Подробнее") {
                    withAnimation(Motion.enter) { open = true }
                }
                .font(Typography.settingNote)
                .frame(minHeight: 44)
            }
        }
    }
}

/// Полив общего сада, который ещё не ушёл в iCloud: записан на телефоне и
/// уйдёт, когда появится связь.
struct PendingBadge: View {
    var body: some View {
        Label("ожидает отправки", systemImage: "icloud.and.arrow.up")
            .font(Typography.cardCaption)
            .foregroundStyle(Palette.secondaryText)
    }
}

/// Правка главной: как менять порядок.
struct ReorderHint: View {
    var body: some View {
        Label("Перетащите, чтобы изменить порядок",
              systemImage: "hand.draw")
            .font(Typography.settingNote)
            .foregroundStyle(Palette.secondaryText)
            .frame(maxWidth: .infinity)
    }
}

private struct StatesGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                EmptyGarden(add: {}, sample: {})
                AccessNote(need: .camera)
                AccessNote(need: .bluetooth)
                ModelAbsent()
                WorkingNote(cancel: {})
                FailedNote(retry: {})
                SyncTrouble(detail: Lang.text("Нет связи с iCloud. Сад обновится, когда появится интернет."))
                PendingBadge()
                ReorderHint()
            }
            .padding(Metrics.contentMargin)
        }
        .background { SproutBackground() }
    }
}

#Preview("States, light") {
    StatesGallery()
}

#Preview("States, dark") {
    StatesGallery()
        .preferredColorScheme(.dark)
}
