// Liquid Glass — материал в духе iOS 26.
//
// Обычное «матовое стекло» — это blur плюс полупрозрачная заливка, и оно
// не похоже на стекло, потому что у настоящего стекла есть толщина.
// Здесь она есть: из SDF формы строится поле высот (в центре линза толстая,
// к краю скруглённая), из него — нормаль поверхности, и по нормали
// смещается точка выборки фона. Это даёт преломление на краях — то самое,
// от чего эффект читается как стекло, а не как замыленный прямоугольник.
//
// Вторая форма и smooth-min нужны для «жидкости»: два элемента можно
// слить в один каплеобразный, как Apple делает при переходах.
//
// Шейдер идёт в ImageFilter.shader внутри BackdropFilter, поэтому
// действуют требования движка: первый uniform — vec2 с размером текстуры,
// первый sampler2D — то, что за стеклом.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2  uSize;        // размер текстуры — заполняет движок
uniform vec2  uCenterA;     // форма A: центр, в долях от uSize
uniform vec2  uHalfA;       // форма A: половина размера, в долях от uSize
uniform float uRadiusA;     // форма A: радиус скругления
uniform vec2  uCenterB;     // форма B — для слияния, в долях от uSize
uniform vec2  uHalfB;
uniform float uRadiusB;
uniform float uMerge;       // 0 — форма B выключена, иначе радиус слияния (px)
uniform float uThickness;   // ширина скоса-линзы от края внутрь, px
uniform float uRefract;     // сила преломления, px
uniform float uSpecular;    // яркость блика
uniform float uLightAngle;  // направление света, радианы
uniform vec4  uTint;        // подкрашивание стекла (rgb + сила в a)
uniform float uSaturation;  // насыщенность фона под стеклом
uniform float uGlow;        // ширина светящейся кромки, px
uniform float uAA;          // сглаживание края, px

uniform sampler2D uBackdrop;

out vec4 fragColor;

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

// Формы заданы в долях от размера области, а не в пикселях: движок сам
// решает, текстуру какого размера отдать фильтру, и в пикселях форма
// уехала бы. При значениях по умолчанию (центр 0.5, половина 0.5)
// стекло занимает всю область — совпадает с ClipRRect вокруг него.
float scene(vec2 p) {
    float d = sdRoundedBox(p - uCenterA * uSize, uHalfA * uSize, uRadiusA);
    if (uMerge > 0.0) {
        float b = sdRoundedBox(p - uCenterB * uSize, uHalfB * uSize, uRadiusB);
        d = smin(d, b, uMerge);
    }
    return d;
}

// --- геометрия стекла ------------------------------------------------

// Профиль линзы: 0 у самого края, 1 на глубине uThickness.
// Дуга окружности, а не линейный скос — у линейного нет characteristic
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
// координату внутрь: содержимое у границы продолжается зеркально, шва не видно.
vec2 mirrorUV(vec2 uv) {
    vec2 t = abs(fract((uv - 1.0) * 0.5) * 2.0 - 1.0);
    return clamp(t, vec2(0.0005), vec2(0.9995));
}

vec3 saturate3(vec3 c, float s) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(l), c, s);
}

void main() {
    vec2 p = FlutterFragCoord().xy;
    vec2 uv = p / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif

    float d = scene(p);

    // За пределами формы стекла нет — отдаём фон как есть.
    // Полупрозрачная кромка шириной uAA убирает лесенку.
    float inside = 1.0 - smoothstep(-uAA, uAA, d);
    if (inside <= 0.0) {
        fragColor = texture(uBackdrop, uv);
        return;
    }

    // Градиент SDF — направление «наружу» по поверхности.
    vec2 e = vec2(1.0, 0.0);
    vec2 grad = vec2(
        scene(p + e.xy) - scene(p - e.xy),
        scene(p + e.yx) - scene(p - e.yx)
    );
    float glen = length(grad);
    grad = glen > 1e-5 ? grad / glen : vec2(0.0, -1.0);

    float depth = -d;                                   // вглубь формы
    float t     = clamp(depth / max(uThickness, 1.0), 0.0, 1.0);
    float slope = lensSlope(t);

    // Нормаль поверхности: у края наклонена наружу, в центре смотрит вверх.
    vec3 n = normalize(vec3(grad * slope, 1.0));

    // Преломление: чем круче стенка, тем сильнее уводим выборку.
    // Знак «плюс» тянет наружное содержимое внутрь — край работает
    // как увеличительное стекло, а не как дырка.
    vec2 offset = grad * slope * uRefract;
    vec2 ruv = (p + offset) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    ruv.y = 1.0 - ruv.y;
#endif
    ruv = mirrorUV(ruv);

    vec3 bg = texture(uBackdrop, ruv).rgb;
    bg = saturate3(bg, uSaturation);

    // Подкрашивание — стекло не бесцветное, оно слегка молочное.
    vec3 col = mix(bg, uTint.rgb, uTint.a);

    // Зеркальный блик: направленный свет по нормали.
    vec3 L = normalize(vec3(cos(uLightAngle), sin(uLightAngle), 0.75));
    float spec = pow(max(dot(n, L), 0.0), 18.0);
    // Виден только на скосе — в плоской середине бликовать нечему.
    spec *= (1.0 - t);
    col += vec3(spec * uSpecular);

    // Светящаяся кромка: тонкая линия по самому краю, за счёт неё
    // стекло «отделяется» от фона даже на однотонной подложке.
    if (uGlow > 0.0) {
        float rim = 1.0 - smoothstep(0.0, uGlow, depth);
        // Ярче там, куда падает свет.
        float lit = 0.55 + 0.45 * dot(grad, normalize(L.xy));
        col += vec3(rim * lit * uSpecular * 0.5);
    }

    vec3 base = texture(uBackdrop, uv).rgb;
    fragColor = vec4(mix(base, col, inside), 1.0);
}
