import SwiftUI

/// Замеры кружков и клеток. Не состоянием: меняются каждый кадр прокрутки, а
/// нужны только в миг нажатия — откуда пустить волну.
final class Spots {
    private var rects: [Int: CGRect] = [:]

    func put(_ rect: CGRect, at key: Int) { rects[key] = rect }

    func rect(_ key: Int) -> CGRect { rects[key] ?? .zero }
}

/// Процент барабаном — порог влажности для напоминаний: любой целый, а не
/// шаг в десять. Подпись числа — из каталога: у кого знак впереди, у кого
/// через пробел.
struct PercentWheel: View {
    @Binding var share: Double

    var range: ClosedRange<Int> = Settings.thresholds

    private var whole: Int {
        min(max(Int((share * 100).rounded()), range.lowerBound),
            range.upperBound)
    }

    var body: some View {
        HStack(spacing: 6) {
            Picker(Lang.format("%lld%%", whole), selection: Binding(
                get: { whole },
                set: { share = Double($0) / 100 })) {
                ForEach(range, id: \.self) { value in
                    Text(Lang.format("%lld%%", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: Metrics.wheelWidth + 24, height: Metrics.wheelHeight)
            .clipped()
            Spacer(minLength: 0)
        }
        .font(Typography.settingRow)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
    }
}

/// Срок полива барабаном, как в «Таймере»: «Раз в [N] дней». Дробный срок —
/// 4,5 дня из таблицы видов — барабан показывает ближайшим целым и не
/// трогает, пока его не крутили.
struct PeriodWheel: View {
    @Binding var days: Double

    private var whole: Int {
        min(max(Int(days.rounded()), 1), Species.longest)
    }

    var body: some View {
        let (before, after) = Self.around(whole)
        HStack(spacing: 6) {
            if !before.isEmpty { Text(before) }
            Picker(Species.periodLabel(Double(whole)), selection: Binding(
                get: { whole },
                set: { days = Double($0) })) {
                ForEach(1 ... Species.longest, id: \.self) { count in
                    Text(count.formatted()).tag(count)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: Metrics.wheelWidth, height: Metrics.wheelHeight)
            .clipped()
            if !after.isEmpty {
                Text(after)
                    .contentTransition(.interpolate)
                    .animation(Motion.number, value: whole)
            }
            Spacer(minLength: 0)
        }
        .font(Typography.settingRow)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
    }

    /// Слова по обе стороны барабана — из той же строки каталога, что «Раз в
    /// 7 дней»: порядок слов и форма числа у каждого языка свои, и склеивать
    /// их здесь значило бы переводить заново.
    static func around(_ count: Int) -> (String, String) {
        let line = Species.periodLabel(Double(count))
        let marks = [count.formatted(.number.locale(Lang.locale)), "\(count)"]
        guard let range = marks.lazy.compactMap({ line.range(of: $0) }).first
        else { return (line, "") }
        let trim = CharacterSet.whitespaces
        return (String(line[..<range.lowerBound]).trimmingCharacters(in: trim),
                String(line[range.upperBound...]).trimmingCharacters(in: trim))
    }
}

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

    @State private var open = false

    init(_ title: LocalizedStringKey, walk: Walk? = nil) {
        self.title = title
        self.walk = walk
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let walk { WalkButton(walk: walk) }
            SproutGear { open = true }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .sproutRide()
        .sheet(isPresented: $open) { SettingsView() }
    }
}

/// Ряд кружков с оттенками — насыщенной ипостасью, с тонкой обводкой. Замер
/// кружка отдаётся выбирающему: волна идёт оттуда, где попали пальцем.
struct SproutTints: View {
    let current: Tint
    let spots: Spots
    let pick: (Tint, CGRect) -> Void

    init(current: Tint, spots: Spots,
         pick: @escaping (Tint, CGRect) -> Void) {
        self.current = current
        self.spots = spots
        self.pick = pick
    }

    /// По шесть в ряд: одиннадцать кружков в одну строку не влезают.
    private static let columns = Array(repeating: GridItem(.flexible(),
                                                           spacing: 6),
                                       count: 6)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 8) {
            ForEach(Tint.allCases) { tint in
                let picked = tint == current
                Button {
                    withAnimation(Motion.pill) {
                        pick(tint, spots.rect(tint.rawValue))
                    }
                } label: {
                    Circle()
                        .fill(Palette.swatch(tint))
                        .overlay {
                            Circle().strokeBorder(Palette.ink.opacity(0.12),
                                                  lineWidth: 0.5)
                        }
                        .frame(width: Metrics.swatch, height: Metrics.swatch)
                        .padding(4)
                        .overlay {
                            if picked {
                                Circle().strokeBorder(Palette.accent,
                                                      lineWidth: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tint.title)
                .accessibilityAddTraits(picked ? .isSelected : [])
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                    action: { spots.put($0, at: tint.rawValue) }
            }
        }
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
