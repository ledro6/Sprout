#!/usr/bin/env python3
"""
Каталоги строк приложения: собирает и проверяет переводы.

    python3 tool/make_strings.py build    # собрать *.xcstrings из таблиц
    python3 tool/make_strings.py check    # проверить, ничего не пишет
    python3 tool/make_strings.py prune    # убрать из таблиц ушедшие строки

Исходный язык — русский: ключ строки и есть русский текст, его видно в
коде. Переводы лежат таблицами по языкам в tool/strings/<язык>.json: ключ →
перевод, а у строк, где форма зависит от числа, — ключ → {"one": …,
"few": …, "other": …}. Русская таблица держит только такие строки: у
остальных русский текст — сам ключ. Два раздела таблицы — отдельные
каталоги, тоже по русскому тексту: "_shortcuts" — фразы Siri
(AppShortcuts.xcstrings), "_infoplist" — пояснения к разрешениям
(InfoPlist.xcstrings).

Ключи берутся из кода, а не выписываются руками:

- `Lang.text("…")`, `Lang.format("…", …)` и `Lang.key("…")`;
- литералы там, где SwiftUI сам ищет перевод: `Text("…")`, `Button("…")`,
  `.navigationTitle("…")`, плашки приложения с `LocalizedStringKey` — и оба
  плеча `условие ? "…" : "…"` (или `nil`) в тех же местах;
- строки App Intents: названия команд, описания, диалоги;
- фразы Siri из `phrases: [...]`;
- пояснения к разрешениям — INFOPLIST_KEY_NS…UsageDescription проекта.

Многострочный литерал `\"\"\"` читается так же, как его прочтёт Swift: `\\` в
конце строки склеивает её со следующей.

Проверка ловит то, что иначе нашлось бы только на телефоне с другим
языком: ключ без перевода, перевод с другими подстановками (%@, %lld),
неполный набор форм числа, фразу Siri без имени приложения, язык,
оставленный по-английски, и русскую строку, которая идёт на экран мимо
каталога.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / "ios-native"
APP = NATIVE / "Sprout"
WIDGET = NATIVE / "SproutWidget"
WATCH = NATIVE / "SproutWatch"
WATCH_WIDGET = NATIVE / "SproutWatchWidget"
PROJECT = NATIVE / "Sprout.xcodeproj" / "project.pbxproj"
TABLES = ROOT / "tool" / "strings"
CATALOG = APP / "Localizable.xcstrings"
SHORTCUTS = APP / "AppShortcuts.xcstrings"
INFOPLIST = APP / "InfoPlist.xcstrings"
SOURCE = "ru"

# Переводы на паузе: по просьбе автора приложение пока только по-русски.
# Новые строки в таблицы других языков не пишутся, а проверка не считает
# их отсутствие ошибкой — система покажет русский текст. Уже переведённое
# по-прежнему проверяется целиком. Вернуть строгость — True.
TRANSLATIONS_REQUIRED = False

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
LITERAL_AT = re.compile(LITERAL)
# Места, где аргумент — ключ каталога. Сам аргумент разбирает `argument`.
LANG_CALL = re.compile(r'\bLang\.(?:text|format|key)\(\s*')
SWIFTUI_FIRST = re.compile(
    r'(?<![\w.])(?:Text|Button|Label|Toggle|Picker|TextField|SecureField|'
    r'Section|Menu|Tab|ProgressView|DatePicker|Stepper|Link|ShareLink|'
    r'ContentUnavailableView|SproutGroup|SproutBlock|SproutHead|SproutLink|'
    r'SproutFigure|SproutPage|Paragraph|SectionTitle|switchRow|tool|pair)'
    r'\(\s*')
SWIFTUI_MOD = re.compile(
    r'\.(?:navigationTitle|alert|confirmationDialog|accessibilityLabel|'
    r'accessibilityHint|accessibilityValue|help|badge|'
    r'configurationDisplayName|description)\(\s*')
NAMED = re.compile(
    r'\b(?:note|body|title|prompt|done|message|requestValueDialog|'
    r'shortTitle|dialog|caption|line)\s*:\s*')
INTENT = re.compile(
    r'(?:LocalizedStringResource\s*=|TypeDisplayRepresentation\s*=|'
    r'IntentDescription\(|IntentDialog\()\s*')
# Оба плеча условия — литералы или nil: `cond ? nil : "…"`.
BRANCH = r'(?:' + LITERAL + r'|nil)'
TERNARY_AT = re.compile(r'[^"\n?;{}]*?\?\s*' + BRANCH + r'\s*:\s*' + BRANCH)
PHRASES = re.compile(r'\bphrases:\s*\[(.*?)\]', re.S)
MULTI = re.compile(r'"""[ \t]*\n(.*?)\n([ \t]*)"""', re.S)
USAGE = re.compile(r'INFOPLIST_KEY_(NS\w+UsageDescription)\s*=\s*' + LITERAL
                   + r';')
CYR = re.compile(r'[А-Яа-яЁё]')
SPEC = re.compile(r'%(?:\d+\$)?(?:\.\d+)?(?:ll|l|h|q)?[@dDiuUxXoOfeEgGcCsSaA]')
PARAM = re.compile(r'\$\{(\w+)\}')


def unescape(text):
    return (text.replace('\\"', '"').replace("\\n", "\n")
            .replace("\\\\", "\\"))


def flatten(text):
    """Многострочные литералы — однострочными на месте открывающих кавычек.
    Переводы строк после них сохраняют номера строк файла."""
    def one(match):
        body, indent = match.group(1), match.group(2)
        lines = body.split("\n")
        value = ""
        for index, line in enumerate(lines):
            line = line[len(indent):] if line.startswith(indent) \
                else line.strip()
            if line.endswith("\\") and not line.endswith("\\\\"):
                value += line[:-1]
            else:
                value += line + ("\\n" if index < len(lines) - 1 else "")
        value = re.sub(r'(?<!\\)"', r'\\"', value)
        return '"' + value + '"' + "\n" * (len(lines) + 1)
    return MULTI.sub(one, text)


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


def sources():
    for folder in (APP, WIDGET, WATCH, WATCH_WIDGET):
        for path in sorted(folder.rglob("*.swift")):
            yield path, path.read_text(encoding="utf-8")


def argument(code, at, ternary):
    """Литералы-ключи, с которых начинается аргумент: сам литерал или оба
    плеча условия. Каждый — (начало, текст)."""
    match = LITERAL_AT.match(code, at)
    if match:
        return [(match.start(1), match.group(1))]
    if not ternary:
        return []
    match = TERNARY_AT.match(code, at)
    if not match:
        return []
    return [(match.start(group), match.group(group)) for group in (1, 2)
            if match.group(group) is not None]


def phrase(literal):
    """Фраза Siri так, как её ищет система: параметры — ${…}."""
    key = re.sub(r'\\\(\s*\\\.\$(\w+)\s*\)', r'${\1}', literal)
    key = re.sub(r'\\\(\s*\.applicationName\s*\)', '${applicationName}', key)
    return unescape(key)


def extract():
    """Ключи из кода: откуда каждый, фразы Siri и строки мимо каталога."""
    keys, phrases, stray = {}, {}, []
    for path, text in sources():
        rel = path.relative_to(NATIVE)
        code = "\n".join(code_only(line)
                         for line in flatten(text).split("\n"))
        starts = [0]
        for line in code.split("\n"):
            starts.append(starts[-1] + len(line) + 1)

        def number(offset):
            low, high = 0, len(starts) - 1
            while low < high:
                middle = (low + high + 1) // 2
                if starts[middle] <= offset:
                    low = middle
                else:
                    high = middle - 1
            return low + 1

        found = set()
        for pattern in (LANG_CALL, SWIFTUI_FIRST, SWIFTUI_MOD, NAMED,
                        INTENT):
            for match in pattern.finditer(code):
                for start, literal in argument(code, match.end(),
                                               pattern is not LANG_CALL):
                    found.add(start)
                    if "\\(" in literal:
                        # Подстановка в литерале SwiftUI дала бы ключ с %@,
                        # который легко не угадать, — такие идут через Lang.
                        # Одна подстановка без слов — не текст, а число.
                        if CYR.search(literal):
                            stray.append((rel, number(start), literal,
                                          "подстановка в литерале"))
                        continue
                    key = unescape(literal)
                    # Вызов Lang — ключ всегда, даже без слов: «%lld%%»
                    # по-турецки пишется «%%%lld».
                    if key.strip() and (pattern is LANG_CALL
                                        or CYR.search(key)):
                        keys.setdefault(key, f"{rel}:{number(start)}")
        for block in PHRASES.finditer(code):
            for match in LITERAL_AT.finditer(code, block.start(1),
                                             block.end(1)):
                found.add(match.start(1))
                phrases.setdefault(phrase(match.group(1)),
                                   f"{rel}:{number(match.start(1))}")
        for match in LITERAL_AT.finditer(code):
            if match.start(1) in found or not CYR.search(match.group(1)):
                continue
            stray.append((rel, number(match.start(1)), match.group(1),
                          "мимо каталога"))
    return keys, phrases, stray


def usages():
    """Пояснения к разрешениям из настроек проекта: ключ Info.plist → текст."""
    found = {}
    for key, value in USAGE.findall(PROJECT.read_text(encoding="utf-8")):
        found.setdefault(key, set()).add(unescape(value))
    return found


# Файл → литералы, которые остаются русскими нарочно: основы для узнавания
# видов и падежей, имена откликов для проверки.
ALLOW = {
    "Sprout/Model/Botany/Preset.swift": [r"."],
    "Sprout/Model/Botany/Toxicity.swift": [r"^[а-яё ]+$"],
    "Sprout/Model/Botany/Grower+Flowers.swift": [r"^[а-яё]+$"],
    "Sprout/Model/Botany/Grower+Foliage.swift": [r"^[а-яё]+$"],
    "Sprout/Model/Botany/Grower+Succulents.swift": [r"^[а-яё]+$"],
    "Sprout/Model/Garden/Plants.swift": [r"^[а-яё]+$", r"аяоеиыуюйь"],
    "Sprout/Model/Core/Pulse.swift": [r"^[а-яё]+$"],
    "Sprout/Model/Garden/Climate.swift": [r"^[а-яё]+$"],
}


def allowed(entry):
    rel, _, literal, _ = entry
    rules = ALLOW.get(str(rel), [])
    return any(re.search(rule, literal) for rule in rules)


def table(lang):
    path = TABLES / f"{lang}.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def load(lang):
    return {k: v for k, v in table(lang).items() if not k.startswith("_")}


def section(lang, name):
    return table(lang).get(name, {})


def neutral():
    return set(table(SOURCE).get("_neutral", []))


def specs(text):
    return sorted(SPEC.findall(text))


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(value):
    if isinstance(value, dict):
        return {"variations": {"plural": {
            form: unit(text) for form, text in value.items()}}}
    return unit(value)


def catalog(strings):
    return json.dumps({"sourceLanguage": SOURCE, "strings": strings,
                       "version": "1.0"},
                      ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def assemble():
    """Все три каталога — текстом, как их запишет `build`."""
    keys, phrases, _ = extract()
    tables = {lang: load(lang) for lang in LANGS}
    strings = {}
    for key in sorted(keys):
        local = {lang: entry(tables[lang][key]) for lang in LANGS
                 if key in tables[lang]}
        item = {"extractionState": "manual"}
        if local:
            item["localizations"] = local
        strings[key] = item

    spoken = {lang: section(lang, "_shortcuts") for lang in LANGS}
    said = {}
    for key in sorted(phrases):
        local = {lang: unit(spoken[lang][key]) for lang in LANGS
                 if lang != SOURCE and key in spoken[lang]}
        item = {"extractionState": "manual"}
        if local:
            item["localizations"] = local
        said[key] = item

    asked = {lang: section(lang, "_infoplist") for lang in LANGS}
    plist = {}
    for key, texts in sorted(usages().items()):
        text = sorted(texts)[0]
        local = {lang: unit(asked[lang][text]) for lang in LANGS
                 if lang != SOURCE and text in asked[lang]}
        local[SOURCE] = unit(text)
        plist[key] = {"extractionState": "manual", "localizations": local}
    return {CATALOG: catalog(strings), SHORTCUTS: catalog(said),
            INFOPLIST: catalog(plist)}


def build():
    for path, text in assemble().items():
        path.write_text(text, encoding="utf-8")
        count = len(json.loads(text)["strings"])
        print(f"{path.relative_to(ROOT)}: строк {count}, языков {len(LANGS)}")
    return 0


def check_values(lang, name, keys, values, problems, counted=()):
    """Один раздел таблицы языка против ключей из кода. `counted` — ключи
    с формами числа по-русски: там, где у языка форм больше одной, они
    нужны и в переводе."""
    for key in keys:
        value = values.get(key)
        if value is None:
            continue
        if (key in counted and not isinstance(value, dict)
                and len(PLURALS.get(lang, DEFAULT_PLURALS)) > 1):
            problems.append(f"{lang}: «{key}» — нужны формы числа")
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
            if not isinstance(text, str) or not text.strip():
                problems.append(f"{lang}: «{key}» [{form}] — пустой перевод")
                continue
            if specs(text) != specs(key):
                problems.append(f"{lang}: «{key}» [{form}] — подстановки "
                                f"{specs(text)} вместо {specs(key)}")
            if "%" in text and "%" not in key:
                # Строка без подстановок не форматируется: «%%» так и
                # останется двумя знаками.
                problems.append(f"{lang}: «{key}» — знак % в строке без "
                                f"подстановок")
            if lang not in CYRILLIC and CYR.search(text):
                problems.append(f"{lang}: «{key}» — осталась кириллица")
    extra = sorted(set(values) - set(keys))
    if extra:
        problems.append(f"{lang}{name}: лишние ключи, которых нет в коде: "
                        f"{extra[:5]}{'…' if len(extra) > 5 else ''}")
    lost = [key for key in keys if key not in values]
    if lost and lang != SOURCE:
        if TRANSLATIONS_REQUIRED:
            problems.append(f"{lang}{name}: без перевода {len(lost)} из "
                            f"{len(keys)}, например «{lost[0]}»")
        else:
            UNTRANSLATED.update(lost)


def check_phrases(lang, phrases, spoken, problems):
    """Фраза Siri: имя приложения ровно раз, те же параметры, без повторов."""
    seen = {}
    for key in phrases:
        text = spoken.get(key)
        if text is None:
            continue
        if text.count("${applicationName}") != 1:
            problems.append(f"{lang}: фраза «{key}» — имя приложения "
                            f"должно встречаться ровно раз")
        if sorted(PARAM.findall(text)) != sorted(PARAM.findall(key)):
            problems.append(f"{lang}: фраза «{key}» — параметры "
                            f"{PARAM.findall(text)} вместо "
                            f"{PARAM.findall(key)}")
        folded = text.casefold()
        if folded in seen:
            problems.append(f"{lang}: фразы «{seen[folded]}» и «{key}» "
                            f"переведены одинаково")
        seen[folded] = key


# Строки без перевода хоть на один язык — для сводки, пока переводы на паузе.
UNTRANSLATED = set()

WORD = re.compile(r"[^\W\d_]{4,}")


def check_english(tables, keys, problems):
    """Язык, в котором слишком много строк совпало с английскими, — скорее
    всего, не переведён, а скопирован."""
    english = tables["en"]
    for lang in LANGS:
        if lang in ("en", SOURCE):
            continue
        same = [key for key in keys
                if key in tables[lang] and key in english
                and tables[lang][key] == english[key]
                and WORD.search(json.dumps(english[key], ensure_ascii=False))]
        if len(same) > len(keys) // 10:
            problems.append(f"{lang}: {len(same)} строк совпадают с "
                            f"английскими, например «{same[0]}»")


def check():
    keys, phrases, stray = extract()
    problems = []
    for item in stray:
        if not allowed(item):
            rel, number, literal, why = item
            problems.append(f"{rel}:{number}: «{literal}» — {why}")
    counted = neutral()
    source = load(SOURCE)
    for key in keys:
        numbers = [s for s in specs(key) if s[-1] in "dDiuU"]
        if numbers and key not in source and key not in counted:
            problems.append(f"«{key}»: нет русских форм числа "
                            f"(или добавь в _neutral)")
    stale = sorted(counted - set(keys))
    if stale:
        problems.append(f"_neutral: ключей нет в коде: {stale}")
    for key in phrases:
        if key.count("${applicationName}") != 1:
            problems.append(f"фраза «{key}» — нет имени приложения")

    plist = usages()
    texts = set()
    for key, values in plist.items():
        if len(values) != 1:
            problems.append(f"{key}: в Debug и Release разный текст")
        texts |= values

    tables = {lang: load(lang) for lang in LANGS}
    plural = {key for key, value in source.items() if isinstance(value, dict)}
    for lang in LANGS:
        check_values(lang, "", keys, tables[lang], problems, plural)
        if lang == SOURCE:
            continue
        spoken = section(lang, "_shortcuts")
        check_values(lang, " (фразы Siri)", phrases, spoken, problems)
        check_phrases(lang, phrases, spoken, problems)
        check_values(lang, " (разрешения)", texts, section(lang, "_infoplist"),
                     problems)
    check_english(tables, keys, problems)

    for path, text in assemble().items():
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            problems.append(f"{path.name} устарел: "
                            f"python3 tool/make_strings.py build")
    if problems:
        print(f"строки: найдено проблем — {len(problems)}")
        for problem in problems[:60]:
            print("  •", problem)
        if len(problems) > 60:
            print(f"  … и ещё {len(problems) - 60}")
        return 1
    print(f"строки сходятся: {len(keys)} ключей, фраз Siri {len(phrases)}, "
          f"разрешений {len(texts)}, языков {len(LANGS)}")
    if UNTRANSLATED:
        print(f"переводы на паузе: {len(UNTRANSLATED)} строк пока только "
              f"по-русски")
    return 0


def prune():
    """Переводы строк, которых в коде больше нет, — вон из таблиц: текст
    поменяли, и старый перевод уже ни к чему. Разделы фраз Siri и
    разрешений не трогаются."""
    keys, _, _ = extract()
    gone = 0
    for lang in LANGS:
        path = TABLES / f"{lang}.json"
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        stale = [key for key in data
                 if not key.startswith("_") and key not in keys]
        for key in stale:
            del data[key]
        # Русские строки без форм числа — тот же список, чистится так же.
        neutral = data.get("_neutral")
        if isinstance(neutral, list):
            kept = [key for key in neutral if key in keys]
            stale += neutral[len(kept):] if len(kept) != len(neutral) else []
            data["_neutral"] = kept
        if stale:
            gone += len(stale)
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2)
                            + "\n", encoding="utf-8")
    print(f"убрано переводов ушедших строк: {gone}")
    return 0


def main():
    commands = {"build": build, "check": check, "prune": prune}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    return commands[sys.argv[1]]()


if __name__ == "__main__":
    sys.exit(main())
