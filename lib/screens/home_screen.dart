import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../model/garden.dart';
import '../widgets/chrome.dart';
import '../widgets/plant_card.dart';
import '../widgets/room_picker.dart';
import 'plant_screen.dart';

/// Главный экран: приветствие, выбор комнаты и сетка растений.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.query});

  /// Строка поиска из нижней панели.
  final ValueListenable<String> query;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  final _scrollValue = ValueNotifier<double>(0);
  final _anchor = GlobalKey();

  int _room = 0;
  OverlayEntry? _menu;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _scrollValue.value = _scroll.offset);
  }

  @override
  void dispose() {
    _menu?.remove();
    _scroll.dispose();
    _scrollValue.dispose();
    super.dispose();
  }

  /// Меню живёт в корневом Overlay, а не в дереве экрана: только так его
  /// затемнение накрывает и нижнюю панель, которая лежит в оболочке
  /// приложения выше по дереву.
  void _openMenu() {
    if (_menu != null) return;
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);

    final entry = OverlayEntry(
      builder: (context) => RoomMenu(
        anchor: origin & box.size,
        rooms: [for (final r in Garden.rooms) r.name],
        selected: _room,
        onPick: (i) => setState(() => _room = i),
        onDismiss: _closeMenu,
      ),
    );
    setState(() => _menu = entry);
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _closeMenu() {
    _menu?.remove();
    if (mounted) setState(() => _menu = null);
  }

  List<Plant> _plants(String query) {
    final plants = Garden.rooms[_room].plants;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return plants;
    // При поиске комната перестаёт ограничивать: искать растение
    // по имени логично во всей квартире.
    return [
      for (final room in Garden.rooms)
        for (final p in room.plants)
          if (p.name.toLowerCase().contains(q) ||
              p.species.toLowerCase().contains(q))
            p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth =
        (width - SproutMetrics.margin * 2 - SproutMetrics.gutter) / 2;

    return Stack(
      children: [
        Positioned.fill(child: SproutBackground(scroll: _scrollValue)),
        ValueListenableBuilder<String>(
          valueListenable: widget.query,
          builder: (context, query, _) {
            final plants = _plants(query);
            return CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        SproutMetrics.margin, 77, SproutMetrics.margin, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Добро пожаловать,\n${Garden.owner}!',
                          style: SproutText.greeting,
                        ),
                        const SizedBox(height: 9),
                        RoomPickerButton(
                          anchorKey: _anchor,
                          room: Garden.rooms[_room].name,
                          open: _menu != null,
                          onTap: _openMenu,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 3)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SproutMetrics.margin),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: SproutMetrics.gutter,
                      mainAxisSpacing: 25,
                      // Высота карточки из макета: поля 10, квадратное фото,
                      // 8, имя, 8, подпись в две строки, 10.
                      childAspectRatio: cardWidth / (cardWidth + 57),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => PlantCard(
                        plant: plants[i],
                        onTap: () => Navigator.of(context).push(
                          PlantScreen.route(plants[i]),
                        ),
                      ),
                      childCount: plants.length,
                    ),
                  ),
                ),
                // Место под нижнюю панель, чтобы последняя карточка
                // не пряталась за стеклом.
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ],
    );
  }
}
