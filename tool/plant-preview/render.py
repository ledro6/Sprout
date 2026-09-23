"""
Собирает картинки видов в один лист с подписями.

    python3 tool/plant-preview/render.py папка вид…

Картинки рисует tool/plant-preview/main.swift; лист ложится в ту же папку
как sheet.png.
"""
import sys

from PIL import Image, ImageDraw

folder = sys.argv[1]
names = sys.argv[2:]
tiles = [Image.open(f'{folder}/{name}.ppm') for name in names]
width, height = tiles[0].size
columns = min(5, len(tiles))
rows = (len(tiles) + columns - 1) // columns
sheet = Image.new('RGB', (width * columns, height * rows), 'white')
draw = ImageDraw.Draw(sheet)
for index, (tile, name) in enumerate(zip(tiles, names)):
    x = (index % columns) * width
    y = (index // columns) * height
    sheet.paste(tile, (x, y))
    draw.text((x + 8, y + 8), name, fill='black')
sheet.save(f'{folder}/sheet.png')
