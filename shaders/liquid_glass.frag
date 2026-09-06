// Liquid Glass — материал в духе iOS 26.
//
// Обычное «матовое стекло» — это blur плюс полупрозрачная заливка, и оно
// не похоже на стекло, потому что у настоящего стекла есть толщина.
// Здесь она есть: из SDF формы строится поле высот (в центре линза толстая,
// к краю скруглённая), из него — нормаль поверхности, и по нормали
// смещается точка выборки фона. Это даёт преломление на краях — то самое,
// от чего эффект читается как стекло, а не как замыленный прямоугольник.
//
// Вторая форма и smooth-min нужны для «жидкости»: два элемента сливаются
// в одну каплю с перемычкой, как у Apple при переходах.
//
// Форму задаёт шейдер, а не обрезка вокруг него: перемычка между двумя
// формами лежит вне обоих прямоугольников, и любой ClipRect её бы срезал.
// Поэтому и размытие тоже внутри — снаружи размывать нечего и не нужно.
//
// Шейдер идёт в ImageFilter.shader внутри BackdropFilter, поэтому
// действуют требования движка: первый uniform — vec2 с размером текстуры,
// первый sampler2D — то, что за стеклом.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2  uSize;        // размер текстуры в пикселях — заполняет движок
uniform vec2  uLogical;     // тот же прямоугольник в логических пикселях
uniform vec2  uCenterA;     // форма A: центр, логические px
uniform vec2  uHalfA;       // форма A: половина размера, логические px
uniform float uRadiusA;     // форма A: радиус скругления, логические px
uniform vec2  uCenterB;     // форма B — для слияния
uniform vec2  uHalfB;
uniform float uRadiusB;
uniform float uMerge;       // <=0 — форма B выключена, иначе радиус слияния
uniform float uThickness;   // ширина скоса-линзы от края внутрь
uniform float uRefract;     // сила преломления
uniform float uSpecular;    // яркость блика
uniform float uLightAngle;  // направление света, радианы
uniform vec4  uTint;        // подкрашивание стекла (rgb + сила в a)
uniform float uSaturation;  // насыщенность фона под стеклом
uniform float uGlow;        // ширина светящейся кромки
uniform float uAA;          // сглаживание края
uniform float uBlur;        // радиус размытия фона под стеклом

uniform sampler2D uBackdrop;

out vec4 fragColor;

// Все длины приходят в логических пикселях, а работаем мы в пикселях
// текстуры. Движок сам решает, какого размера её отдать, поэтому масштаб
// не угадываем, а считаем из того, что он же и сообщил.
float texScale() {
    return uLogical.x > 0.5 ? uSize.x / uLogical.x : 1.0;
}

// --- поля расстояний -------------------------------------------------

float sdRoundedBox(vec2 p, vec2 half_, float r) {
    r = min(r, min(half_.x, half_.y));
    vec2 q = abs(p) - half_ + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Полиномиальный smooth-min: там, где две формы сближаются, между ними
// нарастает перемычка — визуально они «стекаются» друг в друга.
float smin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float scene(vec2 p, float s) {
    float d = sdRoundedBox(p - uCenterA * s, uHalfA * s, uRadiusA * s);
    if (uMerge > 0.0) {
        float b = sdRoundedBox(p - uCenterB * s, uHalfB * s, uRadiusB * s);
        d = smin(d, b, uMerge * s);
    }
    return d;
}

// --- геометрия стекла ------------------------------------------------

// Профиль линзы: 0 у самого края, 1 на глубине uThickness.
// Дуга окружности, а не линейный скос — у линейного нет характерного
// «завала» света у кромки, и край выглядит фаской, а не стеклом.
float lensHeight(float t) {
    float u = 1.0 - clamp(t, 0.0, 1.0);
    return sqrt(max(1.0 - u * u, 0.0));
}

// Крутизна профиля. У самого края производная уходит в бесконечность —
// подрезаем, иначе на кромке появляется шум.
float lensSlope(float t) {
    float u = 1.0 - clamp(t, 0.0, 1.0);
    return min(u / sqrt(max(1.0 - u * u, 1e-4)), 6.0);
}

// Смещённая выборка может уйти за границу текстуры — у стекла на кромке
// экрана это давало полосу из растянутого крайнего пикселя. Отражаем
// координату внутрь: содержимое продолжается зеркально, шва не видно.
vec2 mirrorUV(vec2 uv) {
    vec2 t = abs(fract((uv - 1.0) * 0.5) * 2.0 - 1.0);
    return clamp(t, vec2(0.0005), vec2(0.9995));
}

vec3 saturate3(vec3 c, float s) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(l), c, s);
}

// Размытие фона. Считается только там, где стекло есть, — снаружи шейдер
// выходит раньше, и лишних выборок не делает.
const int   BLUR_TAPS = 16;
const float GOLDEN    = 2.39996323;   // золотой угол — витки не совпадают

vec3 blurBackdrop(vec2 uv, float radius, float phase) {
    vec3 acc = texture(uBackdrop, uv).rgb;
    if (radius <= 0.5) return acc;
    float wsum = 1.0;
    for (int i = 0; i < BLUR_TAPS; i++) {
        float fi = float(i) + 0.5;
        // Спираль Фогеля: точки ложатся по диску равномерно,
        // sqrt по радиусу не даёт им сгуститься в центре.
        float r = radius * sqrt(fi / float(BLUR_TAPS));
        float a = fi * GOLDEN + phase;
        // Гауссов вес: край диска влияет слабее, иначе получается
        // «размазывание коробкой» с заметной ступенькой.
        float w = exp(-1.5 * (r * r) / (radius * radius));
        acc  += texture(uBackdrop, mirrorUV(uv + vec2(cos(a), sin(a)) * r / uSize)).rgb * w;
        wsum += w;
    }
    return acc / wsum;
}

// Шестнадцати выборок на большой радиус мало, и одинаковая для всех
// пикселей спираль превращает нехватку в видимый узор — фон двоится.
// Поворот спирали на псевдослучайный угол размазывает ту же ошибку в шум,
// а шум под тонировкой и преломлением уже не читается.
float dither(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
}

void main() {
    vec2  p = FlutterFragCoord().xy;
    float s = texScale();
    vec2  uv = p / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif

    float d  = scene(p, s);
    float aa = max(uAA * s, 0.5);

    // За пределами формы стекла нет — отдаём фон нетронутым.
    // Полупрозрачная кромка шириной uAA убирает лесенку.
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (inside <= 0.0) {
        fragColor = texture(uBackdrop, uv);
        return;
    }

    // Градиент SDF — направление «наружу» по поверхности.
    vec2 e = vec2(1.0, 0.0);
    vec2 grad = vec2(
        scene(p + e.xy, s) - scene(p - e.xy, s),
        scene(p + e.yx, s) - scene(p - e.yx, s)
    );
    float glen = length(grad);
    grad = glen > 1e-5 ? grad / glen : vec2(0.0, -1.0);

    float depth = -d;                                    // вглубь формы
    float t     = clamp(depth / max(uThickness * s, 1.0), 0.0, 1.0);
    float slope = lensSlope(t);

    // Нормаль поверхности: у края наклонена наружу, в центре смотрит вверх.
    vec3 n = normalize(vec3(grad * slope, 1.0));

    // Преломление: чем круче стенка, тем сильнее уводим выборку.
    // Знак «плюс» тянет наружное содержимое внутрь — край работает
    // как увеличительное стекло, а не как дырка.
    vec2 ruv = (p + grad * slope * uRefract * s) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    ruv.y = 1.0 - ruv.y;
#endif
    ruv = mirrorUV(ruv);

    vec3 bg = blurBackdrop(ruv, uBlur * s, dither(p));
    bg = saturate3(bg, uSaturation);

    // Подкрашивание — стекло не бесцветное, оно слегка молочное.
    vec3 col = mix(bg, uTint.rgb, uTint.a);

    // Зеркальный блик: направленный свет по нормали.
    vec3 L = normalize(vec3(cos(uLightAngle), sin(uLightAngle), 0.75));
    float spec = pow(max(dot(n, L), 0.0), 18.0);
    // Виден только на скосе — в плоской середине бликовать нечему.
    spec *= (1.0 - t) * lensHeight(t);
    col += vec3(spec * uSpecular);

    // Светящаяся кромка: тонкая линия по самому краю, за счёт неё
    // стекло «отделяется» от фона даже на однотонной подложке.
    if (uGlow > 0.0) {
        float rim = 1.0 - smoothstep(0.0, uGlow * s, depth);
        float lit = 0.55 + 0.45 * dot(grad, normalize(L.xy));  // ярче к свету
        col += vec3(rim * lit * uSpecular * 0.5);
    }

    vec4 base = texture(uBackdrop, uv);
    fragColor = vec4(mix(base.rgb, col, inside), base.a);
}
