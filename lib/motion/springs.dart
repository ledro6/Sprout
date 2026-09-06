import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Пружины в терминах SwiftUI.
///
/// Apple задаёт анимацию не кривой Безье, а пружиной: длительностью и
/// «отскоком». Поэтому её движение выглядит физичным и, что важнее,
/// корректно прерывается — если пользователь дёрнул элемент на середине
/// анимации, тот продолжает со своей текущей скоростью, а не прыгает.
/// Кривая так не умеет: у неё нет понятия скорости.
///
/// Перевод из `Spring(duration:bounce:)`:
///   stiffness = (2π/duration)²
///   damping   = 4π(1 − bounce)/duration
/// при массе 1. bounce = 0 — критическое затухание (без перелёта),
/// bounce > 0 — перелёт, bounce < 0 — вялое переторможенное движение.
SpringDescription appleSpring({
  double duration = 0.5,
  double bounce = 0.0,
}) {
  assert(duration > 0);
  assert(bounce > -1.0 && bounce < 1.0);
  const twoPi = 2 * 3.141592653589793;
  final stiffness = (twoPi / duration) * (twoPi / duration);
  final damping = bounce >= 0
      ? 4 * 3.141592653589793 * (1 - bounce) / duration
      : 4 * 3.141592653589793 / ((1 + bounce) * duration);
  return SpringDescription(mass: 1.0, stiffness: stiffness, damping: damping);
}

/// Пресеты iOS. Названия и характер совпадают со SwiftUI, чтобы
/// сверяться с системными анимациями было можно на глаз.
abstract final class Springs {
  /// Плавно, без отскока. Появление и исчезновение, смена состояния.
  static final smooth = appleSpring(duration: 0.5, bounce: 0.0);

  /// Резче и с лёгким отскоком. Нажатия, переключатели, тактильный отклик.
  static final snappy = appleSpring(duration: 0.5, bounce: 0.15);

  /// Заметный отскок. Появление акцентных элементов, празднование.
  static final bouncy = appleSpring(duration: 0.5, bounce: 0.3);

  /// Быстрая реакция на касание — подсветка нажатия.
  static final press = appleSpring(duration: 0.25, bounce: 0.0);

  /// Морфинг стекла: медленнее и чуть упруго, чтобы перетекание
  /// читалось как жидкость, а не как подмена кадра.
  static final morph = appleSpring(duration: 0.6, bounce: 0.2);
}

/// Контроллер, доводящий значение до цели пружиной с сохранением скорости.
///
/// Смысл в [animateTo]: цель можно менять на лету, и движение продолжится
/// от текущего положения с текущей скоростью. Именно это отличает
/// «живой» интерфейс от последовательности проигранных роликов.
class SpringController extends ChangeNotifier {
  SpringController({
    required TickerProvider vsync,
    required SpringDescription spring,
    double initialValue = 0.0,
  })  : _controller = AnimationController.unbounded(
          vsync: vsync,
          value: initialValue,
        ) {
    _spring = spring;
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;
  late SpringDescription _spring;

  double get value => _controller.value;
  double get velocity => _controller.velocity;
  Animation<double> get animation => _controller;

  set spring(SpringDescription s) => _spring = s;

  /// Ведёт значение к [target]. [from] — начальная скорость: передай сюда
  /// скорость жеста, и элемент подхватит движение пальца без разрыва.
  TickerFuture animateTo(double target, {double? from}) {
    return _controller.animateWith(
      SpringSimulation(_spring, _controller.value, target,
          from ?? _controller.velocity),
    );
  }

  void snapTo(double v) => _controller.value = v;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Виджет, перестраивающийся при каждом шаге пружины.
class SpringBuilder extends StatelessWidget {
  const SpringBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.child,
  });

  final SpringController controller;
  final Widget Function(BuildContext, double value, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (c, ch) => builder(c, controller.value, ch),
      child: child,
    );
  }
}
