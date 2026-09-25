#!/usr/bin/env python3
"""
Значки Material Symbols (скруглённые) — векторами в res/drawable.

    python3 android/tool/fetch_icons.py

Список значков — то, что код зовёт как `R.drawable.ic_<имя>`; залитый вариант
— `ic_<имя>_fill`. Скачиваются только недостающие, из репозитория Google
material-design-icons, и лежат в проекте: сборке сеть не нужна.
"""
import re
import sys
import urllib.request
from pathlib import Path

ANDROID = Path(__file__).resolve().parent.parent
KOTLIN = ANDROID / "app" / "src" / "main" / "kotlin"
DRAWABLE = ANDROID / "app" / "src" / "main" / "res" / "drawable"
BASE = ("https://raw.githubusercontent.com/google/material-design-icons/master/"
        "symbols/android/{name}/materialsymbolsrounded/{name}{fill}_24px.xml")
USED = re.compile(r"R\.drawable\.ic_([a-z0-9_]+)")
# Свои рисунки, а не значки Material.
OWN = {"launcher_foreground", "launcher_monochrome", "stat_drop"}


def wanted():
    names = set()
    for path in KOTLIN.rglob("*.kt"):
        names.update(USED.findall(path.read_text(encoding="utf-8")))
    for path in (ANDROID / "app" / "src" / "main" / "res").rglob("*.xml"):
        names.update(re.findall(r"@drawable/ic_([a-z0-9_]+)", path.read_text(encoding="utf-8")))
    return sorted(names - OWN)


def fetch(icon):
    fill = icon.endswith("_fill")
    name = icon[:-5] if fill else icon
    url = BASE.format(name=name, fill="_fill1" if fill else "")
    with urllib.request.urlopen(url, timeout=30) as reply:
        text = reply.read().decode("utf-8")
    # Оттенок задаёт Compose; ссылка на атрибут темы в ресурсе ему мешает.
    text = re.sub(r'\s*android:tint="[^"]*"', "", text)
    return text


def main():
    DRAWABLE.mkdir(parents=True, exist_ok=True)
    missing = [icon for icon in wanted() if not (DRAWABLE / f"ic_{icon}.xml").exists()]
    failed = []
    for icon in missing:
        try:
            (DRAWABLE / f"ic_{icon}.xml").write_text(fetch(icon), encoding="utf-8")
            print("скачан", icon)
        except Exception as error:  # noqa: BLE001 — отчёт, а не падение
            failed.append(f"{icon}: {error}")
    for line in failed:
        print("не скачался", line)
    print(f"значков в коде: {len(wanted())}, скачано: {len(missing) - len(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
