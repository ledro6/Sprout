#!/usr/bin/env python3
"""
Собирает иконку приложения из логотипа, нарисованного в макете.

    python3 tool/make_icons.py

Берёт design/png/логоС.png — рендер логотипа из Figma — и кладёт его в
набор иконок приложения. Начиная с Xcode 14 хватает одного файла
1024×1024: остальные размеры система делает сама.

В макете логотип нарисован внутри скруглённого квадрата с зелёной
обводкой. Иконке приложения ни квадрат, ни обводка не нужны: iOS кладёт
поверх свою маску скругления, и чужая рамка под ней читается вторым
кольцом. Раньше рамка убиралась тем, что рендер раздували на 110% и
срезали края, — вместе с рамкой уходили и поля, росток упирался в край, а
снизу ему отрезало стебель.

Теперь из рендера вырезается только сам росток. Где он лежит, известно из
выгрузки: значок и группа с ростком записаны там отдельными узлами со
своими координатами, так что окно поиска берётся оттуда, а не подбирается
на глаз. Дальше росток кладётся на ровное поле цвета значка, и поля
задаются одним числом — MARK_HEIGHT.
"""
import json
import os
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit('нужен Pillow: pip install Pillow')

SRC = 'design/png/логоС.png'
SCREENS = 'design/screens.json'
GROUP = 'логоС'               # группа на канвасе: значок плюс подпись над ним
MARK = 'лого'                 # группа с самим ростком внутри значка

ICONSET = 'ios-native/Sprout/Assets.xcassets/AppIcon.appiconset'

# Какую долю стороны иконки занимает росток по высоте. Остальное — поля.
# В макете значок отдан ростку почти целиком (86% высоты), но там вокруг
# него есть рамка, которая держит форму. На домашнем экране формы держит
# маска iOS, и такому узкому знаку нужен воздух, иначе он выглядит
# втиснутым.
MARK_HEIGHT = 0.74

# Запас вокруг ростка, в пунктах макета, внутри которого ищется его точный
# габарит. Вбок больше: обводка листьев выходит за коробку группы на
# половину своей толщины, а сверху и снизу срезана прямо.
BLEED_X, BLEED_Y = 8.0, 2.0


def layout():
    """Значок, росток внутри него и цвет заливки — из выгрузки макета."""
    if not os.path.exists(SCREENS):
        sys.exit(f'не нашёл {SCREENS} — сначала выгрузи макет '
                 f'через tool/figma_extract.py')
    for screen in json.load(open(SCREENS))['screens']:
        if screen['name'] != GROUP:
            continue
        for frame in screen.get('children') or []:
            if frame.get('type') != 'FRAME':
                continue
            for mark in frame.get('children') or []:
                if mark.get('name') != MARK:
                    continue
                colour = frame['fills'][0]['color'].lstrip('#')
                fill = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4))
                return frame['frame'], mark['frame'], fill
    sys.exit(f'в {SCREENS} нет группы «{GROUP}» со значком и «{MARK}» внутри')


def matching(image, colour, tolerance):
    """Маска: белое там, где пиксель ближе tolerance к colour по всем каналам."""
    bands = image.split()
    mask = bands[3].point(lambda v: 255 if v > 200 else 0)
    for band, target in zip(bands, colour):
        mask = ImageChops.multiply(
            mask,
            band.point(lambda v, t=target: 255 if abs(v - t) <= tolerance else 0))
    return mask


def sprout():
    """Росток, вырезанный из рендера: без рамки и без полей вокруг."""
    if not os.path.exists(SRC):
        sys.exit(f'не нашёл {SRC} — сначала выгрузи макет '
                 f'через tool/figma_extract.py')
    logo = Image.open(SRC).convert('RGBA')
    frame, mark, fill = layout()

    # Заливка значка встречается в рендере только внутри рамки, поэтому её
    # габарит и есть сам значок в пикселях. Отсюда масштаб рендера.
    box = matching(logo, fill, tolerance=6).getbbox()
    if box is None:
        sys.exit('в рендере не нашлась заливка значка')
    sx = (box[2] - box[0]) / frame['w']
    sy = (box[3] - box[1]) / frame['h']

    def place(x, y):
        return (round(box[0] + (x - frame['x']) * sx),
                round(box[1] + (y - frame['y']) * sy))

    left, top = place(mark['x'] - BLEED_X, mark['y'] - BLEED_Y)
    right, bottom = place(mark['x'] + mark['w'] + BLEED_X,
                          mark['y'] + mark['h'] + BLEED_Y)
    window = logo.crop((left, top, right, bottom))

    # Внутри окна всё, что не заливка, — сам росток. Обрезаем по нему, и
    # мелкая неточность масштаба перестаёт что-либо значить.
    ink = ImageChops.invert(matching(window, fill, tolerance=16))
    return window.crop(ink.getbbox()).convert('RGB'), fill


def master(mark, fill, side):
    """Квадратная иконка нужной стороны, без прозрачности."""
    canvas = Image.new('RGB', (side, side), fill)
    height = round(side * MARK_HEIGHT)
    width = max(1, round(height * mark.width / mark.height))
    canvas.paste(mark.resize((width, height), Image.LANCZOS),
                 ((side - width) // 2, (side - height) // 2))
    return canvas


def main():
    contents = os.path.join(ICONSET, 'Contents.json')
    if not os.path.exists(contents):
        sys.exit(f'не нашёл {contents}')
    mark, fill = sprout()

    # Размеры перечислены в самом наборе — читаем их оттуда, чтобы не
    # разойтись с тем, что ждёт Xcode.
    written = 0
    for entry in json.load(open(contents))['images']:
        name = entry.get('filename')
        if not name:
            continue
        side = round(float(entry['size'].split('x')[0])
                     * float(entry.get('scale', '1x').rstrip('x')))
        master(mark, fill, side).save(os.path.join(ICONSET, name))
        written += 1

    print(f'иконок записано: {written}')


if __name__ == '__main__':
    main()
