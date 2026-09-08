#!/usr/bin/env python3
"""
Собирает иконки приложения из логотипов, нарисованных в макете.

    python3 tool/make_icons.py

В макете логотип нарисован дважды: «логоС» для светлой темы и «логоТ» для
тёмной. Знак в них один и тот же — те же контуры, та же коробка, та же
толщина обводки, — меняется только поле под ним: #CFF8C9 против #12360D.
Так же собираются и иконки: геометрия у них общая и берётся из выгрузки,
различаются они цветом.

Из рендера вырезается только сам знак. Рамка, в которую он вписан в
макете, иконке приложения не нужна: iOS кладёт поверх свою маску
скругления, и чужая рамка под ней читается вторым кольцом. Границы знака
тоже берутся из выгрузки, а не подбираются на глаз — там записаны и
коробка группы «лого», и толщина обводки листьев, которая выходит за эту
коробку вбок.

Поля от края иконки задаёт MARK_HEIGHT. Размеры и темы читаются из самого
набора иконок, чтобы не разойтись с тем, что ждёт Xcode.
"""
import json
import os
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit('нужен Pillow: pip install Pillow')

SCREENS = 'design/screens.json'
ICONSET = 'ios-native/Sprout/Assets.xcassets/AppIcon.appiconset'

# Тема из набора иконок → группа в макете и её рендер. None — обычная
# иконка, та, что показывается в светлой теме и везде, где темы нет.
SOURCES = {
    None: ('логоС', 'design/png/логоС.png'),
    'dark': ('логоТ', 'design/png/логоТ.png'),
}

MARK = 'лого'                 # группа с самим знаком внутри значка

# Какую долю стороны иконки занимает знак по высоте. Остальное — поля.
# В макете значок отдан знаку почти целиком (86% высоты), но там вокруг
# него есть рамка, которая держит форму. На домашнем экране форму держит
# маска iOS, и такому узкому знаку нужен воздух, иначе он выглядит
# втиснутым.
MARK_HEIGHT = 0.74


def layout(group):
    """Значок, знак внутри него, цвет поля и толщина обводки — из выгрузки."""
    if not os.path.exists(SCREENS):
        sys.exit(f'не нашёл {SCREENS} — сначала выгрузи макет '
                 f'через tool/figma_extract.py')
    for screen in json.load(open(SCREENS))['screens']:
        if screen['name'] != group:
            continue
        for frame in screen.get('children') or []:
            if frame.get('type') != 'FRAME':
                continue
            for mark in frame.get('children') or []:
                if mark.get('name') != MARK:
                    continue
                colour = frame['fills'][0]['color'].lstrip('#')
                fill = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4))
                return frame['frame'], mark['frame'], fill, stroke(mark)
    sys.exit(f'в {SCREENS} нет группы «{group}» со значком и «{MARK}» внутри')


def stroke(node):
    """Толщина обводки листьев: первая, что найдётся в группе знака."""
    if node.get('strokeWeight'):
        return float(node['strokeWeight'])
    for child in node.get('children') or []:
        found = stroke(child)
        if found:
            return found
    return 0.0


def matching(image, colour, tolerance):
    """Маска: белое там, где пиксель ближе tolerance к colour по всем каналам."""
    bands = image.split()
    mask = bands[3].point(lambda v: 255 if v > 200 else 0)
    for band, target in zip(bands, colour):
        mask = ImageChops.multiply(
            mask,
            band.point(lambda v, t=target: 255 if abs(v - t) <= tolerance else 0))
    return mask


def sprout(group, source):
    """Знак из рендера — без рамки и без полей, — цвет поля и его пропорция.

    Пропорция считается по макету, а не по вырезанному куску: в рендерах
    светлой и тёмной тем края сглажены по-разному, и пиксельные габариты
    могли бы разойтись на единицу. Тогда знак в двух иконках оказался бы
    разного размера, а он должен быть одним и тем же.
    """
    if not os.path.exists(source):
        sys.exit(f'не нашёл {source} — сначала выгрузи макет '
                 f'через tool/figma_extract.py')
    logo = Image.open(source).convert('RGBA')
    frame, mark, fill, width = layout(group)

    # Поле значка встречается в рендере только внутри рамки, поэтому его
    # габарит и есть сам значок в пикселях. Отсюда масштаб рендера.
    box = matching(logo, fill, tolerance=6).getbbox()
    if box is None:
        sys.exit(f'в {source} не нашлось поле значка')
    sx = (box[2] - box[0]) / frame['w']
    sy = (box[3] - box[1]) / frame['h']

    # Листья обведены по центру контура, и обводка выходит за коробку
    # группы вбок на половину толщины. Сверху и снизу концы срезаны
    # прямо — там запаса не нужно.
    bleed = width / 2
    window = (
        round(box[0] + (mark['x'] - bleed - frame['x']) * sx),
        round(box[1] + (mark['y'] - frame['y']) * sy),
        round(box[0] + (mark['x'] + mark['w'] + bleed - frame['x']) * sx),
        round(box[1] + (mark['y'] + mark['h'] - frame['y']) * sy),
    )
    return logo.crop(window).convert('RGB'), fill, (mark['w'] + width) / mark['h']


def master(mark, fill, aspect, side):
    """Квадратная иконка нужной стороны, без прозрачности."""
    canvas = Image.new('RGB', (side, side), fill)
    height = round(side * MARK_HEIGHT)
    width = max(1, round(height * aspect))
    canvas.paste(mark.resize((width, height), Image.LANCZOS),
                 ((side - width) // 2, (side - height) // 2))
    return canvas


def appearance(entry):
    """Тема записи в наборе: 'dark' или None у обычной иконки."""
    for look in entry.get('appearances') or []:
        if look.get('appearance') == 'luminosity':
            return look.get('value')
    return None


def main():
    contents = os.path.join(ICONSET, 'Contents.json')
    if not os.path.exists(contents):
        sys.exit(f'не нашёл {contents}')

    ready = {}
    written = 0
    for entry in json.load(open(contents))['images']:
        name = entry.get('filename')
        if not name:
            continue
        look = appearance(entry)
        if look not in SOURCES:
            sys.exit(f'в наборе есть тема «{look}», а в макете логотипа '
                     f'для неё нет')
        if look not in ready:
            ready[look] = sprout(*SOURCES[look])
        side = round(float(entry['size'].split('x')[0])
                     * float(entry.get('scale', '1x').rstrip('x')))
        master(*ready[look], side).save(os.path.join(ICONSET, name))
        written += 1

    print(f'иконок записано: {written} '
          f'({", ".join(look or "обычная" for look in ready)})')


if __name__ == '__main__':
    main()
