#!/usr/bin/env python3
"""
Собирает иконки приложения из логотипа, нарисованного в макете.

    python3 tool/make_icons.py

Берёт design/png/логоС.png — рендер логотипа из Figma — и раскладывает
его по всем размерам, которые ждут iOS и Android.

Логотип в макете нарисован как скруглённый квадрат с зелёной обводкой.
Иконке приложения обводка не нужна: и iOS, и Android накладывают свою
маску скругления поверх, и обводка внутри неё читается как лишнее кольцо.
Поэтому логотип слегка увеличивается и обрезается по краям — контур
уходит за границу, остаётся ровное поле с ростком.
"""
import json
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit('нужен Pillow: pip install Pillow')

SRC = 'design/png/логоС.png'
SCREENS = 'design/screens.json'
GROUP = 'логоС'               # группа на канвасе: значок плюс подпись под него
BG = (198, 250, 183)          # #C6FAB7 — заливка логотипа из макета
OVERSCAN = 1.10               # насколько вылезти за края, чтобы срезать обводку

IOS_DIR = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
ANDROID = {                   # mipmap-<плотность> : сторона в пикселях
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
}


def icon_top_fraction() -> float:
    """Где в рендере кончается подпись и начинается сам значок.

    В макете группа «логоС» — это значок плюс текстовая подпись «для
    светлой темы ios» над ним, и рендер захватывает их вместе. Долю
    берём из выгрузки, а не подбираем: значок лежит отдельным фреймом
    внутри группы, и его смещение там записано.
    """
    if not os.path.exists(SCREENS):
        return 0.0
    for screen in json.load(open(SCREENS))['screens']:
        if screen['name'] != GROUP:
            continue
        for child in screen.get('children') or []:
            if child.get('type') == 'FRAME':
                return child['frame']['y'] / screen['frame']['h']
    return 0.0


def master(side: int = 1024) -> Image.Image:
    """Квадратная иконка нужной стороны, без прозрачности."""
    logo = Image.open(SRC).convert('RGBA')
    top = round(logo.height * icon_top_fraction())
    if top:
        logo = logo.crop((0, top, logo.width, logo.height))
    bbox = logo.getbbox()                     # убрать пустые поля рендера
    if bbox:
        logo = logo.crop(bbox)

    canvas = Image.new('RGB', (side, side), BG)
    # Вписываем логотип в квадрат с запасом, чтобы обводка ушла за край.
    scale = side * OVERSCAN / max(logo.size)
    w, h = (max(1, round(v * scale)) for v in logo.size)
    logo = logo.resize((w, h), Image.LANCZOS)
    canvas.paste(logo, ((side - w) // 2, (side - h) // 2), logo)
    return canvas


def main():
    if not os.path.exists(SRC):
        sys.exit(f'не нашёл {SRC} — сначала выгрузи макет '
                 f'через tool/figma_extract.py')
    big = master(1024)
    written = 0

    # iOS: размеры перечислены в Contents.json набора, читаем их оттуда,
    # чтобы не разойтись с тем, что ждёт Xcode.
    contents = os.path.join(IOS_DIR, 'Contents.json')
    if os.path.exists(contents):
        for entry in json.load(open(contents))['images']:
            name = entry.get('filename')
            if not name:
                continue
            base = float(entry['size'].split('x')[0])
            side = round(base * float(entry['scale'].rstrip('x')))
            big.resize((side, side), Image.LANCZOS).save(
                os.path.join(IOS_DIR, name))
            written += 1

    for density, side in ANDROID.items():
        d = f'android/app/src/main/res/mipmap-{density}'
        if not os.path.isdir(d):
            continue
        big.resize((side, side), Image.LANCZOS).save(
            os.path.join(d, 'ic_launcher.png'))
        written += 1

    print(f'иконок записано: {written}')


if __name__ == '__main__':
    main()
