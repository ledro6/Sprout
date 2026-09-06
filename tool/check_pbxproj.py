#!/usr/bin/env python3
"""
Проверяет project.pbxproj, не открывая Xcode.

    python3 tool/check_pbxproj.py ios-native/Sprout.xcodeproj/project.pbxproj

Файл написан руками, а Xcode на любую опечатку отвечает одинаково —
«не удалось открыть проект», без объяснений. Здесь ловится то, что
ломается чаще всего: неуравновешенные скобки и ссылки на объекты,
которых в файле нет.
"""
import re
import sys

UUID = re.compile(r"\b[0-9A-F]{24}\b")


def main(path: str) -> int:
    src = open(path, encoding="utf-8").read()
    problems = []

    # Скобки. Комментарии /* ... */ вырезаем: внутри них бывает всё.
    body = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    for open_ch, close_ch in (("{", "}"), ("(", ")")):
        if body.count(open_ch) != body.count(close_ch):
            problems.append(
                f"скобки {open_ch}{close_ch} не сходятся: "
                f"{body.count(open_ch)} против {body.count(close_ch)}")

    # Объявленные объекты: строка вида <UUID> = { или <UUID> /* ... */ = {
    declared = set(re.findall(r"^\s*([0-9A-F]{24})\s*(?:/\*.*?\*/)?\s*=\s*\{",
                              src, flags=re.M))
    referenced = set(UUID.findall(body))

    dangling = sorted(referenced - declared)
    if dangling:
        problems.append("ссылки в никуда: " + ", ".join(dangling))

    unused = sorted(declared - (referenced - declared) - _used(body, declared))
    if unused:
        problems.append("объявлены, но никем не используются: "
                        + ", ".join(unused))

    root = re.search(r"rootObject\s*=\s*([0-9A-F]{24})", src)
    if not root:
        problems.append("не найден rootObject")
    elif root.group(1) not in declared:
        problems.append(f"rootObject {root.group(1)} не объявлен")

    if problems:
        print(f"{path}: найдено проблем — {len(problems)}")
        for p in problems:
            print("  •", p)
        return 1

    print(f"{path}: объектов {len(declared)}, ссылки сходятся, скобки в порядке")
    return 0


def _used(body: str, declared: set) -> set:
    """UUID, встречающиеся не только в собственном объявлении."""
    used = set()
    for uid in declared:
        # Одно вхождение — это само объявление; больше — значит на объект
        # кто-то ссылается.
        if len(re.findall(uid, body)) > 1:
            used.add(uid)
    return used


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("укажи путь до project.pbxproj")
    sys.exit(main(sys.argv[1]))
