import Foundation

/// Слова приложения — на языке телефона. Ключ — русский текст: русский —
/// исходный язык каталога строк (`Localizable.xcstrings`), и в коде видно,
/// что окажется на экране. Числа и множественное число каждого языка живут
/// в каталоге, а не в коде: «1 день», «2 дня», «5 дней» — три формы одного
/// ключа. `Lang`, а не `Words`: у целых чисел в Swift уже есть свои `Words`.
enum Lang {
    /// Что подставляется в строку.
    enum Value: Equatable, Sendable {
        case text(String)
        case whole(Int)
        case fraction(Double)
    }

    /// Прогон модели без телефона читает каталог сам, см.
    /// tool/swift-model-check. На телефоне пусто: строки ищет система.
    nonisolated(unsafe) static var resolve: ((String, [Value]) -> String)?

    /// Язык чисел для прогона без телефона; на телефоне — язык телефона.
    nonisolated(unsafe) static var locale = Locale.current

    static func text(_ key: String) -> String { format(key) }

    static func format(_ key: String, _ values: any Spoken...) -> String {
        say(key, values.map(\.said))
    }

    static func say(_ key: String, _ values: [Value]) -> String {
        if let resolve { return resolve(key, values) }
        #if canImport(Darwin)
        let pattern = NSLocalizedString(key, bundle: .main, comment: "")
        guard !values.isEmpty else { return pattern }
        let arguments: [CVarArg] = values.map { value in
            switch value {
            case .text(let text): text
            case .whole(let number): number
            case .fraction(let number): number
            }
        }
        // Формат из каталога несёт правила числа своего языка — система
        // сама выберет «день», «дня» или «дней».
        return String(format: pattern, locale: locale, arguments: arguments)
        #else
        return fill(key, values)
        #endif
    }

    /// Дробное число — одним знаком и с запятой или точкой, как принято в
    /// языке.
    static func decimal(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0 ... 1))
            .locale(locale))
    }

    /// Подстановка по порядку: `%@`, `%lld`, `%d`, `%f` с точностью, номера
    /// `%2$@` и `%%`. Без правил числа — их выбирают до подстановки.
    static func fill(_ pattern: String, _ values: [Value]) -> String {
        var out = ""
        var next = 0
        let chars = Array(pattern)
        var index = 0
        func take(_ position: Int?) -> Value? {
            let at = position ?? next
            if position == nil { next += 1 }
            return values.indices.contains(at) ? values[at] : nil
        }
        while index < chars.count {
            let char = chars[index]
            guard char == "%", index + 1 < chars.count else {
                out.append(char)
                index += 1
                continue
            }
            var cursor = index + 1
            if chars[cursor] == "%" {
                out.append("%")
                index = cursor + 1
                continue
            }
            // Номер подстановки: «%2$@».
            var position: Int?
            var digits = ""
            var probe = cursor
            while probe < chars.count, chars[probe].isNumber {
                digits.append(chars[probe])
                probe += 1
            }
            if probe < chars.count, chars[probe] == "$", let number = Int(digits) {
                position = number - 1
                cursor = probe + 1
            }
            // Точность: «%.1f».
            var precision: Int?
            if cursor < chars.count, chars[cursor] == "." {
                var places = ""
                cursor += 1
                while cursor < chars.count, chars[cursor].isNumber {
                    places.append(chars[cursor])
                    cursor += 1
                }
                precision = Int(places)
            }
            while cursor < chars.count, "lhqjzt".contains(chars[cursor]) {
                cursor += 1
            }
            guard cursor < chars.count else {
                out.append(contentsOf: String(chars[index...]))
                break
            }
            let kind = chars[cursor]
            let value = take(position)
            switch (kind, value) {
            case ("@", .text(let text)?): out += text
            case ("@", .whole(let number)?): out += "\(number)"
            case ("@", .fraction(let number)?): out += decimal(number)
            case ("d", .whole(let number)?), ("i", .whole(let number)?),
                 ("u", .whole(let number)?):
                out += "\(number)"
            case ("f", .fraction(let number)?):
                out += number.formatted(.number
                    .precision(.fractionLength(precision ?? 6))
                    .grouping(.never).locale(locale))
            case ("f", .whole(let number)?):
                out += "\(number)"
            default:
                out.append(contentsOf: String(chars[index ... cursor]))
            }
            index = cursor + 1
        }
        return out
    }
}

/// Что можно подставить в строку каталога.
protocol Spoken {
    var said: Lang.Value { get }
}

extension String: Spoken {
    var said: Lang.Value { .text(self) }
}

extension Int: Spoken {
    var said: Lang.Value { .whole(self) }
}

extension Double: Spoken {
    var said: Lang.Value { .fraction(self) }
}
