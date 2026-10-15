import SwiftUI
import UIKit

/// «Дача» в листе «Комнаты»: какие комнаты на даче, где она и как о ней
/// напоминать. Геопозицию спрашивают только по «Отметить дачу здесь»,
/// и пояснение под кнопкой говорит зачем. Место и напоминание — когда
/// на даче есть хоть одна комната. Список вокруг в режиме правки, но эти
/// строки не двигаются и не удаляются — переключатели и кнопки работают
/// как обычно.
struct DachaGroup: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let dachnik = Dachnik.shared
    private let settings = Settings.shared

    private var anyDacha: Bool { !Dacha.rooms(garden.rooms).isEmpty }

    var body: some View {
        Section {
            SproutGroup("Какие комнаты на даче") {
                ForEach(garden.rooms) { room in
                    if room.id != garden.rooms.first?.id { SproutDivider() }
                    row(room)
                }
                if anyDacha {
                    SproutDivider()
                    place
                        .transition(.blurReplace)
                    if dachnik.spot != nil {
                        SproutDivider()
                        reminder
                            .transition(.blurReplace)
                    }
                }
            }
            .animation(Motion.enter, value: anyDacha)
            .animation(Motion.enter, value: dachnik.spot)
            .animation(Motion.enter, value: dachnik.access)
            .animation(Motion.enter, value: dachnik.locating)
            .animation(Motion.enter, value: dachnik.missed)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: 14, leading: Metrics.contentMargin,
                bottom: 5, trailing: Metrics.contentMargin))
            .onAppear {
                if anyDacha { dachnik.look() }
            }
            // Вернулись из Настроек — может, точную геопозицию уже включили.
            .onChange(of: phase) { _, now in
                if now == .active, anyDacha { dachnik.look() }
            }
        } footer: {
            Text(Self.footer)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .padding(.horizontal, Metrics.contentMargin)
        }
    }

    private static let footer = Lang.text("""
        Отметьте комнаты, которые на даче. Когда вы туда приедете, телефон \
        напомнит, кого полить, а с погодой учтёт и дождь на участке.
        """)

    // MARK: - Комнаты

    private func row(_ room: Room) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if let note = note(for: room) {
                    Text(note)
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.blurReplace)
                }
            }
            Spacer(minLength: 0)
            Toggle(room.name, isOn: Binding(
                get: { room.atDacha },
                set: { on in
                    withAnimation(Motion.enter) {
                        garden.settle(room.name, dacha: on)
                    }
                    if on { dachnik.look() }
                    Feel.pick()
                }))
                .labelsHidden()
                .accessibilityLabel(Text(Lang.format("%@ — на даче",
                                                     room.name)))
        }
    }

    /// Без крыши — дождь там откладывает полив. Пока погода на даче ни разу
    /// не пришла (WeatherKit выключен или погода не учитывается), молчим.
    private func note(for room: Room) -> String? {
        guard room.atDacha, Climate.open(room.name), settings.weather,
              dachnik.rain != nil
        else { return nil }
        return Lang.text("Под открытым небом: дождь откладывает полив")
    }

    // MARK: - Место

    @ViewBuilder
    private var place: some View {
        if dachnik.locating {
            HStack(spacing: 10) {
                ProgressView()
                Text("Узнаём, где вы…")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
            }
        } else if let spot = dachnik.spot {
            marked(spot)
        } else {
            unmarked
        }
    }

    @ViewBuilder
    private var unmarked: some View {
        switch dachnik.access {
        case .unasked, .fine:
            VStack(alignment: .leading, spacing: 10) {
                Button { dachnik.mark() } label: {
                    Label("Отметить дачу здесь", systemImage: "location.fill")
                        .font(Typography.detail)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.accentFill)
                .controlSize(.large)
                Text(Self.why)
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if dachnik.missed { missed }
            }
        case .denied:
            VStack(alignment: .leading, spacing: 10) {
                warning(Lang.text("Геопозиция для Sprout запрещена"),
                        Self.allowIt)
                settingsButton
            }
        case .approximate:
            VStack(alignment: .leading, spacing: 10) {
                warning(Lang.text("Нужна точная геопозиция"), Self.precise)
                settingsButton
            }
        }
    }

    private static let why = Lang.text("""
        Нажмите, стоя на участке: телефон один раз узнает, где вы, и \
        запомнит это место. Нужна точная геопозиция, и только сейчас — о \
        приезде потом узнаёт сама iOS, а место остаётся на телефоне.
        """)

    private static let allowIt = Lang.text("""
        Разрешите её в Настройках → Sprout → Геопозиция: «При \
        использовании» и «Точная геопозиция».
        """)

    private static let precise = Lang.text("""
        С примерной телефон не заметит, что вы приехали. Включите «Точная \
        геопозиция» в Настройках → Sprout → Геопозиция.
        """)

    private func marked(_ spot: Dacha.Spot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Место дачи")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text(Lang.format("Отмечено %@", spot.marked.formatted(
                        .dateTime.day().month(.wide).locale(Lang.locale))))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Palette.green)
            }
            lost
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { placeButtons }
                VStack(alignment: .leading, spacing: 10) { placeButtons }
            }
            if dachnik.missed { missed }
        }
    }

    /// Место есть, а доступа уже нет — напоминание не придёт, и сказано,
    /// как вернуть.
    @ViewBuilder
    private var lost: some View {
        switch dachnik.access {
        case .fine:
            EmptyView()
        case .unasked:
            warning(Lang.text("Напоминание по приезде не придёт"),
                    Lang.text("Разрешения на геопозицию больше нет."))
            Button { dachnik.allow() } label: {
                Label("Разрешить геопозицию", systemImage: "location")
                    .font(Typography.settingNote)
            }
            .buttonStyle(.glass)
        case .denied:
            warning(Lang.text("Напоминание по приезде не придёт"),
                    Self.allowIt)
            settingsButton
        case .approximate:
            warning(Lang.text("Напоминание по приезде не придёт"),
                    Self.precise)
            settingsButton
        }
    }

    @ViewBuilder
    private var placeButtons: some View {
        if dachnik.access == .fine {
            Button { dachnik.mark() } label: {
                Label("Отметить здесь заново", systemImage: "location.fill")
                    .font(Typography.settingNote)
            }
            .buttonStyle(.glass)
        }
        Button(role: .destructive) {
            withAnimation(Motion.enter) { dachnik.forget() }
        } label: {
            Label("Забыть место", systemImage: "mappin.slash")
                .font(Typography.settingNote)
        }
        .buttonStyle(.glass)
    }

    private var missed: some View {
        Text("Точно узнать место не вышло. Попробуйте ещё раз под открытым небом.")
            .font(Typography.settingNote)
            .foregroundStyle(Palette.warn)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func warning(_ title: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(Typography.settingNote.weight(.semibold))
                .foregroundStyle(Palette.warn)
            Text(note)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString)
            else { return }
            UIApplication.shared.open(url)
        } label: {
            Label("Открыть Настройки", systemImage: "gear")
                .font(Typography.settingNote)
        }
        .buttonStyle(.glass)
    }

    // MARK: - Напоминание

    @ViewBuilder
    private var reminder: some View {
        if settings.reminders {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Напоминать о дачных растениях только на даче")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Обычные напоминания о них не придут — только по приезде.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Напоминать о дачных растениях только на даче",
                       isOn: Binding(get: { dachnik.only },
                                     set: { dachnik.only = $0 }))
                    .labelsHidden()
                    .disabled(!dachnik.located)
            }
            if !dachnik.located {
                Text("Без геопозиции напоминания по даче приходят как обычно.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            }
        } else {
            Text("Напоминание по приезде придёт, если включить «Напоминать о поливе» в настройках.")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
