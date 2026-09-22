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

    /// Замеры клеток и кружков — см. `Spots`.
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
                // Сегментам щелчок нужен свой: `UISegmentedControl`, в
                // отличие от переключателя и меню, сам не отзывается.
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
                    Text("Пока узор едет, одни фигурки подходят к соседям, "
                         + "другие отстают. Выключите — узор поедет "
                         + "одним куском.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // Разъезд живёт внутри параллакса: выключен он — нечему и
                // расходиться, и переключатель гаснет вместе с ним.
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
                    // Перекраска расходится из того самого кружка, по
                    // которому попал палец: прежний цвет надо взять до
                    // того, как настройка сменится.
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
                    // Цвет волны в покое не виден нигде — его и показать
                    // можно только волной. Пускаем её из кружка, и идёт
                    // она уже новым цветом; узор при этом своего цвета не
                    // меняет, его выбирают выше.
                    //
                    // В очередь, а не поверх: ткнули второй кружок, пока
                    // первая волна идёт, — вторая дождётся её.
                    settings.waveTint = tint
                    Cheer.shared.queue(from: spot)
                    Feel.pick()
                }
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
                    // Клетка перекрашивается сразу, а узор за ней меняется
                    // волной — той же самой, что и при поливе. Добавили
                    // фигурку — волна расходится из этой самой клетки.
                    // Убрали — та же волна, пущенная вспять: она сбегается
                    // с краёв и садится ровно в ту клетку, по которой
                    // попал палец.
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
                        // Тем же цветом, что и выбран для узора: клетка
                        // обещает не только фигурку, но и её цвет.
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

/// Политика конфиденциальности.
///
/// Написана по тому, что приложение делает на самом деле, а не по
/// образцу: сети у него нет вовсе, и обещать здесь нечего, кроме этого.
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
