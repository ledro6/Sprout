import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// «Данные и поддержка» в Настройках: забрать журнал поливов, написать нам,
/// удалить всё. Удаление — вводом слова, см. `TypedConfirm`.
struct DataGroup: View {
    // Сад — общий, а не из окружения: настройки открываются листом из
    // трёх мест.
    private var garden: Garden { Garden.shared }

    @State private var wiping = false
    @State private var working = false
    @State private var trouble: String?
    @State private var wiped = false

    var body: some View {
        SproutGroup("Данные и поддержка") {
            Menu {
                ShareLink(item: JournalCSV(log: garden.log, places: places),
                          preview: SharePreview(Lang.text("Журнал поливов, CSV"))) {
                    Label("Таблица CSV", systemImage: "tablecells")
                }
                ShareLink(item: JournalJSON(log: garden.log, places: places),
                          preview: SharePreview(Lang.text("Журнал поливов, JSON"))) {
                    Label("Файл JSON", systemImage: "curlybraces")
                }
            } label: {
                SproutLink("Экспортировать журнал", icon: "square.and.arrow.up")
            }
            .disabled(garden.log.isEmpty)

            SproutDivider()

            Button(action: write) {
                SproutLink("Написать нам", icon: "envelope")
            }
            .buttonStyle(.plain)

            SproutDivider()

            Button(role: .destructive) { wiping = true } label: {
                HStack(spacing: 12) {
                    if working {
                        ProgressView()
                            .frame(width: 24)
                    } else {
                        Image(systemName: "trash")
                            .font(Typography.settingRow)
                            .frame(width: 24)
                    }
                    Text("Удалить все данные")
                        .font(Typography.settingRow)
                    Spacer(minLength: 8)
                }
                .foregroundStyle(.red)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(working)

            if let trouble {
                Text(trouble)
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            }

            Text("Сад попадает и в резервную копию iPhone — по правилам Apple, вместе с остальными данными телефона.")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(Motion.enter, value: trouble)
        .sheet(isPresented: $wiping) {
            TypedConfirm(
                title: Lang.text("Удалить все данные?"),
                message: Self.warning,
                prompt: Lang.text("Введите «удалить»"),
                answer: Lang.text("удалить"),
                done: Lang.text("Удалить всё")) {
                Task { await wipe() }
            }
        }
        .fullScreenCover(isPresented: $wiped) {
            WipedView()
        }
    }

    private var places: [Plant.ID: Export.Place] {
        Export.places(garden.rooms)
    }

    /// Что исчезнет — и у кого, если сад общий.
    private static var warning: String {
        let all = Lang.text("Исчезнут растения, журнал поливов, снимки, настройки, друзья и награды. Вернуть их будет нельзя.")
        guard Kinship.enabled else { return all }
        let kin = Kinship.shared
        if kin.mode == .guest {
            return all + "\n\n" + Lang.text("Вы выйдете из общего сада. Сам сад останется у хозяина.")
        }
        if kin.sharing {
            return all + "\n\n" + Lang.text("Сад удалится и из iCloud — у всех, кого вы пригласили, его тоже не станет.")
        }
        if kin.mode == .own {
            return all + "\n\n" + Lang.text("Сад удалится и из вашего iCloud.")
        }
        return all
    }

    /// Сперва iCloud: не вышло — на телефоне ничего не стираем.
    private func wipe() async {
        working = true
        trouble = nil
        if Kinship.enabled, let problem = await Kinship.shared.wipe() {
            working = false
            trouble = problem
            Feel.wrong()
            return
        }
        Wipe.local()
        working = false
        wiped = true
    }

    /// Письмо с версией приложения и iOS — и только: ни сада, ни имени.
    /// Адреса поддержки нет — тот же текст уходит в обсуждения на GitHub.
    private func write() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        let body = "\n\n—\n" + Lang.format("Sprout %1$@ (%2$@), iOS %3$@",
                                            version, build,
                                            UIDevice.current.systemVersion)
        var parts = URLComponents()
        if let address = Support.address {
            parts.scheme = "mailto"
            parts.path = address
            parts.queryItems = [URLQueryItem(name: "subject", value: "Sprout"),
                                URLQueryItem(name: "body", value: body)]
        } else {
            parts = URLComponents(string: Support.issues) ?? URLComponents()
            parts.queryItems = [URLQueryItem(name: "body", value: body)]
        }
        guard let url = parts.url else { return }
        UIApplication.shared.open(url)
    }
}

/// Куда писать. Почты поддержки пока нет — тогда «Написать нам» открывает
/// новое обсуждение на GitHub; впишите адрес, и откроется письмо.
enum Support {
    static let address: String? = nil
    static let issues = "https://github.com/ledro6/Sprout/issues/new"
}

/// Журнал таблицей — для листа «Поделиться». Строки собираются в миг
/// отправки, а не при каждой перерисовке настроек.
struct JournalCSV: Transferable {
    let log: [Watering]
    let places: [Plant.ID: Export.Place]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(Export.csv(Export.rows(file.log, places: file.places)).utf8)
        }
        .suggestedFileName("Sprout.csv")
    }
}

/// Журнал файлом JSON.
struct JournalJSON: Transferable {
    let log: [Watering]
    let places: [Plant.ID: Export.Place]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            Export.json(Export.rows(file.log, places: file.places))
        }
        .suggestedFileName("Sprout.json")
    }
}

/// После «Удалить все данные»: телефон чист, а приложение в памяти ещё
/// помнит прежнее — начать заново честно можно только с нового запуска.
private struct WipedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Palette.green)
                .accessibilityHidden(true)
            Text("Данные удалены")
                .font(Typography.navTitle)
                .foregroundStyle(Palette.ink)
            Text("Закройте Sprout: смахните его вверх в переключателе приложений. При следующем запуске он начнёт с чистого листа.")
                .font(Typography.settingRow)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Metrics.contentMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { SproutBackground() }
        .interactiveDismissDisabled()
    }
}

#Preview("Wiped, light") {
    WipedView()
}

#Preview("Wiped, dark") {
    WipedView()
        .preferredColorScheme(.dark)
}
