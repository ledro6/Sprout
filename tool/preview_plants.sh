#!/usr/bin/env bash
# Рисует объёмные растения без телефона: лист политых, лист сухих и полив.
#
#     tool/preview_plants.sh [папка]
#
# Собирает модель с выгрузкой из tool/plant-preview/ и отрисовывает её
# растеризатором на numpy. Формы, позы, увядание и струя — те же, что в
# сцене; свет и материалы — грубее, чем в RealityKit.
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFTC="${SWIFTC:-$(command -v swiftc || echo /opt/swift/usr/bin/swiftc)}"
OUT="${1:-$(mktemp -d)}"
mkdir -p "$OUT/wet" "$OUT/dry"
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
# Модель — тем же списком, что у tool/check_model.sh: растение тянет за
# собой журнал и сад.
MODEL=$(sed -n 's|^ *\(ios-native/Sprout/Model/[A-Za-z]*\.swift\) \\$|\1|p' \
  tool/check_model.sh)
# shellcheck disable=SC2086
"$SWIFTC" -O $MODEL tool/plant-preview/main.swift -o "$BUILD/preview"
"$BUILD/preview" "$OUT/wet" 1
"$BUILD/preview" "$OUT/dry" 0.1
python3 tool/plant-preview/render.py "$OUT/wet" 0 1 2 3 4 5 6 7 8 9 10 11
python3 tool/plant-preview/render.py "$OUT/dry" 0 1 2 3 4 5 6 7 pour
echo "$OUT/wet/sheet.png"
echo "$OUT/dry/sheet.png"
