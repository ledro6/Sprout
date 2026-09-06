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
/// Работает только на Impeller (iOS, Android). На вебе и на старом Skia
/// [ui.ImageFilter.shader] недоступен, поэтому там включается запасной
/// путь: размытие плюс подкраска. Он не выглядит стеклом, но и не падает.

/// Параметры материала. Значения в логических пикселях.
@immutable
class GlassSettings {
  const GlassSettings({
    this.blur = 18.0,
    this.thickness = 22.0,
    this.refraction = 14.0,
    this.specular = 0.5,
    this.lightAngle = -math.pi / 2.2,
    this.tint = const Color(0x14FFFFFF),
    this.saturation = 1.6,
    this.glow = 1.5,
  });

  /// Сигма размытия фона под стеклом.
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

  /// Плотный вариант: под ним читается текст. Аналог Regular у Apple.
  static const regular = GlassSettings();

  /// Прозрачный вариант: сильнее преломляет, слабее красит. Для случаев,
  /// когда важнее показать картинку под стеклом. Аналог Clear.
  static const clear = GlassSettings(
    blur: 8.0,
    thickness: 28.0,
    refraction: 20.0,
    specular: 0.65,
    tint: Color(0x0AFFFFFF),
    saturation: 1.8,
    glow: 2.0,
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

  static const _asset = 'shaders/liquid_glass.frag';

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
    return _pending ??= ui.FragmentProgram.fromAsset(_asset).then(
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
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.settings = GlassSettings.regular,
    this.child,
  });

  final BorderRadius borderRadius;
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

  /// Новый экземпляр шейдера на каждую сборку — это обязательно, а не
  /// расточительность. ImageFilter.shader сравнивается по идентичности
  /// шейдера, а RenderBackdropFilter при равенстве фильтра не помечает
  /// себя на перерисовку. Если переиспользовать один объект и только
  /// менять униформы, анимация встанет.
  ui.FragmentShader _buildShader(double radius) {
    final s = widget.settings;
    final shader = _program!.fragmentShader();

    // Порядок строго соответствует объявлению uniform в
    // shaders/liquid_glass.frag. Индексы 0–1 (uSize) заполняет движок.
    var i = 2;
    void f(double v) => shader.setFloat(i++, v);

    f(0.5); f(0.5);   // uCenterA — центр области
    f(0.5); f(0.5);   // uHalfA   — половина области, стекло занимает всю
    f(radius);        // uRadiusA
    f(0.0); f(0.0);   // uCenterB — вторая форма выключена
    f(0.0); f(0.0);   // uHalfB
    f(0.0);           // uRadiusB
    f(0.0);           // uMerge
    f(s.thickness);
    f(s.refraction);
    f(s.specular);
    f(s.lightAngle);
    f(s.tint.r); f(s.tint.g); f(s.tint.b); f(s.tint.a);
    f(s.saturation);
    f(s.glow);
    f(1.0);           // uAA

    // Сэмплер фона подставляет движок: для ImageFilter.shader первый
    // sampler2D заполняется им самим, руками его задавать не нужно.
    return shader;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    // Запасной путь: размытие и подкраска. Без преломления, но без падения.
    if (_program == null) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur),
          child: DecoratedBox(
            decoration: BoxDecoration(color: s.tint),
            child: widget.child,
          ),
        ),
      );
    }

    final radius = widget.borderRadius.topLeft.x;
    final shader = _buildShader(radius);

    _retired.add(shader);
    if (_retired.length > _retireDepth) {
      _retired.removeAt(0).dispose();
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: BackdropFilter(
        // Порядок важен: сначала размытие фона, потом преломление
        // размытого. Наоборот стекло теряет чёткую кромку.
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.shader(shader),
          inner: ui.ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur),
        ),
        child: widget.child,
      ),
    );
  }
}
