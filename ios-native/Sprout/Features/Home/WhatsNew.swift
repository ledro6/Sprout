import SwiftUI

/// «Что нового» — один раз после смены версии: три-четыре строки о главном.
/// Свежей установке не показываем: её ведёт знакомство, а версию запоминаем
/// сразу. Пока идёт знакомство или экран заперт, лист не поднимаем. Закрыть
/// можно кнопкой «Понятно» или смахиванием — версия запоминается в обоих
/// случаях. Подключается к главной, см. `HomeView`.
struct WhatsNew: ViewModifier {
    @State private var showing = false

    private var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "—"
    }

    /// Показывать ли сейчас: знакомство пройдено, сад не заперт, версия
    /// сменилась, и это не свежая установка.
    private var due: Bool {
        let settings = Settings.shared
        let locked = Lock.shared.on && !Lock.shared.open
        guard let seen = settings.seenVersion else {
            return false
        }
        return settings.toured
            && Launch.shared.step >= Launch.last
            && !locked
            && seen != current
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: adopt)
            // Знакомство гасится с задержкой: его обложка ещё уходит, и лист
            // поверх неё молча бы пропал.
            .task(id: due) {
                guard due else { return }
                try? await Task.sleep(for: .seconds(0.7))
                if due { showing = true }
            }
            .sheet(isPresented: $showing, onDismiss: remember) {
                WhatsNewSheet()
            }
    }

    /// Свежая установка: версия запоминается, лист не нужен.
    private func adopt() {
        let settings = Settings.shared
        if settings.seenVersion == nil, !settings.toured {
            settings.seenVersion = current
        }
    }

    private func remember() {
        Settings.shared.seenVersion = current
    }
}

private struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Что нового")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Полив не перельётся: «Полить всех» пропускает влажные растения, а влажную землю приложение переспросит.")
                    Text("На растении видно, почему оно сухо или скоро попросит воды.")
                    Text("Дату записи в журнале поливов можно поменять: «Изменить дату…».")
                    Text("Паузу напоминаний можно поставить до выбранного дня: для всего сада или одной комнаты.")
                }
                .font(.body)
                Spacer(minLength: 0)
                Button("Понятно") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(Metrics.margin)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { SproutBackground() }
        }
    }
}
