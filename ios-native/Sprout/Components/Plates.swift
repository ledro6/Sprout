import SwiftUI

/// Группа настроек: подпись снаружи плашки, как у системных списков.
/// Подписи плашек — ключи каталога строк, как у `Text("…")`.
struct SproutGroup<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
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

/// Название настройки, выбор и необязательное пояснение. Непонятное слово
/// в названии — со своим «?», см. `TermHint`.
struct SproutBlock<Control: View>: View {
    let title: LocalizedStringKey
    let note: LocalizedStringKey?
    let term: Term?
    let control: Control

    init(_ title: LocalizedStringKey, note: LocalizedStringKey? = nil,
         term: Term? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.note = note
        self.term = term
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(title)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if let term { TermHint(term) }
            }
            control
            if let note {
                Text(note)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Кнопка настроек — системное `.glass`: продавливание, отскок, блик и замена
/// материала приходят с ним. Шестерёнка нарисована крупнее коробки — знак
/// заметнее, кнопка прежняя.
struct SproutGear: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: "gearshape")
                .font(.system(size: Metrics.gearGlyph, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.gearBox, height: Metrics.gearBox)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Настройки")
    }
}

/// Заголовок раздела и кнопка настроек — на каждом экране, кроме главной: там
/// кнопка живёт в закреплённой строке комнаты. У экрана с подсказками рядом
/// «?» — показать их ещё раз.
struct SproutHead: View {
    let title: LocalizedStringKey
    let walk: Walk?

    /// «Выбрать» — правка блоков экрана; пусто — кнопки нет.
    var choosing: Binding<Bool>?

    @State private var open = false

    init(_ title: LocalizedStringKey, walk: Walk? = nil,
         choosing: Binding<Bool>? = nil) {
        self.title = title
        self.walk = walk
        self.choosing = choosing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let choosing {
                Button {
                    withAnimation(Motion.pill) { choosing.wrappedValue.toggle() }
                    Feel.pick()
                } label: {
                    Text(choosing.wrappedValue ? "Готово" : "Выбрать")
                        .font(Typography.settingRow.weight(.semibold))
                        .lineLimit(1)
                        .contentTransition(.interpolate)
                }
                .buttonStyle(.glass)
                .fixedSize()
            }
            if choosing?.wrappedValue != true {
                if let walk { WalkButton(walk: walk) }
                SproutGear { open = true }
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .sproutRide()
        .sheet(isPresented: $open) { SettingsView() }
    }
}

/// Число с ярлыком под ним: «17 / Всего». Ярлык, а не фраза, — его не надо
/// склонять по числу.
struct SproutFigure: View {
    let caption: LocalizedStringKey
    let value: Int

    var note: String?

    init(_ caption: LocalizedStringKey, _ value: Int, note: String? = nil) {
        self.caption = caption
        self.value = value
        self.note = note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value.formatted())
                .font(Typography.figure)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(caption)
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
            if let note {
                Text(note)
                    .font(Typography.figureCaption)
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.number, value: value)
        .accessibilityElement(children: .combine)
    }
}

/// Черта внутри плашки — системная: ширину задаёт колонка с полями, а
/// толщину, цвет и «Увеличение контраста» система знает лучше.
struct SproutDivider: View {
    var body: some View { Divider() }
}

/// Подпись — ключ каталога; строка из данных (прежний запрос поиска) идёт
/// как есть.
struct SproutLink: View {
    let title: Text
    let icon: String

    init(_ title: LocalizedStringKey, icon: String) {
        self.title = Text(title)
        self.icon = icon
    }

    @_disfavoredOverload
    init(_ title: some StringProtocol, icon: String) {
        self.title = Text(title)
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
            title
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

struct SproutPage<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
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

struct Paragraph: View {
    let heading: LocalizedStringKey?
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        heading = nil
        self.text = text
    }

    init(_ heading: LocalizedStringKey, body text: LocalizedStringKey) {
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
