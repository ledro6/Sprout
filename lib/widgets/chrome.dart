import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../design/pattern.dart';
import '../design/tokens.dart';

/// Плашка под чёлкой: логотип и название. В макете — 82×28 по центру
/// экрана, заливка #C6FAB7.
class SproutBadge extends StatelessWidget {
  const SproutBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: SproutColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SproutLogo(size: 21),
          SizedBox(width: 4),
          Text('Sprout', style: SproutText.wordmark),
        ],
      ),
    );
  }
}

/// Фон экрана: узор из капель и две белые растяжки поверх него.
///
/// Растяжки взяты из макета один в один: сплошной белый до 40% высоты
/// полосы, дальше сход в прозрачность. Благодаря им заголовок вверху и
/// панель внизу читаются, а узор не спорит с текстом.
class SproutBackground extends StatelessWidget {
  const SproutBackground({super.key, required this.scroll});

  /// Прокрутка контента. Узор едет медленнее — от этого появляется
  /// ощущение глубины, как у обоев за иконками на домашнем экране iOS.
  final ValueListenable<double> scroll;

  static const _washHeight = 166.0;
  static const _washStop = 0.4;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: SproutColors.background)),
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: scroll,
            builder: (context, value, _) =>
                SproutPattern(offset: Offset(0, -value * 0.25)),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _washHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SproutColors.background,
                  SproutColors.background,
                  Color(0x00FFFFFF),
                ],
                stops: [0, _washStop, 1],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _washHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SproutColors.background,
                  SproutColors.background,
                  Color(0x00FFFFFF),
                ],
                stops: [0, _washStop, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
