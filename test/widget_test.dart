import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sprout/glass/liquid_glass.dart';
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

  testWidgets('раскладка совпадает с макетом', (tester) async {
    await pumpApp(tester);

    // В тестах нет SF Pro, на котором нарисован макет, и приветствие
    // переносится иначе. Поэтому по вертикали сверяем не абсолютные
    // координаты, а расстояния от приветствия — они от шрифта не зависят.
    // По горизонтали и по размерам сверяем прямо с выгрузкой Figma.
    final hello = tester.getRect(find.textContaining('Добро пожаловать'));
    expect(hello.left, closeTo(33, 0.5));
    expect(hello.top, closeTo(73, 0.5));

    // Подпись комнаты: в макете её глифы стоят на 154..172, посреди
    // 44-пиксельной кнопки, которая начинается сразу под приветствием.
    final room = tester.getRect(find.text('Спальня'));
    expect(room.left, closeTo(33, 0.5));
    expect(room.center.dy, closeTo(hello.bottom + 22, 1.0));

    // Карточка: 150×207 при поле 33 и просвете 3 под кнопкой.
    final card = tester.getRect(find.byType(PlantCard).first);
    expect(card.left, closeTo(33, 0.5));
    expect(card.top, closeTo(hello.bottom + 44 + 3, 0.5));
    expect(card.width, closeTo(150, 0.5));
    expect(card.height, closeTo(207, 0.5));

    // Вторая карточка — через 36 pt.
    expect(tester.getRect(find.byType(PlantCard).at(1)).left,
        closeTo(219, 0.5));

    // Нижняя панель: 21 от краёв, высота 62, низ в 21 от края экрана.
    final bar = tester.getRect(find.byType(GlassTabBar));
    expect(bar.left, closeTo(21, 0.5));
    expect(bar.right, closeTo(381, 0.5));
    expect(bar.height, closeTo(62, 0.5));
    expect(bar.bottom, closeTo(874 - 21, 0.5));
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

    // Панель встаёт ровно по макету: 219×140, на 4 pt левее и ниже кнопки.
    final anchor = tester.getRect(find.byType(RoomPickerButton));
    final sheet = tester.getRect(find.descendant(
      of: find.byType(RoomMenu),
      matching: find.byType(LiquidGlass),
    ));
    expect(sheet.left, closeTo(anchor.left - 4, 0.5));
    expect(sheet.top, closeTo(anchor.top + 4, 0.5));
    expect(sheet.width, closeTo(219, 0.5));
    expect(sheet.height, closeTo(140, 0.5));

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

  test('число униформ в Dart и в шейдере совпадает', () {
    // Униформы задаются по индексу, а не по имени: лишний или забытый
    // setFloat сдвигает все последующие, и материал ломается без ошибки.
    // Поэтому считаем float прямо в .frag и сверяем с константой.
    const sizes = {
      'float': 1, 'vec2': 2, 'vec3': 3, 'vec4': 4,
      'mat2': 4, 'mat3': 9, 'mat4': 16,
    };
    final src = File(GlassProgram.asset).readAsStringSync();
    var floats = 0;
    for (final m in RegExp(r'^\s*uniform\s+(\w+)\s+(\w+)\s*;',
            multiLine: true)
        .allMatches(src)) {
      floats += sizes[m.group(1)] ?? 0; // sampler2D сюда не попадает
    }
    expect(floats, GlassProgram.uniformFloats,
        reason: 'shaders/liquid_glass.frag разъехался с '
            'GlassProgram.uniformFloats');
  });
}
