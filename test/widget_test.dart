import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sprout/main.dart';
import 'package:sprout/model/garden.dart';
import 'package:sprout/widgets/glass_tab_bar.dart';
import 'package:sprout/widgets/plant_card.dart';
import 'package:sprout/widgets/room_picker.dart';

/// Экран из макета — iPhone 16/17 Pro.
const _screen = Size(402, 874);

/// pumpAndSettle тут не годится: у растений, которым пора пить, свечение
/// пульсирует бесконечно, и «покоя» в дереве не наступает никогда.
/// Прокручиваем фиксированное число кадров — этого хватает, чтобы пружины
/// доехали до цели.
Future<void> settle(WidgetTester tester, [int frames = 90]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = _screen * 3
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SproutApp());
  await settle(tester);
}

void main() {
  testWidgets('главный экран показывает комнату из макета', (tester) async {
    await pumpApp(tester);

    expect(find.text('Добро пожаловать,\n${Garden.owner}!'), findsOneWidget);
    expect(find.text('Спальня'), findsOneWidget);
    // В спальне два растения — они же в макете.
    expect(find.byType(PlantCard), findsNWidgets(2));
    expect(find.text('Баксик'), findsOneWidget);
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('Следующий полив через 8 дней'), findsOneWidget);
    expect(find.text('Следующий полив завтра'), findsOneWidget);
  });

  testWidgets('меню комнат вытекает из кнопки и переключает комнату',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Спальня'));
    await tester.pump();
    // Панель уже в дереве, но ещё не доехала: морфинг идёт пружиной.
    expect(find.byType(RoomMenu), findsOneWidget);
    final early = tester.getSize(
      find.descendant(of: find.byType(RoomMenu), matching: find.byType(Column)),
    );
    await settle(tester);
    final settled = tester.getSize(
      find.descendant(of: find.byType(RoomMenu), matching: find.byType(Column)),
    );
    expect(settled.height, greaterThan(early.height),
        reason: 'панель должна вырастать, а не появляться готовой');

    await tester.tap(find.text('Кухня'));
    await settle(tester);

    expect(find.byType(RoomMenu), findsNothing);
    expect(find.text('Кухня'), findsOneWidget);
    expect(find.text('Мурзик'), findsOneWidget);
  });

  testWidgets('нажатие на карточку открывает растение и возвращает обратно',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Баксик'));
    await settle(tester);

    expect(find.text('Тюльпан'), findsOneWidget);
    expect(find.text('Добавлен 2.11.2024'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_back));
    await settle(tester);
    expect(find.text('Тюльпан'), findsNothing);
  });

  testWidgets('поиск раскрывается из капсулы и фильтрует по всем комнатам',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(CupertinoIcons.search));
    await settle(tester);

    await tester.enterText(find.byType(CupertinoTextField), 'Лера');
    await settle(tester);

    // «Лера» живёт на кухне, а открыта спальня: поиск не ограничен комнатой.
    expect(find.byType(PlantCard), findsOneWidget);
    expect(
      find.descendant(of: find.byType(PlantCard), matching: find.text('Лера')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await settle(tester);
    expect(find.byType(PlantCard), findsNWidgets(2));
  });

  testWidgets('подложка таба растягивается в движении и собирается на месте',
      (tester) async {
    await pumpApp(tester);

    Size selection() =>
        tester.getSize(find.byKey(const ValueKey('tab-selection')));

    final atRest = selection().width;
    await tester.tap(find.text('Профиль'));
    // Первый кадр только применяет setState — пружина стартует со второго.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final moving = selection().width;
    await settle(tester);
    final arrived = selection().width;

    expect(moving, greaterThan(atRest),
        reason: 'в движении подложка должна вытягиваться');
    expect(arrived, closeTo(atRest, 0.5),
        reason: 'на месте она обязана собраться обратно');
  });

  testWidgets('склонение дней считается по-русски', (tester) async {
    String label(int days) => Plant(
          id: 'x',
          name: 'x',
          species: 'x',
          moisture: 0.5,
          daysUntilWatering: days,
          addedOn: DateTime(2024),
        ).wateringLabel;

    expect(label(0), 'Следующий полив сегодня');
    expect(label(1), 'Следующий полив завтра');
    expect(label(2), 'Следующий полив через 2 дня');
    expect(label(5), 'Следующий полив через 5 дней');
    expect(label(11), 'Следующий полив через 11 дней');
    expect(label(21), 'Следующий полив через 21 день');
    expect(label(22), 'Следующий полив через 22 дня');
  });
}
