import SwiftUI

/// Замеры кружков и клеток. Не состоянием: меняются каждый кадр прокрутки, а
/// нужны только в миг нажатия — откуда пустить волну.
final class Spots {
    private var rects: [Int: CGRect] = [:]

    func put(_ rect: CGRect, at key: Int) { rects[key] = rect }

    func rect(_ key: Int) -> CGRect { rects[key] ?? .zero }
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
        HStack(spacing: 6) {
            Text("Раз в")
            Picker("Полив", selection: Binding(
                get: { whole },
                set: { days = Double($0) })) {
                ForEach(1 ... Species.longest, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: Metrics.wheelWidth, height: Metrics.wheelHeight)
            .clipped()
            Text(Plant.plural(whole, "день", "дня", "дней"))
                .contentTransition(.interpolate)
                .animation(Motion.number, value: whole)
            Spacer(minLength: 0)
        }
        .font(Typography.settingRow)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
    }
}

/// Группа настроек: подпись снаружи плашки, как у системных списков.
struct SproutGroup<Content: View>: View {
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

/// Название настройки, выбор и необязательное пояснение.
struct SproutBlock<Control: View>: View {
    let title: String
    let note: String?
    let control: Control

    init(_ title: String, note: String? = nil,
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
/// кнопка живёт в закреплённой строке комнаты.
struct SproutHead: View {
    let title: String

    @State private var open = false

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        HStack(spacing: 6) {
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
    let value: Int
    let caption: String

    var note: String?

    init(_ value: Int, _ caption: String, note: String? = nil) {
        self.value = value
        self.caption = caption
        self.note = note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
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

struct SproutLink: View {
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

struct SproutPage<Content: View>: View {
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

struct Paragraph: View {
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
