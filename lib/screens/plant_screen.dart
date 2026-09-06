import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/tokens.dart';
import '../glass/liquid_glass.dart';
import '../model/garden.dart';
import '../widgets/chrome.dart';

/// Экран одного растения: навигация стеклянными капсулами, большое фото
/// и карточка со сведениями.
///
/// Появление собрано из анимации самого перехода: капсулы навигации,
/// фото и текст выезжают не одновременно, а с небольшим сдвигом друг за
/// другом. Так экран выглядит собирающимся, а не подставленным целиком —
/// приём Apple использует при любом push.
class PlantScreen extends StatelessWidget {
  const PlantScreen({super.key, required this.plant});

  final Plant plant;

  static Route<void> route(Plant plant) => CupertinoPageRoute<void>(
        builder: (_) => PlantScreen(plant: plant),
      );

  @override
  Widget build(BuildContext context) {
    final entry = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return Stack(
      children: [
        Positioned.fill(
          child: SproutBackground(scroll: _zero),
        ),
        // Прокрутка, а не Column во весь экран: макет нарисован под 874 pt,
        // а на телефоне поменьше или с длинным названием вида содержимое
        // перестаёт помещаться.
        SingleChildScrollView(
          // Навигация начинается на 68 pt — под плашкой Sprout, которая
          // висит в чёлке на 19..47. На устройстве с более высоким вырезом
          // отступ растёт вместе с ним, иначе кнопки заедут под плашку.
          padding: EdgeInsets.fromLTRB(
            SproutMetrics.margin,
            math.max(68.0, MediaQuery.paddingOf(context).top + 6),
            SproutMetrics.margin,
            // Место под нижнюю панель.
            120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Staggered(
                animation: entry,
                delay: 0.0,
                child: _nav(context),
              ),
              const SizedBox(height: 45),
              _Staggered(
                animation: entry,
                delay: 0.08,
                child: _photo(),
              ),
              const SizedBox(height: 44),
              _Staggered(
                animation: entry,
                delay: 0.16,
                child: _facts(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Навигация: кнопка назад, капсула заголовка, «ещё».
  /// В макете капсула выше кнопок — 63 против 47 — и они выровнены
  /// по общему центру.
  Widget _nav(BuildContext context) {
    return SizedBox(
      height: 63,
      child: Row(
        children: [
          _GlassButton(
            size: 47,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(CupertinoIcons.chevron_back,
                size: 22, color: SproutColors.label),
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: LiquidGlass(borderRadius: 31.5),
                ),
                Center(
                  child: Text(
                    plant.name,
                    style: SproutText.navTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 25),
          _GlassButton(
            size: 47,
            onTap: () {},
            child: const Icon(CupertinoIcons.ellipsis,
                size: 20, color: SproutColors.label),
          ),
        ],
      ),
    );
  }

  Widget _photo() {
    return AspectRatio(
      // Макет: плашка 336×347 — квадратное фото плюс 11 на поля.
      aspectRatio: 336 / 347,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(SproutMetrics.cardRadius),
                boxShadow: const [
                  BoxShadow(
                    color: SproutColors.shadow,
                    offset: Offset(0, 8),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: LiquidGlass(
              borderRadius: SproutMetrics.cardRadius,
              settings: GlassSettings.clear,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            bottom: 5,
            child: Hero(
              tag: 'plant-photo-${plant.id}',
              child: Image.asset(plant.photo, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _facts() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SproutMetrics.cardRadius),
              boxShadow: const [
                BoxShadow(
                  color: SproutColors.shadow,
                  offset: Offset(0, 8),
                  blurRadius: 40,
                ),
              ],
            ),
          ),
        ),
        const Positioned.fill(
          child: LiquidGlass(
            borderRadius: SproutMetrics.cardRadius,
            settings: GlassSettings.clear,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 22, 25, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Fact(plant.species),
              const SizedBox(height: 14),
              _Fact(plant.wateringLabel),
              const SizedBox(height: 14),
              _Fact(plant.addedLabel),
            ],
          ),
        ),
      ],
    );
  }
}

final _zero = ValueNotifier<double>(0);

class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('•', style: SproutText.detail),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: SproutText.detail)),
      ],
    );
  }
}

/// Сдвиг появления: тот же прогресс перехода, но с задержкой, из-за
/// которой элементы приходят по очереди.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.delay,
    required this.child,
  });

  final Animation<double> animation;
  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(delay, (delay + 0.7).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.size,
    required this.onTap,
    required this.child,
  });

  final double size;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: LiquidGlass(borderRadius: widget.size / 2),
              ),
              Center(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}
