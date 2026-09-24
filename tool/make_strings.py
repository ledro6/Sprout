#!/usr/bin/env python3
"""
Каталог строк приложения: собирает и проверяет переводы.

    python3 tool/make_strings.py build    # собрать *.xcstrings из таблиц
    python3 tool/make_strings.py check    # проверить, ничего не пишет

Исходный язык — русский: ключ строки и есть русский текст, его видно в
коде. Переводы лежат таблицами по языкам в tool/strings/<язык>.json: ключ →
перевод, а у строк, где форма зависит от числа, — ключ → {"one": …,
"few": …, "other": …}. Русская таблица держит только такие строки: у
остальных русский текст — сам ключ.

Ключи берутся из кода, а не выписываются руками:

- `Lang.text("…")` и `Lang.format("…", …)` — строки модели и экранов;
- строки-литералы в местах, где SwiftUI сам ищет перевод: `Text("…")`,
  `Button("…")`, `Label("…", …)`, `.navigationTitle("…")` и свои плашки
  приложения, которые принимают `LocalizedStringKey`;
- строки App Intents: названия команд, описания, диалоги.

Проверка ловит то, что иначе нашлось бы только на телефоне с другим
языком: ключ без перевода, перевод с другими подстановками (%@, %lld),
неполный набор форм числа для языка и русскую строку, которая идёт на экран
мимо каталога.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "ios-native" / "Sprout"
TABLES = ROOT / "tool" / "strings"
CATALOG = APP / "Localizable.xcstrings"
SOURCE = "ru"

# Языки интерфейса iPhone. Региональные варианты английского, испанского,
# французского и китайского (Гонконг) система берёт из основного языка сама;
# португальский — нет, поэтому оба.
LANGS = [
    "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr",
    "gu", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "kn", "ko", "lt",
    "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro",
    "ru", "sk", "sl", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi",
    "zh-Hans", "zh-Hant",
]

# Формы числа для целых — по CLDR. Лишние формы система не спросит,
# недостающие — возьмёт «other», и выйдет «1 дней».
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

# Кириллица своя у этих языков — русский текст в их переводе не ошибка.
CYRILLIC = {"ru", "uk", "bg", "kk"}

LITERAL = r'"((?:[^"\\\n]|\\.)*)"'
LANG_CALL = re.compile(r'\bLang\.(?:text|format)\(\s*' + LITERAL)
# Первые аргументы, которые SwiftUI и плашки приложения переводят сами.
SWIFTUI_FIRST = re.compile(
    r'(?<![\w.])(?:Text|Button|Label|Toggle|Picker|TextField|SecureField|'
    r'Section|Menu|Tab|ProgressView|DatePicker|Stepper|Link|'
    r'SproutGroup|SproutBlock|SproutHead|SproutLink|Paragraph|SproutPage|'
    r'switchRow|tool|hint|chore)\(\s*' + LITERAL)
SWIFTUI_MOD = re.compile(
    r'\.(?:navigationTitle|alert|confirmationDialog|accessibilityLabel|'
    r'accessibilityHint|accessibilityValue|help|badge)\(\s*' + LITERAL)
NAMED = re.compile(
    r'\b(?:note|body|title|prompt|done|message|requestValueDialog|'
    r'shortTitle|dialog)\s*:\s*' + LITERAL)
INTENT = re.compile(
    r'(?:LocalizedStringResource\s*=|TypeDisplayRepresentation\s*=|'
    r'IntentDescription\(|IntentDialog\()\s*' + LITERAL)
CYR = re.compile(r'[А-Яа-яЁё]')
SPEC = re.compile(r'%(?:\d+\$)?(?:\.\d+)?(?:ll|l|h|q)?[@dDiuUxXoOfeEgGcCsSaA]')


def unescape(text):
    return (text.replace('\\"', '"').replace("\\n", "\n")
            .replace("\\\\", "\\"))


WIDGET = ROOT / "ios-native" / "SproutWidget"


def sources():
    for folder in (APP, WIDGET):
        for path in sorted(folder.rglob("*.swift")):
            yield path, path.read_text(encoding="utf-8")


def code_only(line):
    """Строка кода без хвостового комментария — кавычки внутри строк учтены."""
    inside = False
    escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
        elif char == '"':
            inside = not inside
        elif not inside and line.startswith("//", index):
            return line[:index]
    return line


def extract():
    """Ключи из кода: откуда и каким путём каждый."""
    keys = {}
    stray = []
    for path, text in sources():
        rel = path.relative_to(APP.parent)
        for number, raw in enumerate(text.splitlines(), 1):
            line = code_only(raw)
            if not line.strip():
                continue
            found = set()
            for pattern in (LANG_CALL, SWIFTUI_FIRST, SWIFTUI_MOD, NAMED,
                            INTENT):
                for match in pattern.finditer(line):
                    literal = match.group(1)
                    if "\\(" in literal:
                        # Подстановка в литерале SwiftUI дала бы ключ с %@,
                        # который легко не угадать, — такие идут через Lang.
                        if pattern is not LANG_CALL:
                            stray.append((rel, number, literal,
                                          "подстановка в литерале SwiftUI"))
                        continue
                    key = unescape(literal)
                    if not key.strip() or not CYR.search(key):
                        continue
                    keys.setdefault(key, f"{rel}:{number}")
                    found.add(match.start(1))
            for match in re.finditer(LITERAL, line):
                if match.start(1) in found or not CYR.search(match.group(1)):
                    continue
                stray.append((rel, number, match.group(1), "мимо каталога"))
    return keys, stray


def allowed(entry):
    """Русские строки, которым на экран не нужно: основы для узнавания
    видов, подсказки языковой модели, данные для Siri."""
    rel, _, literal, _ = entry
    rules = ALLOW.get(str(rel), [])
    return any(re.search(rule, literal) for rule in rules)


# Файл → литералы, которые остаются русскими нарочно.
ALLOW = {
    "Sprout/Model/Botany.swift": [r"."],
    "Sprout/Model/Species.swift": [r"."],
    "Sprout/Model/Plants.swift": [r"^[а-яё]+$", r"аяоеиыуюйь"],
    "Sprout/Model/Muse.swift": [r"."],
}


def load(lang):
    path = TABLES / f"{lang}.json"
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def neutral():
    path = TABLES / f"{SOURCE}.json"
    if not path.exists():
        return set()
    return set(json.loads(path.read_text(encoding="utf-8"))
               .get("_neutral", []))


def specs(text):
    return sorted(SPEC.findall(text))


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(key, lang, value):
    if isinstance(value, dict):
        return {"variations": {"plural": {
            form: unit(text) for form, text in value.items()}}}
    return unit(value)


def build():
    keys, _ = extract()
    tables = {lang: load(lang) for lang in LANGS}
    strings = {}
    for key in sorted(keys):
        localizations = {}
        for lang in LANGS:
            value = tables[lang].get(key)
            if value is None:
                continue
            localizations[lang] = entry(key, lang, value)
        item = {"extractionState": "manual"}
        if localizations:
            item["localizations"] = localizations
        strings[key] = item
    catalog = {"sourceLanguage": SOURCE, "strings": strings, "version": "1.0"}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2,
                                  sort_keys=True) + "\n", encoding="utf-8")
    print(f"{CATALOG.relative_to(ROOT)}: строк {len(strings)}, "
          f"языков {len(LANGS)}")
    return 0


def check(strict=True):
    keys, stray = extract()
    problems = []
    for rel, number, literal, why in stray:
        if not allowed((rel, number, literal, why)):
            problems.append(f"{rel}:{number}: «{literal}» — {why}")
    counted = neutral()
    source = load(SOURCE)
    for key in keys:
        numbers = [s for s in specs(key) if s[-1] in "dDiuU"]
        if numbers and key not in source and key not in counted:
            problems.append(f"«{key}»: нет русских форм числа "
                            f"(или добавь в _neutral)")
    missing = {}
    for lang in LANGS:
        table = load(lang)
        for key in keys:
            value = table.get(key)
            if value is None:
                if lang != SOURCE:
                    missing.setdefault(lang, []).append(key)
                continue
            forms = value if isinstance(value, dict) else {"": value}
            if isinstance(value, dict):
                need = PLURALS.get(lang, DEFAULT_PLURALS)
                lacking = [f for f in need if f not in value]
                if lacking:
                    problems.append(f"{lang}: «{key}» — нет форм {lacking}")
                if len(specs(key)) != 1:
                    problems.append(f"{lang}: «{key}» — формы числа только у "
                                    f"строк с одной подстановкой")
            for form, text in forms.items():
                if specs(text) != specs(key):
                    problems.append(f"{lang}: «{key}» [{form}] — подстановки "
                                    f"{specs(text)} вместо {specs(key)}")
                if lang not in CYRILLIC and CYR.search(text):
                    problems.append(f"{lang}: «{key}» — осталась кириллица")
        extra = set(table) - set(keys)
        if extra and strict:
            problems.append(f"{lang}: лишние ключи, которых нет в коде: "
                            f"{sorted(extra)[:5]}…" if len(extra) > 5 else
                            f"{lang}: лишние ключи, которых нет в коде: "
                            f"{sorted(extra)}")
    for lang, lost in sorted(missing.items()):
        problems.append(f"{lang}: без перевода {len(lost)} из {len(keys)}, "
                        f"например «{lost[0]}»")
    built = json.loads(CATALOG.read_text(encoding="utf-8")) \
        if CATALOG.exists() else {"strings": {}}
    if set(built["strings"]) != set(keys):
        problems.append("каталог устарел: python3 tool/make_strings.py build")
    if problems:
        print(f"строки: найдено проблем — {len(problems)}")
        for problem in problems[:60]:
            print("  •", problem)
        if len(problems) > 60:
            print(f"  … и ещё {len(problems) - 60}")
        return 1
    print(f"строки сходятся: {len(keys)} ключей, {len(LANGS)} языков")
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("build", "check"):
        sys.exit(__doc__)
    return build() if sys.argv[1] == "build" else check()


if __name__ == "__main__":
    sys.exit(main())
