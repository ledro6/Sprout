import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../glass/liquid_glass.dart';
import '../model/garden.dart';
import '../motion/springs.dart';

/// Карточка растения: стеклянная плашка, фото, кличка, влажность и срок
/// полива.
///
/// Анимаций две. Первая — нажатие: карточка уходит вглубь пружиной, и
/// вместе с ней сдвигается направление света, поэтому блик на кромке
/// «переезжает». Именно этот сдвиг блика отличает нажатие на стекло от
/// простого уменьшения масштаба.
///
/// Вторая — свечение у растения, которое пора полить: оно медленно
/// пульсирует. Красное пятно из макета статично, но неподвижная тревога
/// на экране быстро перестаёт читаться.
class PlantCard extends StatefulWidget {
  const PlantCard({
    super.key,
    required this.plant,
    required this.onTap,
  });

  final Plant plant;
  final VoidCallback onTap;

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> with TickerProviderStateMixin {
  late final SpringController _press = SpringController(
    vsync: this,
    spring: Springs.press,
  );

  /// Пульсация свечения. Отдельный контроллер заводится только у тех
  /// карточек, которым есть о чём предупреждать.
  AnimationController? _pulse;

  /// Свечение пульсирует бесконечно, поэтому оно же первое, что должно
  /// выключаться при «уменьшении движения» в системных настройках.
  /// Без этого на экране остаётся вечно дышащее пятно.
  bool get _wantsPulse =>
      widget.plant.thirst != Thirst.calm &&
      !MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(PlantCard old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    if (_wantsPulse && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();
    } else if (!_wantsPulse && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  void _setPressed(bool down) => _press.animateTo(down ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press.animation, _pulse]),
        builder: (context, child) {
          final p = _press.value.clamp(0.0, 1.0);
          // Пульсация: 0 в покое, 1 на пике. Синус, а не пила — иначе
          // на стыке периода видна ступенька.
          final beat = _pulse == null
              ? 0.0
              : 0.5 - 0.5 * math.cos(_pulse!.value * 2 * math.pi);

          return Transform.scale(
            scale: 1 - 0.04 * p,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(SproutMetrics.cardRadius),
                boxShadow: [_shadow(plant.thirst, beat, p)],
              ),
              child: child,
            ),
          );
        },
        child: _CardBody(plant: plant, press: _press),
      ),
    );
  }

  BoxShadow _shadow(Thirst thirst, double beat, double press) {
    // Нажатая карточка ближе к пальцу и дальше от «поверхности»: тень
    // собирается и подтягивается — так же, как у виджетов на домашнем
    // экране iOS.
    final lift = 1 - 0.45 * press;
    return switch (thirst) {
      Thirst.calm => BoxShadow(
          color: SproutColors.shadow,
          offset: Offset(0, 8 * lift),
          blurRadius: 40 * lift,
        ),
      Thirst.soon => BoxShadow(
          color: SproutColors.thirsty,
          offset: Offset(0, 8 * lift),
          blurRadius: (34 + 12 * beat) * lift,
          spreadRadius: 2 * beat,
        ),
      Thirst.now => BoxShadow(
          color: SproutColors.thirstyStrong,
          offset: Offset(0, 8 * lift),
          blurRadius: (34 + 16 * beat) * lift,
          spreadRadius: 1 + 4 * beat,
        ),
    };
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.plant, required this.press});

  final Plant plant;
  final SpringController press;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Стекло отдельным слоем под содержимым: BackdropFilter берёт то,
        // что нарисовано до него, поэтому текст в него попасть не должен.
        Positioned.fill(
          child: SpringBuilder(
            controller: press,
            builder: (context, v, _) => LiquidGlass(
              borderRadius: SproutMetrics.cardRadius,
              settings: GlassSettings.clear.copyWith(
                // Свет «съезжает» при нажатии — блик проходит по кромке.
                lightAngle: GlassSettings.clear.lightAngle + 0.5 * v,
                specular: GlassSettings.clear.specular * (1 + 0.35 * v),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SproutMetrics.cardPadding,
            vertical: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Hero(
                  tag: 'plant-photo-${plant.id}',
                  child: Image.asset(plant.photo, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      plant.name,
                      style: SproutText.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(plant.moistureLabel, style: SproutText.cardTitle),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 24,
                child: Text(
                  plant.wateringLabel,
                  style: SproutText.cardCaption,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
