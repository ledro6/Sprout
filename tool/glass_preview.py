#!/usr/bin/env python3
"""
Рендерит shaders/liquid_glass.frag вне Flutter, чтобы параметры стекла
можно было подбирать глазами, а не наугад в собранном приложении.

Тот же GLSL, что уходит в приложение: файл читается как есть, подменяются
только флаттеровские #include и FlutterFragCoord() — их на десктопном GL нет.

    python3 tool/glass_preview.py --out preview.png
    python3 tool/glass_preview.py --refract 40 --thickness 60
"""
import argparse
import math
import os
import re
import sys

import moderngl
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADER = os.path.join(ROOT, "shaders", "liquid_glass.frag")

VERT = """
#version 330 core
in vec2 in_pos;
void main() { gl_Position = vec4(in_pos, 0.0, 1.0); }
"""

# Флаттеровская обвязка, которой нет в десктопном GL.
#
# Ключевой момент: у Impeller (Metal/Vulkan) начало координат фрагмента —
# верхний левый угол, у десктопного GL — нижний левый. Без этой поправки
# всё под стеклом рендерится вверх ногами, и по превью нельзя судить
# ни о преломлении, ни о блике.
PRELUDE = """
#version 330 core
uniform float uViewportH;
vec2 FlutterFragCoord() {
    return vec2(gl_FragCoord.x, uViewportH - gl_FragCoord.y);
}
"""


def to_desktop_glsl(src: str) -> str:
    src = src.replace("#include <flutter/runtime_effect.glsl>", "")
    # precision-квалификаторы — из GLSL ES, десктопный компилятор их не ждёт
    src = re.sub(r"^\s*precision\s+\w+\s+float\s*;\s*$", "", src, flags=re.M)
    return PRELUDE + src


def test_background(w: int, h: int) -> Image.Image:
    """Фон, на котором преломление видно сразу: сетка ломается на кромке,
    цветные пятна протекают под стекло."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = (
                int(120 + 110 * math.sin(x / 90.0)),
                int(90 + 90 * math.sin((x + y) / 130.0 + 1.2)),
                int(150 + 100 * math.cos(y / 80.0)),
            )
    d = ImageDraw.Draw(img)
    for x in range(0, w, 40):
        d.line([(x, 0), (x, h)], fill=(255, 255, 255), width=2)
    for y in range(0, h, 40):
        d.line([(0, y), (w, y)], fill=(255, 255, 255), width=2)
    d.ellipse([w * 0.10, h * 0.55, w * 0.42, h * 0.87], fill=(255, 214, 10))
    d.rectangle([w * 0.60, h * 0.12, w * 0.90, h * 0.34], fill=(255, 55, 95))
    d.ellipse([w * 0.55, h * 0.62, w * 0.80, h * 0.88], fill=(48, 209, 88))
    return img


def sdf_mask(W, H, shapes, merge, aa=1.0):
    """Та же геометрия, что в шейдере: скруглённые прямоугольники,
    при merge>0 склеенные smooth-min. Нужна, чтобы наложить результат
    ровно на форму — как это делает ClipRRect во Flutter."""
    ys, xs = np.mgrid[0:H, 0:W].astype("f4")

    def sd(cx, cy, hx, hy, r):
        r = min(r, min(hx, hy))
        qx = np.abs(xs - cx) - hx + r
        qy = np.abs(ys - cy) - hy + r
        return (np.minimum(np.maximum(qx, qy), 0.0)
                + np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) - r)

    d = sd(*shapes[0])
    if merge > 0 and len(shapes) > 1:
        b = sd(*shapes[1])
        h = np.clip(0.5 + 0.5 * (b - d) / merge, 0.0, 1.0)
        d = b * (1 - h) + d * h - merge * h * (1 - h)
    # inside: 1 внутри, 0 снаружи, мягкая кромка шириной aa
    t = np.clip((d + aa) / (2 * aa), 0.0, 1.0)
    return (1.0 - (t * t * (3 - 2 * t))).astype("f4")


def gaussian_blur(img: Image.Image, sigma: float) -> Image.Image:
    """В приложении размытие делает ImageFilter.blur до шейдера
    (ImageFilter.compose). Здесь повторяем тот же порядок."""
    if sigma <= 0:
        return img
    from PIL import ImageFilter as PILFilter
    return img.filter(PILFilter.GaussianBlur(radius=sigma))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="glass_preview.png")
    ap.add_argument("--width", type=int, default=800)
    ap.add_argument("--height", type=int, default=600)
    ap.add_argument("--thickness", type=float, default=48.0)
    ap.add_argument("--refract", type=float, default=28.0)
    ap.add_argument("--specular", type=float, default=0.55)
    ap.add_argument("--light", type=float, default=-2.0, help="радианы")
    ap.add_argument("--saturation", type=float, default=1.35)
    ap.add_argument("--glow", type=float, default=2.5)
    ap.add_argument("--blur", type=float, default=14.0)
    ap.add_argument("--tint", default="1,1,1,0.10", help="r,g,b,a в 0..1")
    ap.add_argument("--merge", type=float, default=0.0,
                    help=">0 включает вторую форму и слияние")
    ap.add_argument("--sep", type=float, default=0.0,
                    help="расстояние между формами при --merge")
    args = ap.parse_args()

    W, H = args.width, args.height
    ctx = moderngl.create_context(standalone=True, backend="egl")

    src = to_desktop_glsl(open(SHADER).read())
    try:
        prog = ctx.program(vertex_shader=VERT, fragment_shader=src)
    except Exception as e:
        print("шейдер не скомпилировался:\n", e, file=sys.stderr)
        sys.exit(1)

    sharp = test_background(W, H)
    bg = gaussian_blur(sharp, args.blur)
    tex = ctx.texture((W, H), 3, bg.tobytes())
    tex.build_mipmaps()
    tex.use(0)

    def setu(name, val):
        if name in prog:
            prog[name].value = val

    setu("uViewportH", float(H))
    setu("uSize", (float(W), float(H)))
    shapes = []
    if args.merge > 0:
        sep = args.sep or W * 0.16
        setu("uCenterA", (0.5 - sep / W, 0.5))
        setu("uHalfA", (0.16, 0.16 * W / H))
        setu("uRadiusA", W * 0.16)
        setu("uCenterB", (0.5 + sep / W, 0.5))
        setu("uHalfB", (0.16, 0.16 * W / H))
        setu("uRadiusB", W * 0.16)
        shapes = [(W / 2 - sep, H / 2, W * 0.16, H * 0.16, W * 0.16),
                  (W / 2 + sep, H / 2, W * 0.16, H * 0.16, W * 0.16)]
    else:
        setu("uCenterA", (0.5, 0.5))
        setu("uHalfA", (0.32, 0.22))
        setu("uRadiusA", 56.0)
        setu("uCenterB", (0.0, 0.0))
        setu("uHalfB", (0.0, 0.0))
        setu("uRadiusB", 0.0)
        shapes = [(W / 2, H / 2, W * 0.32, H * 0.22, 56.0)]
    setu("uMerge", args.merge)
    setu("uThickness", args.thickness)
    setu("uRefract", args.refract)
    setu("uSpecular", args.specular)
    setu("uLightAngle", args.light)
    r, g, b, a = (float(x) for x in args.tint.split(","))
    setu("uTint", (r, g, b, a))
    setu("uSaturation", args.saturation)
    setu("uGlow", args.glow)
    setu("uAA", 1.0)
    setu("uBackdrop", 0)

    quad = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
    vao = ctx.vertex_array(prog, [(quad, "2f", "in_pos")])
    fbo = ctx.simple_framebuffer((W, H))
    fbo.use()
    fbo.clear(0, 0, 0, 1)
    vao.render(moderngl.TRIANGLES)

    out = Image.frombytes("RGB", (W, H), fbo.read(components=3))
    # GL считает начало координат снизу
    out = out.transpose(Image.FLIP_TOP_BOTTOM)

    # Во Flutter размывается только то, что под стеклом: BackdropFilter
    # живёт внутри ClipRRect. Повторяем — иначе на превью размыт весь
    # кадр и преломление на кромке не разглядеть.
    m = sdf_mask(W, H, shapes, args.merge)[..., None]
    out = Image.fromarray(
        (np.asarray(out, dtype="f4") * m
         + np.asarray(sharp, dtype="f4") * (1.0 - m)
         ).clip(0, 255).astype("u1"))
    out.save(args.out)
    print(f"готово: {args.out}")


if __name__ == "__main__":
    main()
