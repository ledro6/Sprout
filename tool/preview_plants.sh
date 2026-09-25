#!/usr/bin/env bash
# Рисует двадцать готовых моделей без телефона: лист политых, лист сухих
# и цветы крупным планом.
#
#     tool/preview_plants.sh [папка]
#
# Собирает модель с растеризатором из tool/plant-preview/ и рисует каждый
# вид с текстурами и вырезами. Свет грубее, чем в RealityKit, формы и
# рисунок — те же.
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFTC="${SWIFTC:-$(command -v swiftc || echo /opt/swift/usr/bin/swiftc)}"
OUT="${1:-$(mktemp -d)}"
mkdir -p "$OUT/wet" "$OUT/dry"
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
# Модель — тем же списком, что у tool/check_model.sh: растение тянет за
# собой журнал и сад.
MODEL=$(grep -v '^#' tool/model-files.txt)
# shellcheck disable=SC2086
"$SWIFTC" -O $MODEL tool/plant-preview/main.swift -o "$BUILD/preview"
ALL="monstera ficus sansevieria zamioculcas spathiphyllum orchid aloe cactus
echeveria jade dracaena palm fern ivy chlorophytum violet begonia pelargonium
herbs tulip"
DRY="monstera spathiphyllum ficus fern ivy"
# shellcheck disable=SC2086
"$BUILD/preview" "$OUT/wet" 1 $ALL
# shellcheck disable=SC2086
"$BUILD/preview" "$OUT/dry" 0.05 $DRY
# Цветы крупно: у них детали мельче, чем видно на общем плане.
BLOOMS="spathiphyllum orchid cactus jade:Каланхоэ violet begonia pelargonium
pelargonium:Роза tulip"
mkdir -p "$OUT/bloom"
# shellcheck disable=SC2086
"$BUILD/preview" "$OUT/bloom" 1 --close $BLOOMS
# shellcheck disable=SC2086
python3 tool/plant-preview/render.py "$OUT/wet" $ALL
# shellcheck disable=SC2086
python3 tool/plant-preview/render.py "$OUT/dry" $DRY
# shellcheck disable=SC2086
python3 tool/plant-preview/render.py "$OUT/bloom" $BLOOMS
echo "$OUT/wet/sheet.png"
echo "$OUT/dry/sheet.png"
echo "$OUT/bloom/sheet.png"
