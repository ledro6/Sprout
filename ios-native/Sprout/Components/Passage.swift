import SwiftUI
import UIKit

extension View {
    /// Свайп от края — назад и там, где своя кнопка «назад» заменила
    /// системную: UIKit, спрятав системную, выключает и жест, и экран без
    /// разворачивания из карточки закрывался только кнопкой.
    func sproutSwipeBack() -> some View {
        background(Passage(swipeBack: true).frame(width: 0, height: 0))
    }

    /// Экран встал (`true`) или тронулся с места (`false`) — по UIKit:
    /// SwiftUI сообщает только конец перехода, а свайп назад — это его
    /// начало.
    func sproutPassage(_ perform: @escaping (Bool) -> Void) -> some View {
        background(Passage(onlyBack: true, settled: perform)
            .frame(width: 0, height: 0))
    }

    /// Ночной экран в обеих темах — и там, куда тёмное окружение SwiftUI не
    /// достаёт: тёмным становится контроллер самого экрана в стеке, и
    /// строка состояния стиля `.default` над ним светлеет — она берёт тему
    /// у контроллера, который её ведёт, а при спрятанной панели навигации
    /// стек отдаёт её экрану наверху. `preferredColorScheme` перекрасил бы
    /// всё окно — и панель вкладок, и экран под этим. Тема живёт и уходит
    /// вместе со своим экраном: возвращать нечего, и брошенный свайп назад
    /// ничего не сбивает. Тема из настроек для этого задана окну, а не
    /// корню SwiftUI, — см. `WindowTheme`.
    func sproutNight() -> some View {
        background(Passage(night: true).frame(width: 0, height: 0))
    }

    /// Мягкий край сверху — только у экрана, который стоит. Въезжая и
    /// уезжая, экран нёс свой край поверх края соседа, и размытия ложились
    /// друг на друга рваной полосой. На ходу край гаснет — остаётся один, у
    /// того экрана, что стоит на месте.
    func sproutSettledEdge() -> some View {
        modifier(SettledEdge())
    }
}

private struct SettledEdge: ViewModifier {
    @State private var settled = false

    /// UIKit хоть раз сказал, стоит ли экран, — дальше верим ему.
    @State private var heard = false

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectHidden(!settled, for: .top)
            .background(Passage { now in
                heard = true
                withAnimation(Motion.edge) { settled = now }
            }.frame(width: 0, height: 0))
            // Страховка: мост к UIKit промолчал — край всё равно встаёт.
            .task {
                try? await Task.sleep(for: .seconds(0.7))
                guard !heard else { return }
                withAnimation(Motion.edge) { settled = true }
            }
    }
}

/// Мост к UIKit: когда экран встал и когда тронулся с места, жест возврата,
/// если своя кнопка «назад» его выключила, и ночная тема экрана.
private struct Passage: UIViewControllerRepresentable {
    var swipeBack = false
    /// «Тронулся» — только уходя назад, а не уступая место экрану вперёд.
    var onlyBack = false
    /// Экран тёмный в обеих темах — см. `sproutNight`.
    var night = false
    var settled: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> PassageKeeper {
        PassageKeeper()
    }

    func updateUIViewController(_ keeper: PassageKeeper, context: Context) {
        keeper.swipeBack = swipeBack
        keeper.onlyBack = onlyBack
        keeper.night = night
        keeper.settled = settled
    }

    /// Пока экран на виду, жест возврата спрашивает его, а не UIKit; ушёл —
    /// жест возвращается прежнему хозяину, и корень стека живёт
    /// по-системному.
    final class PassageKeeper: UIViewController, UIGestureRecognizerDelegate {
        var swipeBack = false
        var onlyBack = false
        var night = false
        var settled: (Bool) -> Void = { _ in }

        private weak var stack: UINavigationController?
        private weak var owner: UIGestureRecognizerDelegate?

        /// До первого кадра въезда: экран входит в стек уже тёмным.
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if night { darken() }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            settled(true)
            // Ещё раз, если на въезде стека над нами ещё не было.
            if night { darken() }
            guard swipeBack, let stack = navigationController,
                  let swipe = stack.interactivePopGestureRecognizer,
                  swipe.delegate !== self else { return }
            self.stack = stack
            owner = swipe.delegate
            swipe.delegate = self
            swipe.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if !onlyBack || leavingBack { settled(false) }
            guard let swipe = stack?.interactivePopGestureRecognizer,
                  swipe.delegate === self else { return }
            swipe.delegate = owner
        }

        /// Экран, который лежит прямо в стеке: сами мы вложены в него. Вне
        /// стека — пусто.
        private var screen: UIViewController? {
            var step: UIViewController? = self
            while let current = step,
                  !(current.parent is UINavigationController) {
                step = current.parent
            }
            return step
        }

        /// Экран уходит из стека — назад, а не под следующий.
        private var leavingBack: Bool {
            screen?.isMovingFromParent ?? true
        }

        /// Тёмным — только свой экран, не окно и не стек: соседи и панель
        /// вкладок остаются в теме приложения. Строку состояния
        /// пересчитывает корень — он раздаёт её по цепочке.
        private func darken() {
            guard let screen else { return }
            if screen.overrideUserInterfaceStyle != .dark {
                screen.overrideUserInterfaceStyle = .dark
            }
            var root = screen
            while let up = root.parent { root = up }
            root.setNeedsStatusBarAppearanceUpdate()
        }

        /// На корне жест не нужен — там он подвешивал бы стек; посреди
        /// перехода — тоже.
        func gestureRecognizerShouldBegin(
            _ gesture: UIGestureRecognizer
        ) -> Bool {
            guard let stack else { return false }
            return stack.viewControllers.count > 1
                && stack.transitionCoordinator == nil
        }
    }
}
