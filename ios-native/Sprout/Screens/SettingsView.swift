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

    private let lock = Lock.shared

    @State private var tileSpots = Spots()
    @State private var patternSpots = Spots()
    @State private var waveSpots = Spots()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    look
                    backdrop
                    feel
                    watering
                    protection
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
        // Вдруг Face ID настроили, пока приложение было открыто.
        .onAppear { lock.refresh() }
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
            SproutBlock("Тема") {
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

    // MARK: - Фон

    private var backdrop: some View {
        SproutGroup("Фон") {
            SproutBlock("Фигурки", note: "Хотя бы одна остаётся.") {
                pieces
            }

            SproutDivider()

            switchRow("Узор за наклоном", isOn: Binding(
                get: { settings.parallax },
                set: { settings.parallax = $0 }))

            SproutDivider()

            // Разъезд живёт внутри параллакса и гаснет вместе с ним.
            switchRow("Фигурки плывут порознь", isOn: Binding(
                get: { settings.sway },
                set: { settings.sway = $0 }))
                .disabled(!settings.parallax)
        }
    }

    // MARK: - Звук и вибрация

    private var feel: some View {
        SproutGroup("Звук и вибрация") {
            // Включили — сразу слышно, как звучит.
            switchRow("Звуки", isOn: Binding(
                get: { settings.sounds },
                set: {
                    settings.sounds = $0
                    if $0 { Chime.pour.play() }
                }))

            SproutDivider()

            SproutBlock("Сила вибрации") {
                HStack(spacing: 12) {
                    // Отпустили — проба в руку уже новой силы; по дороге
                    // щелчок на каждом десятке.
                    Slider(value: Binding(
                        get: { settings.hapticStrength },
                        set: { settings.hapticStrength = $0 }),
                           in: 0 ... 1, step: 0.05,
                           onEditingChanged: { editing in
                        if !editing { Feel.sample() }
                    })
                    .accessibilityLabel("Сила вибрации")
                    .accessibilityValue(percent)
                    Text(percent)
                        .font(Typography.settingRow)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                        .frame(width: Metrics.percentWidth, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                .animation(Motion.number, value: settings.hapticStrength)
                .onChange(of: Int(settings.hapticStrength * 10)) { _, _ in
                    Feel.pick()
                }
            }
        }
    }

    private var percent: String {
        "\(Int((settings.hapticStrength * 100).rounded()))%"
    }

    /// Строка с переключателем. Подпись спрятана у самого переключателя, но
    /// нужна VoiceOver.
    private func switchRow(_ title: String, note: String? = nil,
                           isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if let note {
                    Text(note)
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: isOn)
                .labelsHidden()
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
            switchRow("Напоминать о поливе", isOn: Binding(
                get: { settings.reminders },
                set: { want(reminders: $0) }))

            if settings.reminders {
                SproutDivider()
                    .transition(.opacity)
                SproutBlock("Когда влажность ниже") {
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

    // MARK: - Защита

    /// Замок — здешние «вход» и «выход»: учётной записи у Sprout нет. Нечем
    /// запирать — переключатель погашен, и это единственное пояснение.
    private var protection: some View {
        SproutGroup("Защита") {
            switchRow("Запирать приложение",
                      note: lock.ready ? nil
                          : "На телефоне нет ни Face ID, ни код-пароля.",
                      isOn: Binding(get: { lock.on }, set: { lock.on = $0 }))
                .disabled(!lock.ready)

            if lock.on {
                SproutDivider()
                    .transition(.opacity)
                // Замок висит над корнем, а лист — над ним: сначала лист
                // уходит.
                Button {
                    lock.close()
                    dismiss()
                } label: {
                    SproutLink("Запереть сейчас", icon: "lock.fill")
                }
                .buttonStyle(.plain)
                .transition(.blurReplace)
            }
        }
        .animation(Motion.enter, value: lock.on)
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
