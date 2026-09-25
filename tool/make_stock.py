#!/usr/bin/env python3
"""
Растит готовые модели всех видов и кладёт их в каталог ресурсов.

    python3 tool/make_stock.py

Модели растит сама модель приложения (Model/Botany.swift, Nursery.swift и
соседи) — здесь, на компьютере: телефон получает их готовыми, открывает AR
сразу и не греется сборкой. Детализация одна на все телефоны — обычная.

Каждая модель — двоичный слепок `Kit`, сжатый DEFLATE без заголовка:
приложение распаковывает его `NSData.decompressed(using: .zlib)`, см.
Model/Workshop.swift. Выход — наборы данных
Assets.xcassets/Stock/stock-*.dataset и сводка tool/stock-models/manifest.json:
по ней проверка модели (tool/check_model.sh) замечает, что рецепты
поменялись, а модели в приложении ещё прежние. Поменял рецепт — запусти
заново.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ROOT = os.path.join(REPO, 'ios-native', 'Sprout', 'Assets.xcassets', 'Stock')
MANIFEST = os.path.join(HERE, 'stock-models', 'manifest.json')


def swiftc():
    found = os.environ.get('SWIFTC') or shutil.which('swiftc')
    if found:
        return found
    if os.path.exists('/opt/swift/usr/bin/swiftc'):
        return '/opt/swift/usr/bin/swiftc'
    sys.exit('не нашёл swiftc; задай путь через SWIFTC=...')


def model_files():
    with open(os.path.join(HERE, 'model-files.txt')) as source:
        return [os.path.join(REPO, line.strip()) for line in source
                if line.strip() and not line.startswith('#')]


def deflate(data):
    packer = zlib.compressobj(9, zlib.DEFLATED, -15)
    return packer.compress(data) + packer.flush()


def dataset(name, packed):
    folder = os.path.join(ROOT, f'{name}.dataset')
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f'{name}.kit'), 'wb') as out:
        out.write(packed)
    contents = {
        'data': [{
            'filename': f'{name}.kit',
            'idiom': 'universal',
            'universal-type-identifier': 'public.data',
        }],
        'info': {'author': 'xcode', 'version': 1},
    }
    with open(os.path.join(folder, 'Contents.json'), 'w') as out:
        json.dump(contents, out, indent=2)
        out.write('\n')


def main():
    if len(sys.argv) != 1:
        sys.exit(__doc__)
    with tempfile.TemporaryDirectory() as work:
        grower = os.path.join(work, 'stock')
        subprocess.run([swiftc(), '-O', *model_files(),
                        os.path.join(HERE, 'stock-models', 'main.swift'),
                        '-o', grower], check=True)
        kits = os.path.join(work, 'kits')
        os.makedirs(kits)
        subprocess.run([grower, kits], check=True)
        with open(os.path.join(kits, 'manifest.json')) as source:
            summary = json.load(source)

        # Прежние наборы — прочь: вид могли переименовать или убрать.
        if os.path.isdir(ROOT):
            shutil.rmtree(ROOT)
        os.makedirs(ROOT)
        with open(os.path.join(ROOT, 'Contents.json'), 'w') as out:
            json.dump({'info': {'author': 'xcode', 'version': 1}}, out,
                      indent=2)
            out.write('\n')
        raw = packed = 0
        for kit in summary['kits']:
            name = f"stock-{kit['preset']}"
            with open(os.path.join(kits, f'{name}.kit'), 'rb') as source:
                data = source.read()
            squeezed = deflate(data)
            dataset(name, squeezed)
            raw += len(data)
            packed += len(squeezed)
            print(f"  {kit['preset']}: {kit['triangles']} треугольников, "
                  f'{len(squeezed) // 1024} КБ')
        with open(MANIFEST, 'w') as out:
            json.dump(summary, out, indent=2, sort_keys=True)
            out.write('\n')
    print(f'  всего {len(summary["kits"])} моделей: {raw // 1024} КБ, '
          f'сжатые — {packed // 1024} КБ')


if __name__ == '__main__':
    main()
