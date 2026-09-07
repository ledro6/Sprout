#!/usr/bin/env python3
"""
Собирает иконку приложения из логотипа, нарисованного в макете.

    python3 tool/make_icons.py

Берёт design/png/логоС.png — рендер логотипа из Figma — и кладёт его в
набор иконок приложения. Начиная с Xcode 14 хватает одного файла
1024×1024: остальные размеры система делает сама.

Логотип в макете нарисован как скруглённый квадрат с зелёной обводкой.
Иконке приложения обводка не нужна: iOS накладывает свою маску скругления
поверх, и обводка внутри неё читается как лишнее кольцо. Поэтому логотип
слегка увеличивается и обрезается по краям — контур уходит за границу,
остаётся ровное поле с ростком.
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

ICONSET = 'ios-native/Sprout/Assets.xcassets/AppIcon.appiconset'


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
    contents = os.path.join(ICONSET, 'Contents.json')
    if not os.path.exists(contents):
        sys.exit(f'не нашёл {contents}')

    # Размеры перечислены в самом наборе — читаем их оттуда, чтобы не
    # разойтись с тем, что ждёт Xcode.
    written = 0
    for entry in json.load(open(contents))['images']:
        name = entry.get('filename')
        if not name:
            continue
        side = round(float(entry['size'].split('x')[0])
                     * float(entry.get('scale', '1x').rstrip('x')))
        master(side).save(os.path.join(ICONSET, name))
        written += 1

    print(f'иконок записано: {written}')


if __name__ == '__main__':
    main()
