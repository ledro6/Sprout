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

# Виджет, часы и циферблат собирают только часть модели — файлы из своих
# списков в проекте. Тип из файла не из списка Xcode не простит, а здесь
# это видно и без Mac: каждая цель — отдельной проверкой.
SUBSETS=$(python3 - <<'PY'
import re
src = open("ios-native/Sprout.xcodeproj/project.pbxproj", encoding="utf-8").read()
for target, body in re.findall(
        r'"Sprout" folder in "(\w+)" target \*/ = \{.*?membershipExceptions = \((.*?)\);',
        src, re.S):
    # Имя с «+» Xcode пишет в кавычках.
    names = [line.strip().rstrip(",").strip('"') for line in body.splitlines()]
    files = ["ios-native/Sprout/" + name for name in names
             if name.startswith("Model/")]
    print(target + ":" + " ".join(files))
PY
)
while IFS=: read -r TARGET FILES; do
  # shellcheck disable=SC2086
  "$SWIFTC" -typecheck $FILES
  echo "модель цели $TARGET собирается: $(echo "$FILES" | wc -w) файлов"
done <<< "$SUBSETS"
# Список файлов — общий с tool/make_stock.py.
MODEL=$(grep -v '^#' tool/model-files.txt)
# shellcheck disable=SC2086
"$SWIFTC" -O $MODEL \
  tool/swift-model-check/main.swift \
  -o "$OUT/check"
# Сад пишет себя в Documents хозяина. Домашняя папка на время проверки
# своя, временная: иначе прогон подложил бы файл в настоящую и следующий
# прогон читал бы его вместо макетных данных.
mkdir -p "$OUT/home/Documents"
HOME="$OUT/home" "$OUT/check"
