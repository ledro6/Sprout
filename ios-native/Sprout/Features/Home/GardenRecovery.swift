import SwiftUI

/// Файл сада не читается: спрашиваем хозяина один раз. Сад не заменяется
/// молча — испорченный файл отложен в сторону, ничего не удалено.
struct GardenRecovery: ViewModifier {
    @Environment(Garden.self) private var garden

    func body(content: Content) -> some View {
        content.sheet(isPresented: shown) {
            RecoverySheet()
                .presentationDetents([.medium])
        }
    }

    private var shown: Binding<Bool> {
        Binding(get: { garden.damaged },
                set: { if !$0 { garden.dismissDamage() } })
    }
}

/// Два выбора: копия, если она есть, и пустой сад.
struct RecoverySheet: View {
    @Environment(Garden.self) private var garden

    /// Копия есть, но и она не читается.
    @State private var copyBroken = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Файл сада повреждён")
                .font(Typography.settingRow.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("Сад не открылся. Испорченный файл сохранён отдельно — ничего не удалено.")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if copyBroken {
                Text("Копия тоже не читается. Можно начать заново.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasCopy {
                Button("Восстановить из копии") {
                    copyBroken = !garden.restoreCopy()
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.accentFill)
            }
            Button("Начать заново", role: .destructive) { garden.startOver() }
                .buttonStyle(.glass)
        }
        .font(Typography.settingNote)
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasCopy: Bool {
        guard let copy = Store.copy else { return false }
        return FileManager.default.fileExists(atPath: copy.path)
    }
}
