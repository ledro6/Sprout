#!/usr/bin/env bash
# Собирает и прогоняет модель нативного приложения.
#
#     tool/check_model.sh
#
# Модель зависит только от Foundation, поэтому её можно проверить где
# угодно, где есть Swift, — не открывая Xcode и не собирая приложение.
# Экраны так проверить нельзя: SwiftUI есть только на платформах Apple.
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFTC="${SWIFTC:-$(command -v swiftc || echo /opt/swift/usr/bin/swiftc)}"
if [ ! -x "$SWIFTC" ]; then
  echo "не нашёл swiftc; задай путь через SWIFTC=..." >&2
  exit 1
fi

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
"$SWIFTC" -O \
  ios-native/Sprout/Model/Garden.swift \
  tool/swift-model-check/main.swift \
  -o "$OUT/check"
"$OUT/check"
