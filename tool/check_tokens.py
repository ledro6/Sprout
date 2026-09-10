#!/usr/bin/env python3
"""
Проверяет, что каждое обращение к токену объявлено.

    python3 tool/check_tokens.py ios-native/Sprout

Ловит ровно тот промах, который однажды дошёл до Xcode: при переписывании
`Palette` из неё вместе с ненужным вырезало `shadow` и `plateFill`, а
`swiftc -parse` этого не увидел — он проверяет синтаксис, а не имена.
Полная проверка имён требует компилятора с SwiftUI, то есть Mac; здесь
берётся то, что можно взять без него, — статические члены типов
приложения.

Разбор нарочно грубый: имена типов и их статические члены собираются
регулярками. Пропустить он может, приврать — нет: если имя объявлено
где-то в исходниках, оно найдётся.
"""
import re
import sys
from pathlib import Path

# Синтезируется компилятором или приходит из протоколов — объявления нет.
GIVEN = {"allCases", "self", "init", "rawValue", "ID", "id", "Type",
         "Element", "shared", "min", "max", "zero", "infinity", "pi"}

DECL = re.compile(
    r"^\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+)?"
    r"(?:static\s+(?:let|var|func)|case|enum|struct|typealias)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)")
TYPE = re.compile(r"^(?:public\s+|private\s+|final\s+)*"
                  r"(?:enum|struct|class|extension)\s+([A-Z][A-Za-z0-9_]*)")
USE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.([a-zA-Z_][A-Za-z0-9_]*)")


def main(root: str) -> int:
    files = sorted(Path(root).rglob("*.swift"))
    types: set[str] = set()
    members: set[str] = set()
    for path in files:
        for line in path.read_text(encoding="utf-8").splitlines():
            found = TYPE.match(line)
            if found:
                types.add(found.group(1))
            found = DECL.match(line)
            if found:
                members.add(found.group(1))
                if line.lstrip().startswith("case "):
                    # `case green, blue, violet` — перечисление в строку.
                    tail = line.split("case ", 1)[1].split("//")[0]
                    for name in tail.split(","):
                        name = name.strip().split("(")[0].split(":")[0]
                        if re.fullmatch(r"[a-zA-Z_][A-Za-z0-9_]*", name):
                            members.add(name)

    problems = []
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8")
                                      .splitlines(), 1):
            code = line.split("//")[0]
            for owner, member in USE.findall(code):
                if owner not in types or member in GIVEN or member in members:
                    continue
                problems.append(f"{path}:{number}: "
                                f"у {owner} нет члена «{member}»")

    if problems:
        print("\n".join(problems))
        print(f"\nне сошлось: {len(problems)}")
        return 1
    print(f"токены сходятся: {len(types)} типов, {len(members)} имён, "
          f"{len(files)} файлов")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "ios-native/Sprout"))
