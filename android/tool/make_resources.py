#!/usr/bin/env python3
"""
Строки Android-версии: ресурсы на 48 языков из тех же таблиц, что у iOS.

    python3 android/tool/make_resources.py build   # записать ресурсы
    python3 android/tool/make_resources.py check   # проверить, ничего не пишет

Таблицы iOS (tool/strings/<язык>.json) только читаются: ключ — русский
текст, перевод — строка или формы числа. Строки, которые есть только на
Android (канал уведомлений, плитка быстрых настроек, ярлыки), лежат рядом —
android/strings/<язык>.json, в том же виде. Где перевод iOS говорит «iPhone»,
а на Android это просто телефон, — замена в android/strings/overrides/.

Код зовёт `Lang.text("…")` / `Lang.format("…", …)` по-русски, как на iOS.
Генератор даёт каждой строке имя ресурса по хэшу ключа и пишет таблицу
«ключ → ресурс» на Kotlin. Английский — ресурсы по умолчанию: его увидит
телефон на языке, которого нет в списке. Русский — values-ru, ключи как
есть.

Проверка ловит: ключ из кода без перевода, лишние ключи в таблице Android,
разные подстановки в ключе и переводе, неполные формы числа.
"""
import hashlib
import json
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ANDROID = Path(__file__).resolve().parent.parent
ROOT = ANDROID.parent
TABLES = ROOT / "tool" / "strings"
OVERLAY = ANDROID / "strings"
OVERRIDES = OVERLAY / "overrides"
RES = ANDROID / "app" / "src" / "main" / "res"
KOTLIN = ANDROID / "app" / "src" / "main" / "kotlin"
TABLE_KT = KOTLIN / "com" / "ledro6" / "sprout" / "platform" / "StringTable.kt"
FILE = "sprout_strings.xml"

LANGS = [
    "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr",
    "gu", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "kn", "ko", "lt",
    "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro",
    "ru", "sk", "sl", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi",
    "zh-Hans", "zh-Hant",
]

# Папки ресурсов. Иврит и индонезийский — под старыми кодами тоже: часть
# телефонов до сих пор зовёт их iw и in. Просто «pt» — бразильский, как у
# CLDR.
FOLDERS = {
    "en": ["values"],
    "he": ["values-iw", "values-he"],
    "id": ["values-in", "values-id"],
    "pt-BR": ["values-pt-rBR", "values-pt"],
    "pt-PT": ["values-pt-rPT"],
    "zh-Hans": ["values-b+zh+Hans"],
    "zh-Hant": ["values-b+zh+Hant"],
}

PLURALS = {
    "ar": ["zero", "one", "two", "few", "many", "other"],
    "cs": ["one", "few", "other"], "sk": ["one", "few", "other"],
    "hr": ["one", "few", "other"], "lt": ["one", "few", "other"],
    "pl": ["one", "few", "many", "other"],
    "ru": ["one", "few", "many", "other"],
    "uk": ["one", "few", "many", "other"],
    "ro": ["one", "few", "other"],
    "sl": ["one", "two", "few", "other"],
    "he": ["one", "two", "other"],
    "id": ["other"], "ja": ["other"], "ko": ["other"], "ms": ["other"],
    "th": ["other"], "vi": ["other"], "zh-Hans": ["other"],
    "zh-Hant": ["other"],
}
DEFAULT_PLURALS = ["one", "other"]

# Формы, которых нет в таблицах iOS, а Android (ICU) требует: `many` — для
# дробных (cs, sk, lt) и миллионов (es, fr, it, pt, ca). Счётчики приложения
# целые и небольшие, так что эти формы звучат как `other`.
ANDROID_PLURALS = {
    "cs": ["many"], "sk": ["many"], "lt": ["many"],
    "es": ["many"], "fr": ["many"], "it": ["many"], "pt": ["many"], "ca": ["many"],
}

SPEC = re.compile(r"%(?:\d+\$)?(?:\.\d+)?(?:ll|l|h|q)?[@dDiuUxXoOfeEgGcCsSaA]")
CYR = re.compile(r"[А-Яа-яЁё]")
CYRILLIC = {"ru", "uk", "bg", "kk"}

# Ключ — первый строковый литерал вызова. Сырые строки Kotlin (""") и
# шаблоны с ${…} ключами не бывают.
CALL = re.compile(r'\bLang\.(?:text|format|key)\(\s*"((?:[^"\\$]|\\.|\$(?![{A-Za-z_]))*)"')
# Шаблон Kotlin внутри ключа — ошибка: такой ключ не найдётся в таблице.
TEMPLATE = re.compile(r'\bLang\.(?:text|format|key)\(\s*"(?:[^"\\]|\\.)*?(?<!\\)\$[{A-Za-z_]')
# Строки, которые код называет не вызовом Lang, а ключом в таблице —
# `Key("…")` для списков, собранных заранее.
NAMED = re.compile(r'\bKey\(\s*"((?:[^"\\$]|\\.|\$(?![{A-Za-z_]))*)"')


# Строки, которые зовут XML-файлы (манифест, виджет, ярлыки), — под
# постоянными именами: хэш в XML не напишешь руками.
XML_NAMES = {
    "widget_name": "Кого полить",
    "widget_description": "Самые сухие растения и кнопка «Полить».",
    "shortcut_add": "Добавить",
    "shortcut_stats": "Статистика",
    "shortcut_search": "Поиск",
    "shortcut_thirst": "Кого полить",
    "tile_label": "Кого полить",
}


def load(folder, lang):
    path = folder / f"{lang}.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def strings(lang):
    """Перевод языка: таблица iOS и поверх — строки Android."""
    base = {k: v for k, v in load(TABLES, lang).items()
            if not k.startswith("_")}
    extra = {k: v for k, v in load(OVERLAY, lang).items()
             if not k.startswith("_")}
    clash = set(base) & set(extra)
    if clash:
        raise SystemExit(f"{lang}: ключи и в iOS, и в Android: {sorted(clash)[:3]}")
    base.update(extra)
    # Замены: перевод iOS, где сказано «iPhone», а на Android это телефон.
    base.update({k: v for k, v in load(OVERRIDES, lang).items() if not k.startswith("_")})
    return base


def plural_keys():
    """Ключи с формами числа — их знает английская таблица."""
    return {k for k, v in strings("en").items() if isinstance(v, dict)}


def all_keys():
    return set(strings("en"))


def name(key, prefix):
    return prefix + hashlib.sha1(key.encode("utf-8")).hexdigest()[:10]


def java(text):
    """Подстановки iOS → Java: %@ → %s, %lld → %d, позиции как есть."""
    def one(match):
        spec = match.group(0)
        if spec.endswith("@"):
            return spec[:-1] + "s"
        return re.sub(r"(?:ll|l|h|q)(?=[dDiuU])", "", spec).replace(
            "D", "d").replace("i", "d").replace("u", "d").replace("U", "d")
    return SPEC.sub(one, text)


def xml_text(text):
    """Текст ресурса: экранирование aapt и XML."""
    out = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"')
    out = out.replace("\n", "\\n").replace("\t", "\\t")
    if out.startswith("@") or out.startswith("?"):
        out = "\\" + out
    return escape(out)


def formatted(text):
    """Строка с % без подстановок не форматируется — иначе aapt примет
    «40% в» за подстановку."""
    return "%" in text and not SPEC.search(text)


def resources(lang):
    table = strings(lang)
    keys = sorted(all_keys())
    plurals = plural_keys()
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             "<!-- Собрано android/tool/make_resources.py — не править руками. -->",
             '<resources xmlns:tools="http://schemas.android.com/tools" '
             'tools:ignore="MissingTranslation,UnusedResources,Typos">']
    for key in keys:
        if lang == "ru":
            value = table.get(key, key)
        else:
            value = table.get(key)
            if value is None:
                continue
        if key in plurals:
            forms = value if isinstance(value, dict) else {"other": value}
            if lang == "ru" and not isinstance(value, dict):
                raise SystemExit(f"ru: «{key}» без форм числа")
            lines.append(f'    <plurals name="{name(key, "p_")}">')
            extra = ANDROID_PLURALS.get(lang.split("-")[0], [])
            for form in ["zero", "one", "two", "few", "many", "other"]:
                text = forms.get(form, forms["other"] if form in extra else None)
                if text is not None:
                    lines.append(f'        <item quantity="{form}">'
                                 f"{xml_text(java(text))}</item>")
            lines.append("    </plurals>")
        else:
            text = java(value)
            extra = ' formatted="false"' if formatted(text) else ""
            lines.append(f'    <string name="{name(key, "t_")}"{extra}>'
                         f"{xml_text(text)}</string>")
    for alias, key in sorted(XML_NAMES.items()):
        value = table.get(key, key if lang == "ru" else None)
        if isinstance(value, str):
            lines.append(f'    <string name="{alias}">{xml_text(java(value))}</string>')
    lines.append("</resources>")
    return "\n".join(lines) + "\n"


def table_kotlin():
    keys = sorted(all_keys())
    plurals = plural_keys()
    texts = [k for k in keys if k not in plurals]
    counted = [k for k in keys if k in plurals]

    def literal(key):
        return json.dumps(key, ensure_ascii=False).replace("$", "\\$")

    out = ["// Собрано android/tool/make_resources.py — не править руками.",
           "package com.ledro6.sprout.platform", "",
           "import com.ledro6.sprout.R", "",
           "/** Русский ключ → ресурс. Куски по двести строк: один метод "
           "JVM не вместил бы всё. */",
           "internal object StringTable {"]
    chunks = [texts[i:i + 200] for i in range(0, len(texts), 200)]
    out.append("    val texts: Map<String, Int> by lazy {")
    out.append("        HashMap<String, Int>(%d).apply {" % (len(texts) * 2))
    for index in range(len(chunks)):
        out.append(f"            part{index}(this)")
    out.append("        }")
    out.append("    }")
    out.append("")
    out.append("    val plurals: Map<String, Int> = mapOf(")
    for key in counted:
        out.append(f"        {literal(key)} to R.plurals.{name(key, 'p_')},")
    out.append("    )")
    for index, chunk in enumerate(chunks):
        out.append("")
        out.append(f"    private fun part{index}(map: HashMap<String, Int>) {{")
        for key in chunk:
            out.append(f"        map[{literal(key)}] = R.string.{name(key, 't_')}")
        out.append("    }")
    out.append("}")
    return "\n".join(out) + "\n"


def locales_config():
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             "<!-- Собрано android/tool/make_resources.py — не править руками. -->",
             '<locale-config xmlns:android="http://schemas.android.com/apk/res/android">']
    for lang in LANGS:
        lines.append(f'    <locale android:name="{lang}" />')
    lines.append("</locale-config>")
    return "\n".join(lines) + "\n"


def outputs():
    files = {}
    for lang in LANGS:
        text = resources(lang)
        for folder in FOLDERS.get(lang, [f"values-{lang}"]):
            files[RES / folder / FILE] = text
    files[TABLE_KT] = table_kotlin()
    files[RES / "xml" / "locales_config.xml"] = locales_config()
    return files


def unescape(literal):
    """Литерал Kotlin → текст: `\\$` и `\\'` — не JSON, их снимаем сами."""
    return json.loads('"' + literal.replace("\\$", "$").replace("\\'", "'") + '"')


def templates():
    """Вызовы Lang с шаблоном Kotlin в ключе."""
    out = []
    for path in sorted(KOTLIN.rglob("*.kt")):
        text = path.read_text(encoding="utf-8")
        for match in TEMPLATE.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            out.append(f"{path.relative_to(ANDROID)}:{line}: шаблон в ключе")
    return out


LITERAL = re.compile(r'"((?:[^"\\$]|\\.|\$(?![{A-Za-z_]))*)"')
JOIN = re.compile(r'\s*\+\s*')
OPEN = re.compile(r'\b(?:Lang\.(?:text|format|key)|Key)\(\s*')


def literal_at(text, at):
    """Литерал с места `at` и склеенные к нему через «+»; пусто — не литерал."""
    parts = []
    while True:
        match = LITERAL.match(text, at)
        if not match:
            return None if not parts else "".join(parts)
        parts.append(unescape(match.group(1)))
        at = match.end()
        glue = JOIN.match(text, at)
        if not glue or not text.startswith('"', glue.end()):
            return "".join(parts)
        at = glue.end()


def used():
    """Ключи из кода Android: откуда каждый."""
    found = {}
    for path in sorted(KOTLIN.rglob("*.kt")):
        if path == TABLE_KT:
            continue
        text = path.read_text(encoding="utf-8")
        for match in OPEN.finditer(text):
            key = literal_at(text, match.end())
            if key is None:
                continue
            line = text.count("\n", 0, match.start()) + 1
            found.setdefault(key, f"{path.relative_to(ANDROID)}:{line}")
    for alias, key in XML_NAMES.items():
        found.setdefault(key, f"XML @string/{alias}")
    return found


def check():
    problems = templates()
    keys = all_keys()
    plurals = plural_keys()
    names = {}
    for key in keys:
        for prefix in ("t_", "p_"):
            label = name(key, prefix)
            if label in names and names[label] != key:
                problems.append(f"одинаковое имя ресурса у «{key}» и «{names[label]}»")
            names[label] = key
    for key, place in sorted(used().items(), key=lambda item: item[1]):
        if key not in keys:
            problems.append(f"{place}: «{key}» — нет в таблицах")
    for lang in LANGS:
        table = strings(lang)
        extra = load(OVERLAY, lang)
        for key in keys:
            value = table.get(key)
            if value is None:
                if lang != "ru":
                    problems.append(f"{lang}: «{key}» — нет перевода")
                continue
            forms = value if isinstance(value, dict) else {"": value}
            if key in plurals and isinstance(value, dict):
                need = PLURALS.get(lang, DEFAULT_PLURALS)
                lacking = [f for f in need if f not in value]
                if lacking:
                    problems.append(f"{lang}: «{key}» — нет форм {lacking}")
            if key in extra:
                for form, text in forms.items():
                    if sorted(SPEC.findall(text)) != sorted(SPEC.findall(key)):
                        problems.append(f"{lang}: «{key}» [{form}] — другие подстановки")
                    if lang not in CYRILLIC and CYR.search(text):
                        problems.append(f"{lang}: «{key}» — осталась кириллица")
    overlay_keys = set(load(OVERLAY, "en")) - {"_note"}
    for lang in LANGS:
        if lang == "ru":
            continue
        mine = set(load(OVERLAY, lang)) - {"_note"}
        if mine != overlay_keys:
            problems.append(f"{lang}: строки Android не совпадают с английскими: "
                            f"{sorted(mine ^ overlay_keys)[:3]}")
    base_en = {k for k in load(TABLES, "en") if not k.startswith("_")}
    for lang in LANGS:
        for key, text in load(OVERRIDES, lang).items():
            if key.startswith("_"):
                continue
            if key not in base_en:
                problems.append(f"{lang}: замена «{key}» — нет такого ключа в таблицах iOS")
            elif sorted(SPEC.findall(text)) != sorted(SPEC.findall(key)):
                problems.append(f"{lang}: замена «{key}» — другие подстановки")
    code = set(used())
    idle = sorted(overlay_keys - code)
    if idle:
        problems.append(f"строки Android, которых нет в коде: {idle[:5]}")
    for path, text in outputs().items():
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            problems.append(f"{path.relative_to(ANDROID)} устарел — запустите build")
    for problem in problems:
        print(problem)
    print(f"ключей в коде: {len(code)}, в таблицах: {len(keys)}, "
          f"языков: {len(LANGS)}, замечаний: {len(problems)}")
    return 1 if problems else 0


def build():
    for path, text in outputs().items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    print(f"ресурсы: {len(LANGS)} языков, строк {len(all_keys())}")
    return 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    sys.exit(build() if command == "build" else check())
