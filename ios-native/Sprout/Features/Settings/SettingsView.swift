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

    /// Знакомство ещё раз — то же, что при первом запуске.
    @State private var touring = false

    @State private var tileSpots = Spots()
    @State private var patternSpots = Spots()
    @State private var waveSpots = Spots()

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        look
                            .hintSpot(.settingsLook)
                        backdrop
                            .hintSpot(.settingsBackdrop)
                        feel
                        watering
                            .hintSpot(.settingsWatering)
                        protection
                        about
                            .hintSpot(.settingsAbout)
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
                .background { SproutBackground() }
                .walk(.settings, scroll: reader)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    WalkButton(walk: .settings, bare: true)
                }
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
            Text("Их включают в настройках телефона: Sprout → Уведомления.")
        }
        .fullScreenCover(isPresented: $touring) { TourView() }
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

            SproutBlock("Цвет волны", term: .wave) {
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

            switchRow("Узор по времени года", term: .motif, isOn: Binding(
                get: { settings.seasonalPattern },
                set: { dress($0) }))

            SproutDivider()

            switchRow("Узор за наклоном", term: .parallax, isOn: Binding(
                get: { settings.parallax },
                set: { settings.parallax = $0 }))

            SproutDivider()

            // Разъезд живёт внутри параллакса и гаснет вместе с ним.
            switchRow("Фигурки плывут порознь", term: .sway, isOn: Binding(
                get: { settings.sway },
                set: { settings.sway = $0 }))
                .disabled(!settings.parallax)
        }
    }

    /// Снежинки, листья или гирлянда приходят и уходят той же волной, что
    /// фигурки, — полосой сверху вниз, как падает снег: клетки у
    /// переключателя нет.
    private func dress(_ on: Bool) {
        let chosen = settings.chosen
        settings.seasonalPattern = on
        guard let before = Festive.shared.settle(on: on) else { return }
        let after = Festive.shared.motif
        guard before.dress(chosen) != after.dress(chosen) else { return }
        Launch.shared.reshape(from: before.dress(chosen),
                              to: after.dress(chosen),
                              front: .sweep(Double.pi / 2))
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
        Lang.format("%lld%%", Int((settings.hapticStrength * 100).rounded()))
    }

    /// Строка с переключателем. Подпись спрятана у самого переключателя, но
    /// нужна VoiceOver. Непонятное слово — со своим «?».
    private func switchRow(_ title: LocalizedStringKey,
                           term: Term? = nil,
                           note: LocalizedStringKey? = nil,
                           isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    if let term { TermHint(term) }
                }
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

    private static let shapeNames = [Lang.text("Росток"), Lang.text("Капля"),
                                     Lang.text("Цветок"), Lang.text("Горшок")]

    /// Выключенная фигурка остаётся на месте приглушённой: иначе кнопки
    /// перескакивали бы под пальцем.
    private var pieces: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< Settings.shapeCount, id: \.self) { index in
                let on = settings.shapes.contains(index)
                Button {
                    // Узор меняется волной из этой клетки; убрали фигурку —
                    // волна сбегается в неё. Наборы — с фигуркой времени
                    // года: иначе после волны она появлялась бы скачком.
                    let motif = Festive.shared.motif
                    let before = motif.dress(settings.chosen)
                    var changed = false
                    withAnimation(Motion.pill) {
                        changed = settings.toggle(shape: index)
                    }
                    guard changed else { return }
                    Feel.pick()
                    let spot = tileSpots.rect(index)
                    Launch.shared.reshape(
                        from: before, to: motif.dress(settings.chosen),
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
            switchRow("Учитывать время года", term: .seasons, isOn: Binding(
                get: { settings.seasons },
                set: { settings.seasons = $0 }))

            SproutDivider()

            switchRow("Напоминать о поливе", term: .reminders, isOn: Binding(
                get: { settings.reminders },
                set: { want(reminders: $0) }))

            if settings.reminders {
                SproutDivider()
                    .transition(.opacity)
                SproutBlock("Когда влажность ниже") {
                    PercentWheel(share: Binding(
                        get: { settings.threshold },
                        set: { settings.threshold = $0 }))
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
            switchRow("Запирать приложение", term: .lock,
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
            Button { touring = true } label: {
                SproutLink("Как пользоваться", icon: "hand.tap")
            }
            .buttonStyle(.plain)

            SproutDivider()

            NavigationLink { GlossaryView() } label: {
                SproutLink("Словарик", icon: "character.book.closed")
            }
            .buttonStyle(.plain)

            SproutDivider()

            // Все экраны снова подскажут при заходе; этот — сразу, чтобы
            // было видно, что сработало.
            Button {
                settings.rewalk()
                Coach.shared.start(.settings)
            } label: {
                SproutLink("Показать подсказки снова", icon: "lightbulb")
            }
            .buttonStyle(.plain)

            SproutDivider()

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
