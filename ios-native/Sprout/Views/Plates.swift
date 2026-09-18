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
