import SwiftUI

/// Подсказки экрана поверх него самого: экран темнеет, в темноте — окно
/// вокруг того, о чём речь, рядом пузырь со словами. Показываются один раз
/// при первом заходе на экран, потом — по «?». Один экран за раз.
@MainActor
@Observable
final class Coach {
    static let shared = Coach()

    private(set) var walk: Walk?
    private(set) var step = 0

    /// Пусть сперва доиграет вход экрана и разложится вёрстка: окно, открытое
    /// на полпути, поехало бы следом.
    static let settle: Duration = .milliseconds(700)

    private init() {}

    /// Сами — только в первый запуск приложения, при первом заходе на экран
    /// и после знакомства: оно важнее. Со второго запуска — только по «?».
    func offer(_ walk: Walk) {
        let settings = Settings.shared
        guard self.walk == nil, settings.toured, settings.firstRun,
              !settings.seen(walk)
        else { return }
        start(walk)
    }

    func start(_ walk: Walk) {
        withAnimation(Motion.chrome) {
            self.walk = walk
            step = 0
        }
    }

    func next(of count: Int) {
        guard step + 1 < count else { return finish() }
        withAnimation(Motion.arrange) { step += 1 }
        Feel.pick()
    }

    /// Экран ушёл посреди подсказок или показывать пока нечего — не
    /// засчитываем: при следующем заходе они начнутся заново.
    func drop(_ walk: Walk) {
        guard self.walk == walk else { return }
        self.walk = nil
        step = 0
    }

    /// И «Пропустить», и последний шаг: экран больше сам не подсказывает.
    func finish() {
        if let walk { Settings.shared.mark(walk) }
        withAnimation(Motion.chrome) {
            walk = nil
            step = 0
        }
    }
}

/// Где на экране то, о чём подсказка, — якорем рамки.
struct HintSpots: PreferenceKey {
    static let defaultValue: [Hint.Target: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Hint.Target: Anchor<CGRect>],
                       nextValue: () -> [Hint.Target: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Это место подсвечивает подсказка `target`. Имя же — адрес для
    /// прокрутки: окно может ждать ниже края экрана.
    func hintSpot(_ target: Hint.Target) -> some View {
        anchorPreference(key: HintSpots.self, value: .bounds) {
            [target: $0]
        }
        .id(target)
    }

    /// Подсказки экрана `walk`. Прокрутка — чтобы довести до окна, которое
    /// ниже края.
    func walk(_ walk: Walk, scroll: ScrollViewProxy? = nil) -> some View {
        modifier(WalkHost(walk: walk, scroll: scroll))
    }
}

private struct WalkHost: ViewModifier {
    let walk: Walk
    let scroll: ScrollViewProxy?

    private let coach = Coach.shared

    func body(content: Content) -> some View {
        // Читаем здесь, в теле: изнутри замыкания настроек слежка за
        // `Coach` могла бы не сработать.
        let active = coach.walk == walk
        let step = coach.step
        content
            .overlayPreferenceValue(HintSpots.self) { spots in
                if active {
                    GeometryReader { proxy in
                        CoachLayer(hints: present(spots, in: proxy),
                                   step: step,
                                   size: proxy.size,
                                   insets: proxy.safeAreaInsets,
                                   scroll: scroll,
                                   next: { coach.next(of: $0) },
                                   skip: { coach.finish() },
                                   drop: { coach.drop(walk) })
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: Coach.settle)
                guard !Task.isCancelled else { return }
                coach.offer(walk)
            }
            // Ушли на другую вкладку — подсказки этого экрана подождут.
            .onDisappear { coach.drop(walk) }
    }

    /// Подсказки, чьё место сейчас есть на экране: пустые рамки не в счёт —
    /// такой кнопки сейчас нет.
    private func present(_ spots: [Hint.Target: Anchor<CGRect>],
                         in proxy: GeometryProxy) -> [(Hint, CGRect)] {
        walk.hints.compactMap { hint in
            guard let anchor = spots[hint.target] else { return nil }
            let rect = proxy[anchor]
            guard rect.width > 16, rect.height > 16 else { return nil }
            return (hint, rect)
        }
    }
}

/// Затемнение с окном, ободок окна и пузырь со стрелкой. Пузырь встаёт под
/// окном, если там хватает места, иначе над ним; большому окну — внизу
/// экрана, поверх.
private struct CoachLayer: View {
    let hints: [(Hint, CGRect)]
    let step: Int
    let size: CGSize
    let insets: EdgeInsets
    let scroll: ScrollViewProxy?
    let next: @MainActor (Int) -> Void
    let skip: @MainActor () -> Void
    let drop: @MainActor () -> Void

    /// Высота пузыря — замером; до замера — с запасом.
    @State private var tall: CGFloat = 230

    private enum Side { case below, above, pinned }

    private static let reach: CGFloat = 8
    private static let gap: CGFloat = 12
    private static let arrow: CGFloat = 10
    private static let edge: CGFloat = 16

    var body: some View {
        if hints.indices.contains(step) {
            let hint = hints[step].0
            let rect = hints[step].1
            let place = side(for: window(rect))
            // Пузырь внизу поверх большого окна — окно кончается над ним:
            // иначе пузырь лёг бы на ободок.
            let hole = place == .pinned ? trimmed(window(rect)) : window(rect)
            ZStack {
                shade(hole)
                ring(hole)
                if place != .pinned { pointer(hole, side: place) }
                bubble(hint, side: place, hole: hole)
            }
            .onAppear { reveal(hint.target, rect: rect) }
            .onChange(of: step) { reveal(hint.target, rect: rect) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        } else {
            // Мест этого экрана сейчас нет — подсказывать пока не о чем.
            Color.clear.onAppear { drop() }
        }
    }

    // MARK: - Окно

    /// Окно чуть шире места и не шире экрана.
    private func window(_ rect: CGRect) -> CGRect {
        let wide = rect.insetBy(dx: -Self.reach, dy: -Self.reach)
        let screen = CGRect(origin: .zero, size: size)
            .insetBy(dx: 4, dy: insets.top > 0 ? 4 : 0)
        return wide.intersection(screen).isNull ? wide : wide.intersection(screen)
    }

    /// Нижний край, до которого можно класть пузырь: над панелью вкладок.
    /// Безопасная зона её знает не всегда — поэтому не меньше запаса.
    private var floor: CGFloat { max(insets.bottom, Metrics.coachFloor) }

    /// Окно, обрезанное над пузырём внизу. Слишком низкое не режем: окно
    /// в палец высотой читалось бы поломкой.
    private func trimmed(_ hole: CGRect) -> CGRect {
        let top = size.height - floor - Self.edge - tall - Self.gap
        guard hole.maxY > top, top - hole.minY >= 60 else { return hole }
        return CGRect(x: hole.minX, y: hole.minY, width: hole.width,
                      height: top - hole.minY)
    }

    private func radius(_ hole: CGRect) -> CGFloat {
        min(Metrics.cardRadius + Self.reach, min(hole.width, hole.height) / 2)
    }

    private func shade(_ hole: CGRect) -> some View {
        Color.black.opacity(0.55)
            .overlay {
                RoundedRectangle(cornerRadius: radius(hole), style: .continuous)
                    .frame(width: hole.width, height: hole.height)
                    .position(x: hole.midX, y: hole.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .contentShape(Rectangle())
            // Нажатие в любом месте — дальше, как в подсказках системы.
            .onTapGesture { next(hints.count) }
            .accessibilityHidden(true)
    }

    /// Ободок дышит: глаз находит окно сразу.
    private func ring(_ hole: CGRect) -> some View {
        RoundedRectangle(cornerRadius: radius(hole), style: .continuous)
            .strokeBorder(Palette.accent, lineWidth: 2)
            .frame(width: hole.width, height: hole.height)
            .phaseAnimator([false, true]) { view, lit in
                view
                    .shadow(color: Palette.accent.opacity(lit ? 0.9 : 0.35),
                            radius: lit ? 14 : 6)
                    .scaleEffect(lit ? 1.015 : 1)
            } animation: { _ in .easeInOut(duration: 1.1) }
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Пузырь

    private func side(for hole: CGRect) -> Side {
        let need = tall + Self.gap + Self.arrow
        if size.height - floor - Self.edge - hole.maxY >= need {
            return .below
        }
        if hole.minY - insets.top - Self.edge >= need { return .above }
        return .pinned
    }

    private var width: CGFloat { min(size.width - 2 * Self.edge, 400) }

    /// Стрелка — к середине окна, но не за скругление пузыря.
    private func pointer(_ hole: CGRect, side: Side) -> some View {
        let left = (size.width - width) / 2 + 30
        let right = (size.width + width) / 2 - 30
        let x = min(max(hole.midX, left), right)
        let y = side == .below
            ? hole.maxY + Self.gap + Self.arrow / 2
            : hole.minY - Self.gap - Self.arrow / 2
        return Beak()
            .fill(Palette.background)
            .frame(width: Self.arrow * 2, height: Self.arrow)
            .rotationEffect(.degrees(side == .below ? 0 : 180))
            .position(x: x, y: y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func bubble(_ hint: Hint, side: Side, hole: CGRect) -> some View {
        let last = step == hints.count - 1
        let card = VStack(alignment: .leading, spacing: 8) {
            Text(Lang.format("%1$lld из %2$lld", step + 1, hints.count))
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(hint.title)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
            Text(hint.text)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if !last {
                    Button("Пропустить") { skip() }
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button { next(hints.count) } label: {
                    Text(last ? "Понятно" : "Дальше")
                        .font(Typography.detail)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.background)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height }
            action: { tall = $0 }
        .id(hint.id)
        .transition(.blurReplace)

        return Group {
            switch side {
            case .below:
                card
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .top)
                    .padding(.top, hole.maxY + Self.gap + Self.arrow)
            case .above:
                card
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .bottom)
                    .padding(.bottom,
                             size.height - hole.minY + Self.gap + Self.arrow)
            case .pinned:
                card
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .bottom)
                    .padding(.bottom, floor + Self.edge)
            }
        }
    }

    /// Окно ниже края — довести до него. Высокое — к верху, иначе его начало
    /// ушло бы за край.
    private func reveal(_ target: Hint.Target, rect: CGRect) {
        guard let scroll else { return }
        let visible = rect.minY >= insets.top
            && rect.maxY <= size.height - floor
        guard !visible else { return }
        let anchor: UnitPoint = rect.height > size.height * 0.55 ? .top : .center
        withAnimation(Motion.arrange) { scroll.scrollTo(target, anchor: anchor) }
    }
}

/// Стрелка пузыря — треугольник остриём вверх.
private struct Beak: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// «?» в заголовке экрана — подсказки ещё раз.
struct WalkButton: View {
    let walk: Walk

    /// В панели навигации стекло под кнопкой рисует система — своё легло
    /// бы вторым, и кнопка читалась бы двойной.
    var bare = false

    var body: some View {
        if bare {
            Button { Coach.shared.start(walk) } label: {
                Image(systemName: "questionmark")
            }
            .accessibilityLabel("Подсказки")
        } else {
            Button { Coach.shared.start(walk) } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: Metrics.gearGlyph - 4,
                                  weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Metrics.gearBox, height: Metrics.gearBox)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Подсказки")
        }
    }
}
