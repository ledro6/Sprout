import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Материал «жидкое стекло».
///
/// Flutter не наследует материалы UIKit — он рисует свои пиксели, поэтому
/// системный Liquid Glass из iOS 26 сюда не приходит сам по себе. Здесь он
/// собран из фрагментного шейдера: SDF формы даёт поле высот, из него
/// берётся нормаль, по нормали смещается выборка фона. Отсюда преломление
/// на кромке — то, чем стекло отличается от полупрозрачного прямоугольника
/// с размытием.
///
/// Форму задаёт шейдер, а не обрезка вокруг него. Из-за этого две формы
/// можно слить в одну каплю с перемычкой ([merge]) — перемычка лежит вне
/// обоих прямоугольников, и любой ClipRRect срезал бы её.
///
/// Работает только на Impeller (iOS, Android). На вебе и на старом Skia
/// [ui.ImageFilter.shader] недоступен, поэтому там включается запасной
/// путь: размытие плюс подкраска. Он не выглядит стеклом, но и не падает.

/// Одна форма стекла — скруглённый прямоугольник в координатах виджета.
@immutable
class GlassBlob {
  const GlassBlob(this.rect, this.radius);

  final Rect rect;
  final double radius;

  static GlassBlob lerp(GlassBlob a, GlassBlob b, double t) => GlassBlob(
        Rect.lerp(a.rect, b.rect, t)!,
        ui.lerpDouble(a.radius, b.radius, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is GlassBlob && other.rect == rect && other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// Параметры материала. Все длины — в логических пикселях.
@immutable
class GlassSettings {
  const GlassSettings({
    this.blur = 18.0,
    this.thickness = 20.0,
    this.refraction = 12.0,
    this.specular = 0.5,
    this.lightAngle = -math.pi / 2.2,
    this.tint = const Color(0xA6FFFFFF),
    this.saturation = 1.5,
    this.glow = 1.5,
  });

  /// Радиус размытия фона под стеклом.
  final double blur;

  /// Ширина скоса-линзы от кромки внутрь. Чем больше, тем «толще» стекло.
  final double thickness;

  /// Сила преломления. Хорошо смотрится примерно 0.5–0.7 от [thickness];
  /// выше — уже карикатурная линза.
  final double refraction;

  /// Яркость зеркального блика на скосе.
  final double specular;

  /// Направление света в радианах. Значение по умолчанию — свет сверху,
  /// как во всех системных материалах Apple.
  final double lightAngle;

  /// Подкраска стекла. Альфа задаёт силу подмешивания.
  final Color tint;

  /// Насыщенность фона под стеклом. Выше 1 — цвета «проступают» ярче,
  /// за счёт этого стекло кажется цветным, а не серым.
  final double saturation;

  /// Ширина светящейся кромки. Отделяет стекло от фона даже на однотонной
  /// подложке, где преломлять нечего.
  final double glow;

  /// Панели, поверх которых лежит текст: таб-бар, навбар. Плотная подкраска
  /// #FFFFFFA6 — ровно та, что стоит в макете. Аналог Regular у Apple.
  static const regular = GlassSettings();

  /// Плашки карточек. У слоя заливки в макете стоит #FFFFFF1A, но поверх
  /// него лежит эффект стекла, который сильно высветляет — на рендерах
  /// карточки заметно белее фона. Здесь эта суммарная плотность и задана,
  /// иначе плашка тонет в узоре. Аналог Clear у Apple.
  static const clear = GlassSettings(
    blur: 14.0,
    thickness: 26.0,
    refraction: 17.0,
    specular: 0.6,
    tint: Color(0x4DFFFFFF),
    saturation: 1.7,
    glow: 2.0,
  );

  /// Всплывающее меню: подложка плотнее и чуть холоднее, чтобы текст
  /// читался поверх любого содержимого экрана.
  static const sheet = GlassSettings(
    blur: 24.0,
    thickness: 18.0,
    refraction: 11.0,
    specular: 0.45,
    tint: Color(0x99F5F5F5),
    saturation: 1.4,
    glow: 1.2,
  );

  GlassSettings copyWith({
    double? blur,
    double? thickness,
    double? refraction,
    double? specular,
    double? lightAngle,
    Color? tint,
    double? saturation,
    double? glow,
  }) {
    return GlassSettings(
      blur: blur ?? this.blur,
      thickness: thickness ?? this.thickness,
      refraction: refraction ?? this.refraction,
      specular: specular ?? this.specular,
      lightAngle: lightAngle ?? this.lightAngle,
      tint: tint ?? this.tint,
      saturation: saturation ?? this.saturation,
      glow: glow ?? this.glow,
    );
  }

  static GlassSettings lerp(GlassSettings a, GlassSettings b, double t) {
    return GlassSettings(
      blur: ui.lerpDouble(a.blur, b.blur, t)!,
      thickness: ui.lerpDouble(a.thickness, b.thickness, t)!,
      refraction: ui.lerpDouble(a.refraction, b.refraction, t)!,
      specular: ui.lerpDouble(a.specular, b.specular, t)!,
      lightAngle: ui.lerpDouble(a.lightAngle, b.lightAngle, t)!,
      tint: Color.lerp(a.tint, b.tint, t)!,
      saturation: ui.lerpDouble(a.saturation, b.saturation, t)!,
      glow: ui.lerpDouble(a.glow, b.glow, t)!,
    );
  }
}

/// Загрузка и кеш скомпилированного шейдера.
///
/// Программа грузится один раз на всё приложение: каждая её загрузка —
/// это компиляция, и делать её на каждый виджет нельзя.
class GlassProgram {
  GlassProgram._();

  static const asset = 'shaders/liquid_glass.frag';

  /// Сколько float занимают все uniform шейдера вместе, включая те два,
  /// что заполняет движок. Униформы задаются по индексу, без имён, поэтому
  /// лишний или пропущенный setFloat сдвинет всё, что за ним, — и материал
  /// сломается молча. Число сверяется с самим .frag в тестах.
  static const uniformFloats = 27;

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _pending;
  static bool _failed = false;

  static ui.FragmentProgram? get programOrNull => _program;

  /// Поддерживается ли шейдерный путь вообще. False на вебе и везде,
  /// где движок не Impeller.
  static bool get isSupported =>
      !kIsWeb && ui.ImageFilter.isShaderFilterSupported && !_failed;

  /// Грузит программу. Вызывать один раз при старте приложения — тогда
  /// первое стекло появится уже готовым, без кадра-подмены.
  static Future<ui.FragmentProgram?> load() {
    if (_program != null) return Future.value(_program);
    if (!isSupported) return Future.value(null);
    return _pending ??= ui.FragmentProgram.fromAsset(asset).then(
      (p) => _program = p,
      onError: (Object e, StackTrace s) {
        // Не роняем приложение из-за материала: без шейдера остаётся
        // запасной путь, интерфейс продолжает работать.
        _failed = true;
        debugPrint('LiquidGlass: шейдер не загрузился, включён запасной '
            'путь (размытие без преломления). Причина: $e');
        return null;
      },
    );
  }
}

/// Стеклянная панель. Всё, что нарисовано позади, размывается
/// и преломляется в форме этого виджета.
///
/// По умолчанию стекло занимает весь виджет со скруглением [borderRadius].
/// Если задать [blobs], форма собирается из них: одна или две, при [merge]
/// больше нуля вторая «стекается» к первой.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    this.borderRadius = 24.0,
    this.blobs,
    this.merge = 0.0,
    this.settings = GlassSettings.regular,
    this.child,
  }) : assert(blobs == null || blobs.length <= 2,
            'шейдер знает про две формы; больше — это уже другой материал');

  /// Скругление, когда стекло занимает весь виджет.
  final double borderRadius;

  /// Явные формы в координатах виджета. Одна или две.
  final List<GlassBlob>? blobs;

  /// Радиус слияния форм в логических пикселях. Ноль — формы независимы.
  final double merge;

  final GlassSettings settings;
  final Widget? child;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  ui.FragmentProgram? _program;

  /// Шейдеры прошлых кадров. Освобождаем не сразу: отправленный кадр может
  /// ещё растеризоваться в другом потоке, и уничтожать его шейдер в этот
  /// момент нельзя. Держим очередь на несколько кадров — этого хватает
  /// с запасом, а расти она не может.
  final _retired = <ui.FragmentShader>[];
  static const _retireDepth = 3;

  @override
  void initState() {
    super.initState();
    _program = GlassProgram.programOrNull;
    if (_program == null && GlassProgram.isSupported) {
      GlassProgram.load().then((p) {
        if (mounted && p != null) setState(() => _program = p);
      });
    }
  }

  @override
  void dispose() {
    for (final s in _retired) {
      s.dispose();
    }
    _retired.clear();
    super.dispose();
  }

  List<GlassBlob> _shapes(Size size) =>
      widget.blobs ??
      [GlassBlob(Offset.zero & size, widget.borderRadius)];

  /// Новый экземпляр шейдера на каждую сборку — это обязательно, а не
  /// расточительность. ImageFilter.shader сравнивается по идентичности
  /// шейдера, а RenderBackdropFilter при равенстве фильтра не помечает
  /// себя на перерисовку. Если переиспользовать один объект и только
  /// менять униформы, анимация встанет.
  ui.FragmentShader _buildShader(Size size) {
    final s = widget.settings;
    final shapes = _shapes(size);
    final shader = _program!.fragmentShader();

    // Порядок строго соответствует объявлению uniform в
    // shaders/liquid_glass.frag. Индексы 0–1 (uSize) заполняет движок.
    var i = 2;
    void f(double v) => shader.setFloat(i++, v);
    void blob(GlassBlob? b) {
      f(b?.rect.center.dx ?? 0);
      f(b?.rect.center.dy ?? 0);
      f((b?.rect.width ?? 0) / 2);
      f((b?.rect.height ?? 0) / 2);
      f(b?.radius ?? 0);
    }

    // Логический размер области: по нему шейдер сам вычисляет, во сколько
    // раз текстура крупнее, и переводит все длины из логических пикселей
    // в пиксели текстуры. Гадать про devicePixelRatio не нужно.
    f(size.width);
    f(size.height);
    blob(shapes.first);
    blob(shapes.length > 1 ? shapes[1] : null);
    f(shapes.length > 1 ? widget.merge : 0.0);
    f(s.thickness);
    f(s.refraction);
    f(s.specular);
    f(s.lightAngle);
    f(s.tint.r);
    f(s.tint.g);
    f(s.tint.b);
    f(s.tint.a);
    f(s.saturation);
    f(s.glow);
    f(1.0); // uAA
    f(s.blur);
    assert(i == GlassProgram.uniformFloats,
        'записано ${i - 2} униформ вместо ${GlassProgram.uniformFloats - 2}; '
        'порядок разъехался с shaders/liquid_glass.frag');

    // Сэмплер фона подставляет движок: для ImageFilter.shader первый
    // sampler2D заполняется им самим, руками его задавать не нужно.
    return shader;
  }

  /// Запасной путь: размытие и подкраска по каждой форме отдельно.
  /// Без преломления и без перемычки, но и без падения.
  Widget _fallback(Size size) {
    final s = widget.settings;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final b in _shapes(size))
          Positioned.fromRect(
            rect: b.rect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(b.radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: s.tint),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        if (widget.child != null) SizedBox.fromSize(size: size, child: widget.child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'LiquidGlass должен получать ограниченный размер: форма стекла '
          'считается из него.',
        );
        final size = constraints.biggest;

        if (_program == null) return _fallback(size);

        final shader = _buildShader(size);
        _retired.add(shader);
        if (_retired.length > _retireDepth) {
          _retired.removeAt(0).dispose();
        }

        // Обрезки нет намеренно: за форму отвечает шейдер, а он за
        // пределами стекла возвращает фон нетронутым.
        return BackdropFilter(
          filter: ui.ImageFilter.shader(shader),
          child: SizedBox.fromSize(size: size, child: widget.child),
        );
      },
    );
  }
}
