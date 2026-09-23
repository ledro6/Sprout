import SwiftUI

/// Словарь плашек, из которого собраны все экраны со списками: настройки,
/// статистика, профиль, добавление растения.
///
/// Вынесен из настроек, где и родился. Пока экран был один, кирпичам было
/// незачем жить отдельно; с тремя одинаково устроенными экранами общий
/// словарь — единственный способ, чтобы они остались одинаковыми не на
/// словах, а на деле: поправил отступ здесь — поправился везде.

/// Где на экране лежат кружки цветов и клетки фигурок.
///
/// Нужны они ровно в миг нажатия — оттуда расходится переход по узору, — а
/// меняются на каждом кадре прокрутки. Лежи замеры в состоянии вью, каждый
/// такой кадр пересобирал бы экран ради чисел, которых в теле никто не
/// читает. Та же причина, что у `Spot` на экране растения.
final class Spots {
    private var rects: [Int: CGRect] = [:]

    func put(_ rect: CGRect, at key: Int) { rects[key] = rect }

    func rect(_ key: Int) -> CGRect { rects[key] ?? .zero }
}

/// Подпись и плашка под ней — одна группа настроек.
///
/// Заголовок живёт снаружи плашки, а не внутри: так же, как у системных
/// сгруппированных списков, — глаз читает подпись как название раздела, а
/// не как первую строку содержимого.
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

/// Название настройки, сам выбор и пояснение под ним.
///
/// Пояснение необязательно: у выбора цвета его нет вовсе. Там объяснять
/// нечего — кружки говорят сами за себя, — а строка серого текста под
/// каждым рядом делала плашку длиннее и мусорнее.
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

/// Кнопка настроек — круглая, стеклянная, системная.
///
/// Стекло не своё, а `.buttonStyle(.glass)` с круглой каймой: вместе с ним
/// приходит и продавливание под пальцем, и отскок пружиной, и блик,
/// который идёт за точкой касания, и подмена материала при «Уменьшении
/// прозрачности». Ничего из этого руками не повторяется.
///
/// Размер кнопки задаёт коробка значка: системная кнопка меряет себя по
/// содержимому. Сама шестерёнка нарисована крупнее коробки и выходит за
/// неё — так знак заметнее, а кнопка прежняя.
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

/// Заголовок раздела и кнопка настроек справа от него.
///
/// Настройки должны открываться с любого экрана, а не с одной только
/// главной: это не «настройки главной», а настройки приложения, и
/// уходить за ними на другую вкладку — лишний ход.
///
/// Лист свой у каждого экрана, и это не расточительство: лист принадлежит
/// тому, кто его поднял, и общий на приложение пришлось бы тащить через
/// корень ради кнопки, которая и так на месте.
///
/// На главной этого типа нет: там кнопка живёт в закреплённой строке
/// комнаты и хитро смещается, чтобы стоять вровень с заголовком и в покое,
/// и на прокрутке. Здесь прокручивается всё вместе, и хитрость не нужна.
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

/// Ряд кружков с оттенками.
///
/// Кружок насыщенной ипостасью оттенка, а не бледной: выбирают оттенок, а
/// не силу, и бледный кружок на белой плашке было бы не разглядеть. Тонкая
/// обводка — чтобы светлые кружки не сливались с плашкой совсем.
///
/// Замер кружка уходит выбирающему: почти всё, что выбирают цветом, надо
/// потом показать волной, а волна расходится из того места, где по цвету
/// попали пальцем. Экран сам решает, пускать ли её.
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

/// Крупное число с ярлыком под ним: «17 / Всего».
///
/// Ярлык, а не фраза. «17 поливов» пришлось бы склонять по числу — 1
/// полив, 2 полива, 5 поливов, — и склонять пришлось бы на ходу, потому
/// что число меняется. Ярлык не склоняется вовсе: под ним стоит любое
/// число, и строка остаётся верной.
///
/// Число меняется числовым переходом системы — тем же, что у влажности на
/// карточке: цифры пролистываются, а ярлык под ними стоит на месте.
struct SproutFigure: View {
    let value: Int
    let caption: String

    /// Необязательная приписка мельче ярлыка — «лучшая — 9».
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
        // Числу и ярлыку порознь озвучиваться незачем: вслух это одна
        // строка — «17, всего».
        .accessibilityElement(children: .combine)
    }
}

/// Черта между настройками внутри одной плашки.
///
/// Системная. Своя здесь была — прямоугольник в десятую долю чернил, — из
/// опасения, что системная растянется во всю ширину вью и упрётся в
/// скруглённый край плашки. Опасение пустое: черта стоит внутри колонки с
/// полями, её ширину задаёт колонка, и до края плашки черта не доходит.
/// А толщину в пиксель, цвет под тему и поведение при «Увеличении
/// контраста» система знает лучше.
struct SproutDivider: View {
    var body: some View { Divider() }
}

/// Строка, ведущая на другую страницу.
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

/// Внутренняя страница настроек: заголовок в панели, одна плашка с
/// текстом на том же фоне.
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

/// Абзац: подзаголовок и текст под ним. Без подзаголовка — просто текст.
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
