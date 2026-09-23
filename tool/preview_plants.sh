#!/usr/bin/env bash
# Рисует двадцать готовых моделей без телефона: лист политых и лист сухих.
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
MODEL=$(sed -n 's|^ *\(ios-native/Sprout/Model/[A-Za-z]*\.swift\) \\$|\1|p' \
  tool/check_model.sh)
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
# shellcheck disable=SC2086
python3 tool/plant-preview/render.py "$OUT/wet" $ALL
# shellcheck disable=SC2086
python3 tool/plant-preview/render.py "$OUT/dry" $DRY
echo "$OUT/wet/sheet.png"
echo "$OUT/dry/sheet.png"
