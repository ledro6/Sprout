import SwiftUI

/// «Новая комната» — страница за последней комнатой на главной. Долистали до
/// неё — пишите имя, клавиатура уже поднята; готовые имена заводятся одним
/// нажатием. Заведённая комната встаёт на место этой страницы, а «Новая
/// комната» отъезжает правее.
struct NewRoom: View {
    @Binding var draft: String

    let focus: FocusState<Bool>.Binding

    /// Сада ещё нет — сверху строка о том, с чего начать.
    let bare: Bool

    /// Готовые имена, которых в саду ещё нет.
    let ideas: [String]

    /// Сколько раз имя не подошло: на каждый раз поле вздрагивает, как
    /// неверный пароль.
    let misses: Int

    let make: (String) -> Void

    let edit: () -> Void

    private var blank: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            if bare {
                Text(Lang.text("""
                    В саду пока ничего не растёт. Посадите первое растение во \
                    вкладке «Добавить».
                    """))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Растения в неё можно будет посадить или перевезти.")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            field

            Button { make(draft) } label: {
                Text("Завести комнату")
                    .font(Typography.detail)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(blank)

            if !ideas.isEmpty {
                Flow {
                    ForEach(ideas, id: \.self) { idea in
                        Button(idea) { make(idea) }
                            .buttonStyle(.glass)
                            .font(Typography.settingNote)
                    }
                }
                .padding(.top, 4)
            }

            if !bare {
                Button(action: edit) {
                    Label("Изменить комнаты…", systemImage: "pencil")
                        .font(Typography.settingNote)
                }
                .buttonStyle(.glass)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .frame(maxWidth: .infinity)
        .transition(.blurReplace)
    }

    private var field: some View {
        TextField("Название", text: $draft)
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .submitLabel(.done)
            .onSubmit { make(draft) }
            .focused(focus)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .sproutPlate(in: Capsule())
            .keyframeAnimator(initialValue: CGFloat(0), trigger: misses) {
                content, shift in
                content.offset(x: shift)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-10, duration: 0.06)
                    LinearKeyframe(9, duration: 0.07)
                    LinearKeyframe(-6, duration: 0.07)
                    LinearKeyframe(3, duration: 0.07)
                    SpringKeyframe(0, duration: 0.2)
                }
            }
    }
}

/// Кнопки строками с переносом, как слова в абзаце: сколько влезет в строку,
/// остальное — ниже; строки по середине.
struct Flow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let rows = lines(of: subviews, within: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +)
            + spacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(of: subviews, within: bounds.width) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + spacing
        }
    }

    private struct Line {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(of subviews: Subviews, within width: CGFloat) -> [Line] {
        var done: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !line.items.isEmpty,
               line.width + spacing + size.width > width {
                done.append(line)
                line = Line()
            }
            line.width += (line.items.isEmpty ? 0 : spacing) + size.width
            line.height = max(line.height, size.height)
            line.items.append(index)
        }
        if !line.items.isEmpty { done.append(line) }
        return done
    }
}
