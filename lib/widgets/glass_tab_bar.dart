import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/tokens.dart';
import '../glass/liquid_glass.dart';
import '../motion/springs.dart';

@immutable
class TabItem {
  const TabItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const kSproutTabs = <TabItem>[
  TabItem(CupertinoIcons.house_fill, 'Главная'),
  TabItem(CupertinoIcons.chart_bar_alt_fill, 'Статистика'),
  TabItem(CupertinoIcons.plus_circle_fill, 'Добавить'),
  TabItem(CupertinoIcons.person_fill, 'Профиль'),
];

/// Нижняя панель: таб-бар и кнопка поиска — две стеклянные капсулы,
/// как в макете.
///
/// Здесь три анимации, и все три опираются на то, что форму стекла задаёт
/// шейдер, а не обрезка вокруг виджета.
///
/// 1. Подложка выбранного таба переезжает пружиной и при этом растягивается
///    по ходу движения: ширина считается из текущей скорости пружины.
///    Из-за перелёта пружины она успевает вытянуться и собраться обратно —
///    это и читается как «жидкость», а не как переставленный прямоугольник.
///
/// 2. Кнопка поиска, раскрываясь, наезжает на таб-бар. Пока между двумя
///    формами есть просвет, smooth-min тянет между ними перемычку — капсулы
///    стекаются в одну. Обрезкой такое не сделать: перемычка лежит вне
///    обоих прямоугольников.
///
/// 3. Подписи табов гаснут и разъезжаются, поле ввода проявляется.
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.index,
    required this.onIndexChanged,
    required this.searchOpen,
    required this.onSearchOpenChanged,
    required this.onQueryChanged,
  });

  final int index;
  final ValueChanged<int> onIndexChanged;
  final bool searchOpen;
  final ValueChanged<bool> onSearchOpenChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  /// Позиция подложки в номерах табов — дробная, пока едет.
  late final SpringController _slider = SpringController(
    vsync: this,
    spring: Springs.snappy,
    initialValue: widget.index.toDouble(),
  );

  /// Раскрытие поиска: 0 — капсула, 1 — поле во всю ширину.
  late final SpringController _search = SpringController(
    vsync: this,
    spring: Springs.morph,
  );

  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => widget.onQueryChanged(_query.text));
  }

  @override
  void didUpdateWidget(GlassTabBar old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) _slider.animateTo(widget.index.toDouble());
    if (widget.searchOpen != old.searchOpen) {
      _search.animateTo(widget.searchOpen ? 1 : 0);
      // Фокус и очистка поля дёргают чужое состояние: очистка через
      // onQueryChanged доходит до списка растений. didUpdateWidget идёт
      // внутри сборки кадра, и оттуда помечать чужие виджеты грязными
      // нельзя — откладываем до конца кадра.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.searchOpen) {
          _focus.requestFocus();
        } else {
          _focus.unfocus();
          _query.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _slider.dispose();
    _search.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SproutMetrics.barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const h = SproutMetrics.barHeight;
          const searchW = h;
          const gap = SproutMetrics.barGap;
          final tabsW = w - searchW - gap;
          // Шаг табов считается от реальной ширины: на 402 pt получается
          // ровно макетные 68, на узких экранах панель сжимается, а не
          // вылезает за край.
          final pitch = (tabsW - 12) / kSproutTabs.length;

          return AnimatedBuilder(
            animation: Listenable.merge([_slider.animation, _search.animation]),
            builder: (context, _) {
              final t = _search.value.clamp(0.0, 1.0);
              // Кнопка поиска разъезжается влево, наезжая на таб-бар.
              final searchLeft = _lerp(tabsW + gap, 0.0, t);
              final searchWidth = _lerp(searchW, w, t);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: LiquidGlass(
                      settings: GlassSettings.regular,
                      // Перемычка нужна только в движении: в покое капсулы
                      // в макете раздельные, и слипаться им нельзя.
                      merge: 20 * math.min(1.0, t * 4),
                      blobs: [
                        GlassBlob(Rect.fromLTWH(0, 0, tabsW, h), h / 2),
                        GlassBlob(
                          Rect.fromLTWH(searchLeft, 0, searchWidth, h),
                          h / 2,
                        ),
                      ],
                    ),
                  ),
                  _selection(tabsW, pitch, t),
                  _tabs(pitch, t),
                  _searchField(searchLeft, searchWidth, t),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Подложка выбранного таба.
  Widget _selection(double tabsW, double pitch, double t) {
    final v = _slider.value;
    // Растяжение по скорости: чем быстрее едет, тем длиннее. Предел
    // держит форму капсулой даже на резком переключении.
    final stretch = math.min(46.0, _slider.velocity.abs() * 9);
    final width = SproutMetrics.tabSelectionWidth + stretch;
    final center = 6 + pitch * (v + 0.5);

    return Positioned(
      key: const ValueKey('tab-selection'),
      left: center - width / 2,
      top: (SproutMetrics.barHeight - SproutMetrics.tabSelectionHeight) / 2,
      width: width,
      height: SproutMetrics.tabSelectionHeight,
      child: Opacity(
        opacity: 1 - t,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SproutColors.selection,
            borderRadius: BorderRadius.circular(
              SproutMetrics.tabSelectionHeight / 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs(double pitch, double t) {
    return Positioned(
      left: 6,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: t > 0.5,
        child: Row(
          children: [
            for (var i = 0; i < kSproutTabs.length; i++)
              SizedBox(
                width: pitch,
                child: _TabButton(
                  item: kSproutTabs[i],
                  selected: widget.index == i,
                  // Табы гаснут не разом, а волной слева направо: ближние
                  // к раскрывающемуся поиску уходят первыми.
                  fade: (1 - (t * 1.6 - i * 0.08)).clamp(0.0, 1.0),
                  onTap: () => widget.onIndexChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(double left, double width, double t) {
    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: SproutMetrics.barHeight,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSearchOpenChanged(!widget.searchOpen),
            child: SizedBox(
              width: SproutMetrics.barHeight,
              height: SproutMetrics.barHeight,
              child: Center(
                child: Icon(
                  // Крестик появляется только когда есть что закрывать.
                  t > 0.5 ? CupertinoIcons.xmark : CupertinoIcons.search,
                  size: 20,
                  color: SproutColors.labelSecondary,
                ),
              ),
            ),
          ),
          if (t > 0.01)
            Expanded(
              child: Opacity(
                opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                child: CupertinoTextField.borderless(
                  controller: _query,
                  focusNode: _focus,
                  placeholder: 'Найти растение',
                  style: SproutText.cardTitle,
                  padding: const EdgeInsets.only(right: 18),
                  onSubmitted: (_) => _focus.unfocus(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Крошечная обёртка: lerpDouble возвращает nullable, а здесь оба конца
/// всегда заданы, и разворачивать его в каждой строке шумно.
double _lerp(double a, double b, double t) => a + (b - a) * t;

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.fade,
    required this.onTap,
  });

  final TabItem item;
  final bool selected;
  final double fade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SproutColors.accent : SproutColors.labelSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: fade,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: SproutText.tab.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ],
        ),
      ),
    );
  }
}
