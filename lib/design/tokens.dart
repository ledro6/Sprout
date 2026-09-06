import 'package:flutter/widgets.dart';

/// Значения из макета Figma «орпи». Не подобраны на глаз: выгружены
/// tool/figma_extract.py и отранжированы по частоте — то, что встречается
/// в макете десятки раз, и есть токен, остальное случайные значения.
///
/// Макет нарисован под ширину 402 pt (iPhone 16/17 Pro). Отступы отсюда
/// берутся как есть, а сетка карточек считается от реальной ширины экрана,
/// поэтому на 375 и на 430 ничего не разъезжается.
abstract final class SproutColors {
  /// Фон приложения.
  static const background = Color(0xFFFFFFFF);

  /// Узор из капель на фоне. В макете — #CFF8C9 с прозрачностью 30%.
  static const pattern = Color(0x4DCFF8C9);

  /// Основной текст.
  static const label = Color(0xFF000000);

  /// Текст на элементах управления (иконки таб-бара).
  static const labelSecondary = Color(0xFF1A1A1A);

  /// Системный синий iOS: активный таб, выбранная комната.
  static const accent = Color(0xFF0088FF);

  /// Зелёный логотипа.
  static const green = Color(0xFF37B551);

  /// Светло-зелёная плашка логотипа под чёлкой.
  static const greenSoft = Color(0xFFC6FAB7);

  /// Голубой капли на логотипе.
  static const water = Color(0xFF47B5E4);

  /// Подложка выбранного таба.
  static const selection = Color(0xFFEDEDED);

  /// Системная заливка iOS под пунктами меню.
  static const fill = Color(0x29787880);

  /// Тень карточек и панелей.
  static const shadow = Color(0x1F000000);

  /// Тревожное свечение: растение пора полить.
  static const thirsty = Color(0x66FF0000);

  /// То же свечение в критической стадии — полив сегодня.
  static const thirstyStrong = Color(0x99FF0000);

  /// Затемнение экрана под всплывающим меню.
  static const scrim = Color(0x24000000);
}

abstract final class SproutText {
  /// Шрифт намеренно не задан: на iOS система подставит SF Pro, на котором
  /// макет и нарисован, на Android — Roboto. Прибивать здесь '.SF Pro Text'
  /// нельзя, на Android такого файла нет и вместо текста будут квадраты.

  /// «Добро пожаловать, Святослав!» — SF Pro 590 26.3/34.
  static const greeting = TextStyle(
    fontSize: 26.3,
    height: 34 / 26.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: SproutColors.label,
  );

  /// Кнопка выбора комнаты — SF Pro 590 18/28.
  static const room = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
    color: SproutColors.accent,
  );

  /// Имя растения и влажность на карточке — SF Pro 510 16/19.
  static const cardTitle = TextStyle(
    fontSize: 16,
    height: 19 / 16,
    fontWeight: FontWeight.w500,
    color: SproutColors.label,
  );

  /// «Следующий полив...» — SF Pro 400 10/12.
  static const cardCaption = TextStyle(
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w400,
    color: SproutColors.label,
  );

  /// Подпись таба — SF Pro 590 10/12.
  static const tab = TextStyle(
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w600,
  );

  /// Пункт всплывающего меню — SF Pro 510 12.4/16.
  static const menuItem = TextStyle(
    fontSize: 12.4,
    height: 16 / 12.4,
    fontWeight: FontWeight.w500,
    color: SproutColors.label,
  );

  /// Заголовок экрана растения — SF Pro 590 21/28.
  static const navTitle = TextStyle(
    fontSize: 21,
    height: 28 / 21,
    fontWeight: FontWeight.w600,
    color: SproutColors.label,
  );

  /// Строка списка на экране растения — SF Pro 590 17/28.
  static const detail = TextStyle(
    fontSize: 17,
    height: 28 / 17,
    fontWeight: FontWeight.w600,
    color: SproutColors.label,
  );

  /// Название приложения на плашке под чёлкой.
  static const wordmark = TextStyle(
    fontSize: 15,
    height: 18.75 / 15,
    fontWeight: FontWeight.w400,
    color: SproutColors.label,
  );
}

/// Размеры и отступы макета в логических пикселях.
abstract final class SproutMetrics {
  /// Ширина, под которую нарисован макет.
  static const designWidth = 402.0;

  /// Боковое поле контента.
  static const margin = 33.0;

  /// Промежуток между карточками по горизонтали и по вертикали.
  static const gutter = 36.0;

  /// Скругление карточки.
  static const cardRadius = 26.0;

  /// Внутреннее поле карточки.
  static const cardPadding = 11.0;

  /// Скругление всплывающего меню.
  static const sheetRadius = 24.8;

  /// Высота панели таб-бара и кнопки поиска.
  static const barHeight = 62.0;

  /// Ширина панели таб-бара: четыре кнопки по 68 плюс поля.
  static const barWidth = 290.0;

  /// Поле от края экрана до панелей внизу.
  static const barMargin = 21.0;

  /// Просвет между таб-баром и кнопкой поиска.
  static const barGap = 8.0;

  /// Шаг между кнопками таб-бара.
  static const tabPitch = 68.0;

  /// Ширина подложки выбранного таба.
  static const tabSelectionWidth = 80.0;

  /// Высота подложки выбранного таба.
  static const tabSelectionHeight = 54.0;
}
