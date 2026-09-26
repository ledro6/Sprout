#!/usr/bin/env bash
# Проверки перед коммитом одним прогоном: разбор всех Swift-файлов, имена,
# проект, строки и модель — то же, что CI делает на Linux, и синтаксис
# экранов в придачу. Печатает итог каждой проверки, а при провале — её
# ошибки; последняя строка — GATE PASS или GATE FAIL.
#
#     tool/gate.sh
set -uo pipefail
cd "$(dirname "$0")/.."

SWIFTC="${SWIFTC:-$(command -v swiftc || echo /opt/swift/usr/bin/swiftc)}"
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
fail=0

# Каждая проверка идёт один раз; вывод — в файл, на экран — только хвост.
check() {
  local name=$1
  shift
  if "$@" > "$LOG" 2>&1; then
    tail -n 2 "$LOG"
  else
    fail=1
    echo "✗ $name"
    grep -E "error:|✗" "$LOG" | head -n 20
    tail -n 3 "$LOG"
  fi
}

check "синтаксис Swift" bash -c \
  "find ios-native -name '*.swift' -print0 | xargs -0 '$SWIFTC' -parse"
check "имена" python3 tool/check_tokens.py ios-native
check "проект" python3 tool/check_pbxproj.py \
  ios-native/Sprout.xcodeproj/project.pbxproj
check "строки" python3 tool/make_strings.py check
check "модель" bash tool/check_model.sh

if [ "$fail" = 0 ]; then echo "GATE PASS"; else echo "GATE FAIL"; fi
[ "$fail" = 0 ]
