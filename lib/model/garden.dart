import 'package:flutter/foundation.dart';

/// Насколько срочно растение просит воды. От этого зависит красное
/// свечение карточки — в макете оно двух сил, #FF000066 и #FF000099.
enum Thirst {
  /// Полив нескоро, карточка спокойная.
  calm,

  /// Полив завтра — мягкое свечение.
  soon,

  /// Полив сегодня или уже просрочен — свечение сильнее.
  now;

  static Thirst fromDays(int days) => switch (days) {
        <= 0 => Thirst.now,
        1 => Thirst.soon,
        _ => Thirst.calm,
      };
}

@immutable
class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.moisture,
    required this.daysUntilWatering,
    required this.addedOn,
    this.photo = 'assets/plants/monstera.png',
  });

  final String id;

  /// Кличка, которую дал хозяин: «Баксик», «Сумка».
  final String name;

  /// Вид растения: «Тюльпан».
  final String species;

  /// Влажность почвы, 0..1.
  final double moisture;

  final int daysUntilWatering;
  final DateTime addedOn;
  final String photo;

  Thirst get thirst => Thirst.fromDays(daysUntilWatering);

  String get moistureLabel => '${(moisture * 100).round()}%';

  /// «Следующий полив сегодня / завтра / через 5 дней».
  String get wateringLabel {
    if (daysUntilWatering <= 0) return 'Следующий полив сегодня';
    if (daysUntilWatering == 1) return 'Следующий полив завтра';
    return 'Следующий полив через $daysUntilWatering '
        '${_plural(daysUntilWatering, 'день', 'дня', 'дней')}';
  }

  String get addedLabel =>
      'Добавлен ${addedOn.day}.${addedOn.month}.${addedOn.year}';
}

/// Русское склонение по числу: 1 день, 2 дня, 5 дней.
String _plural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  return switch (n % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}

@immutable
class Room {
  const Room({required this.name, required this.plants});

  final String name;
  final List<Plant> plants;
}

/// Данные из макета: те же клички, проценты и сроки полива.
abstract final class Garden {
  static final owner = 'Святослав';

  static final rooms = <Room>[
    Room(
      name: 'Спальня',
      plants: [
        Plant(
          id: 'baksik',
          name: 'Баксик',
          species: 'Тюльпан',
          moisture: 0.89,
          daysUntilWatering: 8,
          addedOn: DateTime(2024, 11, 2),
        ),
        Plant(
          id: 'pr',
          name: 'Пр',
          species: 'Монстера',
          moisture: 0.14,
          daysUntilWatering: 1,
          addedOn: DateTime(2025, 3, 17),
        ),
      ],
    ),
    Room(
      name: 'Гостиная',
      plants: [
        Plant(
          id: 'zelenik',
          name: 'Зеленик',
          species: 'Фикус',
          moisture: 0.30,
          daysUntilWatering: 2,
          addedOn: DateTime(2025, 1, 9),
        ),
      ],
    ),
    Room(
      name: 'Кухня',
      plants: [
        Plant(
          id: 'murzik',
          name: 'Мурзик',
          species: 'Монстера',
          moisture: 0.89,
          daysUntilWatering: 8,
          addedOn: DateTime(2024, 12, 20),
        ),
        Plant(
          id: 'privet',
          name: 'Привет',
          species: 'Замиокулькас',
          moisture: 0.14,
          daysUntilWatering: 1,
          addedOn: DateTime(2025, 2, 4),
        ),
        Plant(
          id: 'lera',
          name: 'Лера',
          species: 'Сансевиерия',
          moisture: 0.56,
          daysUntilWatering: 5,
          addedOn: DateTime(2025, 4, 28),
        ),
        Plant(
          id: 'sumka',
          name: 'Сумка',
          species: 'Спатифиллум',
          moisture: 0.01,
          daysUntilWatering: 0,
          addedOn: DateTime(2025, 6, 1),
        ),
        Plant(
          id: 'baksik-2',
          name: 'Баксик',
          species: 'Тюльпан',
          moisture: 0.89,
          daysUntilWatering: 8,
          addedOn: DateTime(2024, 11, 2),
        ),
      ],
    ),
  ];
}
