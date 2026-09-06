import 'package:flutter/cupertino.dart';

import '../design/tokens.dart';
import '../glass/liquid_glass.dart';
import '../motion/springs.dart';

/// Кнопка выбора комнаты: «Спальня ⌄».
///
/// Ключ [anchorKey] нужен, чтобы меню знало, из какого места экрана
/// вырастать: морфинг идёт от настоящих координат кнопки, а не от
/// заранее вписанных в код.
class RoomPickerButton extends StatelessWidget {
  const RoomPickerButton({
    super.key,
    required this.anchorKey,
    required this.room,
    required this.open,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final String room;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        // Пока меню открыто, кнопка чуть отступает назад: она «отдала»
        // себя всплывшей панели.
        scale: open ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: Alignment.centerLeft,
        child: Container(
          key: anchorKey,
          height: 44,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(room, style: SproutText.room),
              const SizedBox(height: 18, width: 3),
              AnimatedOpacity(
                opacity: open ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 15,
                  color: SproutColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Всплывающее меню комнат.
///
/// Панель не появляется поверх экрана готовой — она вытекает из кнопки:
/// один и тот же прямоугольник стекла пружиной меняет положение, размер
/// и скругление от габаритов кнопки до габаритов панели. Пункты при этом
/// проявляются с задержкой друг за другом, и меню читается как налившееся,
/// а не как подставленная картинка.
class RoomMenu extends StatefulWidget {
  const RoomMenu({
    super.key,
    required this.anchor,
    required this.rooms,
    required this.selected,
    required this.onPick,
    required this.onDismiss,
  });

  /// Прямоугольник кнопки в координатах экрана.
  final Rect anchor;
  final List<String> rooms;
  final int selected;
  final ValueChanged<int> onPick;
  final VoidCallback onDismiss;

  /// Размеры панели из макета.
  static const sheetWidth = 219.0;
  static const itemHeight = 35.0;
  static const itemGap = 7.5;
  static const sheetPadding = 10.0;

  static double sheetHeight(int count) =>
      sheetPadding * 2 + count * itemHeight + (count - 1) * itemGap;

  @override
  State<RoomMenu> createState() => _RoomMenuState();
}

class _RoomMenuState extends State<RoomMenu> with TickerProviderStateMixin {
  late final SpringController _open = SpringController(
    vsync: this,
    spring: Springs.morph,
  );

  @override
  void initState() {
    super.initState();
    _open.animateTo(1);
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _open.animateTo(0);
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sheet = Rect.fromLTWH(
      // В макете панель сдвинута на 4 pt левее и ниже кнопки.
      (widget.anchor.left - 4).clamp(8.0, size.width - RoomMenu.sheetWidth - 8),
      widget.anchor.top + 4,
      RoomMenu.sheetWidth,
      RoomMenu.sheetHeight(widget.rooms.length),
    );

    return SpringBuilder(
      controller: _open,
      builder: (context, raw, _) {
        final t = raw.clamp(0.0, 1.0);
        final rect = Rect.lerp(widget.anchor, sheet, t)!;
        final radius = _lerp(widget.anchor.height / 2, SproutMetrics.sheetRadius, t);

        return Stack(
          children: [
            // Затемнение и перехват касания мимо меню.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: ColoredBox(
                  color: SproutColors.scrim.withValues(
                    alpha: SproutColors.scrim.a * t,
                  ),
                ),
              ),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LiquidGlass(
                      borderRadius: radius,
                      settings: GlassSettings.sheet,
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(RoomMenu.sheetPadding),
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.rooms.length; i++) ...[
                            if (i > 0) const SizedBox(height: RoomMenu.itemGap),
                            Expanded(
                              child: _MenuItem(
                                label: widget.rooms[i],
                                selected: i == widget.selected,
                                // Пункты проявляются друг за другом: панель
                                // сначала наливается, потом наполняется.
                                progress: ((t - 0.35 - i * 0.09) / 0.45)
                                    .clamp(0.0, 1.0),
                                onTap: () {
                                  widget.onPick(i);
                                  _close();
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.selected,
    required this.progress,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - progress)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SproutColors.fill,
              borderRadius: BorderRadius.circular(RoomMenu.itemHeight / 2),
            ),
            child: Center(
              child: Text(
                label,
                style: SproutText.menuItem.copyWith(
                  color: selected ? SproutColors.accent : SproutColors.label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
