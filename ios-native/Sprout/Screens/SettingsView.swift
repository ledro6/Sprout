import SwiftUI
import UIKit

/// Настройки: оформление, узор на фоне, напоминания и сведения о
/// приложении.
///
/// Не системная форма, а те же плашки, что на остальных экранах. `Form`
/// нарисовал бы серые сгруппированные списки iOS — они опрятные, но чужие
/// здесь: в приложении всё лежит на стекле поверх узора, и настройки,
/// выпадающие из этого, читались бы служебным экраном, приделанным сбоку.
///
/// Панель сверху при этом системная, и это не противоречие. Крупный
/// заголовок, кнопка «Готово», стрелка возврата на внутренних страницах —
/// то, что система в iOS 26 и так рисует стеклом; переписывать её значило
/// бы повторять готовое хуже, чем оно есть.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Настройки не в окружении: их читает и фон, который рисуется
    /// внутри замыкания холста, — туда окружение не дотягивается. См.
    /// `Settings`.
    private let settings = Settings.shared

    /// Уведомления запрещены в настройках телефона: переключатель
    /// вернулся, и надо сказать, где это чинится.
    @State private var denied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    look
                    watering
                    about
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background { SproutBackground() }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .alert("Уведомления выключены", isPresented: $denied) {
            Button("Открыть настройки") { openSystemSettings() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Разрешить их можно в настройках телефона: "
                 + "Sprout → Уведомления.")
        }
    }

    // MARK: - Оформление

    private var look: some View {
        SettingsGroup("Оформление") {
            SettingsBlock(
                "Тема",
                note: "«Система» — как настроен телефон."
            ) {
                Pills(options: Settings.Theme.allCases.map {
                    PillOption(value: $0, title: $0.short)
                }, selection: Binding(get: { settings.theme },
                                      set: { settings.theme = $0 }))
            }

            SettingsDivider()

            SettingsBlock(
                "Фигурки на фоне",
                note: "Нажмите на фигурку, чтобы убрать её из узора или "
                    + "вернуть. Хотя бы одна нужна."
            ) {
                pieces
            }
        }
    }

    /// Названия фигурок — для тех, кто слушает экран, а не смотрит.
    private static let shapeNames = ["Росток", "Капля", "Цветок", "Горшок"]

    /// Ряд из четырёх фигурок узора: каждая включается сама по себе.
    ///
    /// Порядок в ряду — тот же, что в узоре, и он не меняется от выбора:
    /// выключенная фигурка остаётся на своём месте приглушённой, а не
    /// уезжает из ряда. Иначе кнопки перескакивали бы под пальцем, и
    /// попасть по нужной со второго раза было бы нельзя.
    private var pieces: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< Settings.shapeCount, id: \.self) { index in
                let on = settings.shapes.contains(index)
                Button {
                    withAnimation(Motion.pill) { settings.toggle(shape: index) }
                } label: {
                    SproutPiece(index: index)
                        .fill(on ? Palette.green
                              : Palette.ink.opacity(Metrics.pieceOff))
                        .frame(height: Metrics.pieceTile)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 16,
                                             style: .continuous)
                                .fill(on ? Palette.accent.opacity(0.14)
                                      : .clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.shapeNames[index])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: - Полив

    private var watering: some View {
        SettingsGroup("Полив") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Напоминать о поливе")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text("Телефон подскажет, когда растению станет сухо.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("Напоминать о поливе", isOn: Binding(
                    get: { settings.reminders },
                    set: { want(reminders: $0) }))
                    .labelsHidden()
            }

            if settings.reminders {
                SettingsDivider()
                SettingsBlock(
                    "Когда напоминать",
                    note: "Влажность, ниже которой растение просит воды."
                ) {
                    Pills(options: Settings.thresholds.map {
                        PillOption(value: $0,
                                   title: "\(Int(($0 * 100).rounded()))%")
                    }, selection: Binding(get: { settings.threshold },
                                          set: { settings.threshold = $0 }))
                }
            }
        }
        // Порог приезжает и уезжает вместе с переключателем: он к нему и
        // относится, а выключенным напоминаниям порог ни к чему.
        .animation(Motion.enter, value: settings.reminders)
    }

    /// Включить или выключить напоминания.
    ///
    /// Включение — это ещё и разрешение, которого может не быть.
    /// Спрашиваем его здесь, в тот самый миг, когда человек попросил
    /// напоминать: спрошенное при запуске разрешение чаще всего получает
    /// отказ, а отказ уже не переспросить: система больше не покажет окно.
    private func want(reminders on: Bool) {
        guard on else {
            settings.reminders = false
            Notifier.clear()
            return
        }
        Task { @MainActor in
            if await Notifier.ask() {
                settings.reminders = true
            } else {
                denied = true
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - О приложении

    private var about: some View {
        SettingsGroup("О приложении") {
            NavigationLink { PrivacyView() } label: {
                SettingsLink("Политика конфиденциальности",
                             icon: "checkmark.shield")
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink { AboutView() } label: {
                SettingsLink("Сведения о приложении", icon: "info.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Кирпичи настроек

/// Подпись и плашка под ней — одна группа настроек.
private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.groupTitle)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: Metrics.rowGap) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.groupPadding)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
        }
    }
}

/// Название настройки, пояснение под ним и сам выбор.
private struct SettingsBlock<Control: View>: View {
    let title: String
    let note: String
    let control: Control

    init(_ title: String, note: String,
         @ViewBuilder control: () -> Control) {
        self.title = title
        self.note = note
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            control
            Text(note)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Черта между настройками внутри одной плашки.
///
/// Своя, а не системная: системная тянется во всю ширину вью, а плашка
/// стеклянная, и черта во всю ширину упиралась бы в её скруглённый край.
private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.ink.opacity(0.1))
            .frame(height: 1)
    }
}

/// Строка, ведущая на другую страницу.
private struct SettingsLink: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
            Text(title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// Один пункт в ряду выбора.
private struct PillOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}

/// Ряд кнопок, из которых выбрана одна.
///
/// Своё, а не `Picker(.segmented)`: тот рисует серый системный
/// переключатель, который на стеклянной плашке выглядит наклейкой. Здесь
/// подложка та же, что у плашки, а выбранное отмечено синим — тем же
/// синим, которым в приложении отмечена открытая комната и активная
/// вкладка.
///
/// Синяя капсула не появляется на новом месте, а переезжает: у неё общая
/// личность на весь ряд, и SwiftUI переносит её сам. Появляйся она
/// заново, выбор читался бы перещёлкиванием, а не движением.
private struct Pills<Value: Hashable>: View {
    let options: [PillOption<Value>]
    @Binding var selection: Value

    @Namespace private var slide

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let picked = option.value == selection
                Button {
                    withAnimation(Motion.pill) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(Typography.pill)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(picked ? Color.white : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.pillHeight)
                        .background {
                            if picked {
                                Capsule()
                                    .fill(Palette.accent)
                                    .matchedGeometryEffect(id: "picked",
                                                           in: slide)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Metrics.pillPadding)
        .background { Capsule().fill(Palette.ink.opacity(0.07)) }
    }
}

// MARK: - Страницы

/// Политика конфиденциальности.
///
/// Написана по тому, что приложение делает на самом деле, а не по
/// образцу: сети у него нет вовсе, и обещать здесь нечего, кроме этого.
private struct PrivacyView: View {
    var body: some View {
        Page(title: "Политика конфиденциальности") {
            Paragraph("Sprout не собирает о вас никаких сведений и никуда "
                      + "их не передаёт.")
            Paragraph("Что хранится", body:
                "Клички растений, виды, влажность, даты — всё, что вы "
                + "вводите, — лежит в файле внутри приложения, на самом "
                + "телефоне. Там же настройки. Ничего из этого не покидает "
                + "устройство.")
            Paragraph("Сеть", body:
                "Приложение не выходит в интернет. У него нет ни учётной "
                + "записи, ни сервера, ни аналитики, ни рекламы.")
            Paragraph("Датчик движения", body:
                "Наклон телефона чуть двигает узор на фоне. Показания "
                + "используются только для этого, не сохраняются и никуда "
                + "не уходят.")
            Paragraph("Уведомления", body:
                "Напоминания о поливе создаёт сам телефон по срокам, "
                + "посчитанным на нём же. Пуш-сервер в этом не участвует.")
            Paragraph("Резервная копия", body:
                "Файл сада попадает в резервную копию iPhone — туда же, "
                + "куда и остальные ваши данные, по правилам Apple.")
            Paragraph("Удаление", body:
                "Удалите приложение — вместе с ним исчезнет и всё, что оно "
                + "помнило.")
        }
    }
}

/// Сведения о приложении.
private struct AboutView: View {
    /// Версия и сборка — из самого приложения, а не написанные здесь
    /// руками: написанные руками расходятся с настоящими на первой же
    /// сборке.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Page(title: "Сведения о приложении") {
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

            SettingsDivider()

            fact("Версия", version)
            fact("Система", "iOS 26 и новее")

            SettingsDivider()

            Paragraph("Время идёт быстрее", body:
                "Час сада проходит здесь за секунду настоящего времени: "
                + "иначе за один сеанс проценты влажности не сдвинулись бы "
                + "ни на один. По этим же часам считаются и напоминания.")

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

    private func fact(_ name: String, _ value: String) -> some View {
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

/// Внутренняя страница настроек: заголовок в панели, одна плашка с
/// текстом на том же фоне.
private struct Page<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowGap) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.groupPadding)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background { SproutBackground() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Абзац: подзаголовок и текст под ним. Без подзаголовка — просто текст.
private struct Paragraph: View {
    let heading: String?
    let text: String

    init(_ text: String) {
        heading = nil
        self.text = text
    }

    init(_ heading: String, body text: String) {
        self.heading = heading
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let heading {
                Text(heading)
                    .font(Typography.settingRow.weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            Text(text)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
