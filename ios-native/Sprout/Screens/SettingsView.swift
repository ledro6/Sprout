import SwiftUI
import UIKit

/// Настройки. Не `Form`, а те же стеклянные плашки, что везде: серые списки
/// iOS читались бы здесь чужими. Панель сверху при этом системная.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Не в окружении: настройки читает и фон изнутри замыкания холста. См.
    /// `Settings`.
    private let settings = Settings.shared

    /// Уведомления запрещены в настройках телефона — надо сказать, где это
    /// чинится.
    @State private var denied = false

    @State private var tileSpots = Spots()
    @State private var patternSpots = Spots()
    @State private var waveSpots = Spots()

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
        SproutGroup("Оформление") {
            SproutBlock(
                "Тема",
                note: "«Система» — как настроен телефон."
            ) {
                Picker("Тема", selection: Binding(get: { settings.theme },
                                                  set: { settings.theme = $0 })) {
                    ForEach(Settings.Theme.allCases) { theme in
                        Text(theme.short).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // `UISegmentedControl` сам не отзывается, в отличие от
                // переключателя и меню.
                .onChange(of: settings.theme) { _, _ in Feel.pick() }
            }

            SproutDivider()

            SproutBlock(
                "Фигурки на фоне",
                note: "Нажмите на фигурку, чтобы убрать её из узора или "
                    + "вернуть. Хотя бы одна нужна."
            ) {
                pieces
            }

            SproutDivider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Отклик в руке")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text("Полив, всходы и волна отзываются вибрацией.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("Отклик в руке", isOn: Binding(
                    get: { settings.haptics },
                    set: { settings.haptics = $0 }))
                    .labelsHidden()
            }

            SproutDivider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Звуки")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text("Полив, посадка, удаление и возврат звучат. "
                         + "В беззвучном режиме телефона молчат.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // Включили — сразу слышно, как звучит.
                Toggle("Звуки", isOn: Binding(
                    get: { settings.sounds },
                    set: {
                        settings.sounds = $0
                        if $0 { Chime.pour.play() }
                    }))
                    .labelsHidden()
            }

            SproutDivider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Узор за наклоном")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text("Фон едет вслед за тем, как держат телефон. "
                         + "Выключите, если от этого рябит.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Узор за наклоном", isOn: Binding(
                    get: { settings.parallax },
                    set: { settings.parallax = $0 }))
                    .labelsHidden()
            }

            SproutDivider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Фигурки живут порознь")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text("Фигурки плывут в фоне порознь и доплывают, "
                         + "когда телефон уже замер. Выключите — узор "
                         + "поедет одним куском.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // Разъезд живёт внутри параллакса и гаснет вместе с ним.
                Toggle("Фигурки живут порознь", isOn: Binding(
                    get: { settings.sway },
                    set: { settings.sway = $0 }))
                    .labelsHidden()
                    .disabled(!settings.parallax)
            }

            SproutDivider()

            SproutBlock("Цвет узора") {
                SproutTints(current: settings.patternTint,
                            spots: patternSpots) { tint, spot in
                    // Прежний цвет берём до смены настройки: перекраска идёт
                    // из кружка, по которому попал палец.
                    Feel.pick()
                    Repaint.shared.begin(base: settings.patternTint,
                                         wave: settings.waveTint,
                                         to: tint, toWave: settings.waveTint,
                                         from: CGPoint(x: spot.midX,
                                                       y: spot.midY))
                    settings.patternTint = tint
                }
            }

            SproutDivider()

            SproutBlock("Цвет волны") {
                SproutTints(current: settings.waveTint,
                            spots: waveSpots) { tint, spot in
                    // Цвет волны виден только волной — пускаем её из кружка.
                    // В очередь: второй кружок дождётся первой волны.
                    settings.waveTint = tint
                    Cheer.shared.queue(from: spot)
                    Feel.pick()
                }
            }
        }
    }

    private static let shapeNames = ["Росток", "Капля", "Цветок", "Горшок"]

    /// Выключенная фигурка остаётся на месте приглушённой: иначе кнопки
    /// перескакивали бы под пальцем.
    private var pieces: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< Settings.shapeCount, id: \.self) { index in
                let on = settings.shapes.contains(index)
                Button {
                    // Узор меняется волной из этой клетки; убрали фигурку —
                    // волна сбегается в неё.
                    let before = settings.chosen
                    var changed = false
                    withAnimation(Motion.pill) {
                        changed = settings.toggle(shape: index)
                    }
                    guard changed else { return }
                    Feel.pick()
                    let spot = tileSpots.rect(index)
                    Launch.shared.reshape(
                        from: before, to: settings.chosen,
                        front: on
                            ? .collapse(CGPoint(x: spot.midX, y: spot.midY))
                            : .point(CGPoint(x: spot.midX, y: spot.midY)))
                } label: {
                    SproutPiece(index: index)
                        .fill(on ? Palette.swatch(settings.patternTint)
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
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                    action: { tileSpots.put($0, at: index) }
            }
        }
    }

    // MARK: - Полив

    private var watering: some View {
        SproutGroup("Полив") {
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
                SproutDivider()
                    .transition(.opacity)
                SproutBlock(
                    "Когда напоминать",
                    note: "Влажность, ниже которой растение просит воды."
                ) {
                    Picker("Когда напоминать",
                           selection: Binding(get: { settings.threshold },
                                              set: { settings.threshold = $0 })) {
                        ForEach(Settings.thresholds, id: \.self) { level in
                            Text("\(Int((level * 100).rounded()))%").tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .transition(.blurReplace)
            }
        }
        .animation(Motion.enter, value: settings.reminders)
    }

    /// Разрешение спрашиваем здесь, когда попросили напоминать: спрошенное
    /// при запуске чаще получает отказ, а отказ уже не переспросить.
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
        SproutGroup("О приложении") {
            NavigationLink { PrivacyView() } label: {
                SproutLink("Политика конфиденциальности",
                             icon: "checkmark.shield")
            }
            .buttonStyle(.plain)

            SproutDivider()

            NavigationLink { AboutView() } label: {
                SproutLink("Сведения о приложении", icon: "info.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Страницы

/// Политика конфиденциальности — по тому, что приложение делает на самом
/// деле: сети у него нет вовсе.
private struct PrivacyView: View {
    var body: some View {
        SproutPage(title: "Политика конфиденциальности") {
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

private struct AboutView: View {
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

            fact("Версия", version)
            fact("Система", "iOS 26 и новее")

            SproutDivider()

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
