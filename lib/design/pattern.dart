import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Фоновый узор: чередование ростка и капли.
///
/// Контуры не нарисованы на глаз — это те же кривые, что в макете. Фигма
/// отдаёт их в fillGeometry при запросе с geometry=paths, отсюда и взяты.
abstract final class _Shapes {
  static const leafH = 42.2327;
  static const dropH = 42.2327;

  /// Росток: два листа, сходящихся к общей точке внизу.
  static final leaf = Path()
    ..moveTo(50.2067, 0)
    ..cubicTo(50.2067, 16.0251, 38.9675, 42.2327, 25.1033, 42.2327)
    ..cubicTo(11.2391, 42.2327, 0, 16.0251, 0, 0)
    ..cubicTo(25.1033, 0, 11.2391, 31.4466, 25.1033, 31.4466)
    ..cubicTo(38.9675, 31.4466, 25.1033, 0, 50.2067, 0)
    ..close();

  /// Капля.
  static final drop = Path()
    ..moveTo(30.4193, 27.0336)
    ..cubicTo(30.4193, 35.4278, 23.6097, 42.2327, 15.2097, 42.2327)
    ..cubicTo(6.8096, 42.2327, 0, 35.4278, 0, 27.0336)
    ..cubicTo(0, 18.6393, 14.513, 0, 15.2097, 0)
    ..cubicTo(15.9063, 0, 30.4193, 18.6393, 30.4193, 27.0336)
    ..close();
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  /// Шаг сетки из макета: ростки через 89.4 pt, капля — посередине между
  /// ними, ряды через 46.7 pt.
  static const _pitchX = 89.4;
  static const _pitchY = 46.68;
  static const _dropOffsetX = 55.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SproutColors.pattern;
    // Начинаем на шаг раньше нуля: иначе при сдвиге фона у края вылезает
    // пустая полоса.
    for (var y = -_pitchY; y < size.height + _pitchY; y += _pitchY) {
      for (var x = -_pitchX; x < size.width + _pitchX; x += _pitchX) {
        canvas
          ..save()
          ..translate(x, y)
          ..drawPath(_Shapes.leaf, paint)
          ..restore()
          ..save()
          ..translate(x + _dropOffsetX, y)
          ..drawPath(_Shapes.drop, paint)
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => false;
}

/// Узор во всю доступную площадь.
///
/// Сдвиг [offset] задаётся снаружи (например от прокрутки) и делается
/// трансформацией, а не перерисовкой: сам узор рисуется один раз и дальше
/// только двигается.
class SproutPattern extends StatelessWidget {
  const SproutPattern({super.key, this.offset = Offset.zero});

  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.translate(
        offset: offset,
        child: const RepaintBoundary(
          child: CustomPaint(
            painter: _PatternPainter(),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Логотип Sprout: два листа и две капли.
class SproutLogo extends StatelessWidget {
  const SproutLogo({super.key, this.size = 21});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 13 / 21,
      height: size,
      child: const CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Тот же росток, что в узоре, но контуром — как на плашке в макете.
    final s = size.height / (_Shapes.leafH * 1.35);
    canvas.save();
    canvas.scale(s);
    final stroke = Paint()
      ..color = SproutColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_Shapes.leaf, stroke);
    canvas.restore();

    // Капли воды над ростком.
    final water = Paint()..color = SproutColors.water;
    canvas.save();
    canvas.translate(size.width * 0.52, 0);
    canvas.scale(size.height / _Shapes.dropH * 0.16);
    canvas.drawPath(_Shapes.drop, water);
    canvas.restore();
    canvas.save();
    canvas.translate(0, size.height * 0.24);
    canvas.scale(size.height / _Shapes.dropH * 0.10);
    canvas.drawPath(_Shapes.drop, water);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
