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

Заодно ловит второй промах, тоже дошедший до Xcode: новый тип `Pulse` в
модели встал рядом с давним `private struct Pulse` в карточке растения.
Частный он или нет, для Swift неважно — оба объявлены в области модуля, и
это «invalid redeclaration». Обращения при этом все были верные, так что
первая проверка молчала.

Третий промах — порядок замыканий. У `sheet` и `fullScreenCover`
`onDismiss` объявлен ДО содержимого, а записанный вторым он туда не
переставится: несколько замыканий подряд Swift раздаёт строго в том
порядке, в каком они стоят у самого метода. Синтаксис при этом
безупречный, и `swiftc -parse` молчит.

Разбор нарочно грубый: имена типов и их статические члены собираются
регулярками. Пропустить он может, приврать — нет: если имя объявлено
где-то в исходниках, оно найдётся.
"""
import re
import sys
from pathlib import Path

# Синтезируется компилятором или приходит из протоколов — объявления нет.
# `updateAppShortcutParameters` — из `AppShortcutsProvider`: команды Siri
# объявлены в приложении, а их пересказ системе — в самом App Intents.
GIVEN = {"allCases", "self", "init", "rawValue", "ID", "id", "Type",
         "Element", "shared", "min", "max", "zero", "infinity", "pi",
         "updateAppShortcutParameters"}

DECL = re.compile(
    r"^\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+)?"
    r"(?:nonisolated(?:\(unsafe\))?\s+)?"
    r"(?:static\s+(?:let|var|func)|case|enum|struct|typealias)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)")
# Расширение с соответствием протоколу (`extension Int: Spoken`) типа
# приложения не делает: статические члены у `Int` свои, системные.
TYPE = re.compile(r"^(?:public\s+|private\s+|final\s+)*"
                  r"(?:(?:enum|struct|class)\s+([A-Z][A-Za-z0-9_]*)"
                  r"|extension\s+([A-Z][A-Za-z0-9_]*)\s*\{)")
# То же, но только объявления — без `extension`, которых у одного типа
# бывает сколько угодно.
BORN = re.compile(r"^(?:public\s+|private\s+|fileprivate\s+|internal\s+"
                  r"|final\s+)*"
                  r"(?:enum|struct|class|actor|protocol)\s+"
                  r"([A-Z][A-Za-z0-9_]*)")
USE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.([a-zA-Z_][A-Za-z0-9_]*)")
SELECTOR = re.compile(r"#selector\([^)]*\)")

# Замыкания, объявленные у SwiftUI до содержимого. Вторым такое замыкание
# записать нельзя — переставить их Swift не даст. Список короткий нарочно:
# сюда попадает то, на чём уже обожглись, а не всё, на чём можно.
EARLY = ("onDismiss",)
LATE = re.compile(r"^\s*\}\s*(" + "|".join(EARLY) + r")\s*:")


def main(root: str) -> int:
    files = sorted(Path(root).rglob("*.swift"))
    types: set[str] = set()
    members: set[str] = set()
    born: dict[str, list[str]] = {}
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8")
                                      .splitlines(), 1):
            found = TYPE.match(line)
            if found:
                types.add(found.group(1) or found.group(2))
            # Объявления верхнего уровня: вложенные в тип имена живут в
            # своей области и столкнуться не могут, поэтому отступ важен.
            found = BORN.match(line)
            if found and not line[:1].isspace():
                born.setdefault(found.group(1), []).append(f"{path}:{number}")
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
    # Два типа с одним именем в модуле Xcode не пускает, даже если один из
    # них частный: `private` ограничивает доступ, а не область имени.
    for name, where in sorted(born.items()):
        if len(where) > 1:
            problems.append(f"«{name}» объявлен дважды: " + ", ".join(where))

    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8")
                                      .splitlines(), 1):
            code = line.split("//")[0]
            # `#selector(Tapper.fire)` ссылается на метод объекта для
            # Objective-C, а не на статический член — сверять нечего.
            code = SELECTOR.sub("", code)
            found = LATE.match(code)
            if found:
                problems.append(
                    f"{path}:{number}: «{found.group(1)}» записан вторым "
                    "замыканием, а объявлен он до содержимого")
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
          f"{len(born)} объявлений, {len(files)} файлов")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "ios-native/Sprout"))
