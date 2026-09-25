import SwiftUI

struct AboutView: View {
    /// Из самого приложения: написанная руками версия разошлась бы с
    /// настоящей на первой же сборке.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        SproutPage(title: "Сведения о приложении") {
            HStack(spacing: 12) {
                SproutLogo(height: 44, aspect: SproutLogo.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sprout")
                        .font(Typography.navTitle)
                        .foregroundStyle(Palette.ink)
                    Text("Напоминалка о поливе комнатных растений")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SproutDivider()

            pair("Версия", version)
            pair("Система", Lang.text("iOS 26 и новее"))

            SproutDivider()

            Paragraph("Время идёт быстрее", body: """
                Час сада проходит здесь за секунду настоящего времени: иначе \
                за один сеанс проценты влажности не сдвинулись бы ни на один. \
                По этим же часам считаются и напоминания.
                """)

            Link(destination: URL(string: "https://github.com/ledro6/Sprout")!) {
                HStack(spacing: 8) {
                    Text("Исходный код на GitHub")
                        .font(Typography.settingRow)
                    Image(systemName: "arrow.up.right")
                        .font(Typography.settingNote)
                }
                .foregroundStyle(Palette.accent)
            }
        }
    }

    private func pair(_ name: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(Typography.settingRow)
                .foregroundStyle(.secondary)
        }
    }
}
