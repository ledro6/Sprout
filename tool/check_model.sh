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

# Виджет собирает только часть модели — файлы из списка в проекте. Тип из
# файла не из списка Xcode не простит, а здесь это видно и без Mac.
WIDGET_MODEL=$(python3 - <<'PY'
import re
src = open("ios-native/Sprout.xcodeproj/project.pbxproj", encoding="utf-8").read()
block = re.search(r'"Sprout" folder in "SproutWidgetExtension" target \*/ '
                  r'= \{.*?membershipExceptions = \((.*?)\);', src, re.S)
names = [line.strip().rstrip(",") for line in block.group(1).splitlines()]
print(" ".join("ios-native/Sprout/" + name for name in names
               if name.startswith("Model/")))
PY
)
# shellcheck disable=SC2086
"$SWIFTC" -typecheck $WIDGET_MODEL
echo "модель виджета собирается: $(echo "$WIDGET_MODEL" | wc -w) файлов"
"$SWIFTC" -O \
  ios-native/Sprout/Model/Lang.swift \
  ios-native/Sprout/Model/Season.swift \
  ios-native/Sprout/Model/Care.swift \
  ios-native/Sprout/Model/Trip.swift \
  ios-native/Sprout/Model/Store.swift \
  ios-native/Sprout/Model/Rig.swift \
  ios-native/Sprout/Model/Plants.swift \
  ios-native/Sprout/Model/Garden.swift \
  ios-native/Sprout/Model/Settings.swift \
  ios-native/Sprout/Model/Weave.swift \
  ios-native/Sprout/Model/Tint.swift \
  ios-native/Sprout/Model/Front.swift \
  ios-native/Sprout/Model/Sway.swift \
  ios-native/Sprout/Model/Frolic.swift \
  ios-native/Sprout/Model/Pulse.swift \
  ios-native/Sprout/Model/Crop.swift \
  ios-native/Sprout/Model/Recents.swift \
  ios-native/Sprout/Model/Score.swift \
  ios-native/Sprout/Model/Diary.swift \
  ios-native/Sprout/Model/Reminders.swift \
  ios-native/Sprout/Model/Rival.swift \
  ios-native/Sprout/Model/Species.swift \
  ios-native/Sprout/Model/Shots.swift \
  ios-native/Sprout/Model/Sculpt.swift \
  ios-native/Sprout/Model/Canvas.swift \
  ios-native/Sprout/Model/Leafart.swift \
  ios-native/Sprout/Model/Kit.swift \
  ios-native/Sprout/Model/Effort.swift \
  ios-native/Sprout/Model/Bench.swift \
  ios-native/Sprout/Model/Botany.swift \
  ios-native/Sprout/Model/Sample.swift \
  ios-native/Sprout/Model/Greenhouse.swift \
  tool/swift-model-check/main.swift \
  -o "$OUT/check"
# Сад пишет себя в Documents хозяина. Домашняя папка на время проверки
# своя, временная: иначе прогон подложил бы файл в настоящую и следующий
# прогон читал бы его вместо макетных данных.
mkdir -p "$OUT/home/Documents"
HOME="$OUT/home" "$OUT/check"
