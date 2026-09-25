package com.ledro6.sprout.model

import java.text.NumberFormat
import java.util.Locale

/**
 * Слова приложения — на языке телефона. Ключ — русский текст, как на iOS:
 * в коде видно, что окажется на экране. Переводы и формы числа живут в
 * ресурсах Android (их собирает android/tool/make_resources.py из таблиц
 * iOS), а здесь — только подстановка.
 *
 * Подстановка своя, а не `String.format`: кривой перевод с лишним `%` уронил
 * бы `String.format` исключением, а здесь просто останется как есть.
 */
object Lang {
    /** Где искать перевод. Без телефона — нигде: ключ и есть русский текст. */
    interface Source {
        val locale: Locale

        fun text(key: String): String?

        /** Строка с формами числа — форма уже выбрана по `count`. */
        fun plural(key: String, count: Long): String?
    }

    object Russian : Source {
        override val locale: Locale = Locale.forLanguageTag("ru")
        override fun text(key: String): String? = null
        override fun plural(key: String, count: Long): String? = null
    }

    @Volatile
    var source: Source = Russian

    val locale: Locale get() = source.locale

    fun text(key: String): String = say(key, emptyList())

    /** Ключ, который переводится позже — там, где его показывают. */
    fun key(key: String): String = key

    fun format(key: String, vararg values: Any): String = say(key, values.toList())

    private fun say(key: String, values: List<Any>): String {
        // Формы числа бывают только у строк с одной подстановкой — целой.
        val count = values.singleOrNull()?.let { whole(it) }
        val pattern = count?.let { source.plural(key, it) }
            ?: source.text(key)
            ?: key
        if (values.isEmpty()) return pattern
        return fill(pattern, values)
    }

    private fun whole(value: Any): Long? = when (value) {
        is Int -> value.toLong()
        is Long -> value
        is Short -> value.toLong()
        else -> null
    }

    /** Целое — с разрядами, как принято в языке. */
    fun number(value: Int): String = NumberFormat.getIntegerInstance(locale).format(value)

    /** Дробное — одним знаком и с запятой или точкой, как принято в языке. */
    fun decimal(number: Double): String {
        val style = NumberFormat.getNumberInstance(locale)
        style.minimumFractionDigits = 0
        style.maximumFractionDigits = 1
        return style.format(number)
    }

    /**
     * Подстановка по порядку и по номерам: `%@`, `%s`, `%lld`, `%d`, `%.1f`,
     * `%2$@`, `%%`. Понимает и форму iOS (ключи), и форму Java (ресурсы).
     */
    fun fill(pattern: String, values: List<Any>): String {
        val out = StringBuilder()
        var next = 0
        var index = 0
        val chars = pattern
        while (index < chars.length) {
            val char = chars[index]
            if (char != '%' || index + 1 >= chars.length) {
                out.append(char)
                index += 1
                continue
            }
            var cursor = index + 1
            if (chars[cursor] == '%') {
                out.append('%')
                index = cursor + 1
                continue
            }
            var position: Int? = null
            var probe = cursor
            while (probe < chars.length && chars[probe].isDigit()) probe += 1
            if (probe < chars.length && chars[probe] == '$' && probe > cursor) {
                position = chars.substring(cursor, probe).toIntOrNull()?.minus(1)
                cursor = probe + 1
            }
            var precision: Int? = null
            if (cursor < chars.length && chars[cursor] == '.') {
                cursor += 1
                val from = cursor
                while (cursor < chars.length && chars[cursor].isDigit()) cursor += 1
                precision = chars.substring(from, cursor).toIntOrNull()
            }
            while (cursor < chars.length && chars[cursor] in "lhqjzt") cursor += 1
            if (cursor >= chars.length) {
                out.append(chars, index, chars.length)
                break
            }
            val kind = chars[cursor]
            val at = position ?: next
            if (position == null) next += 1
            val value = values.getOrNull(at)
            val said: String? = when (kind) {
                '@', 's' -> value?.let { spoken(it) }
                'd', 'i', 'u' -> value?.let { whole(it)?.toString() ?: spoken(it) }
                'f' -> when (value) {
                    is Double -> fixed(value, precision ?: 6)
                    is Float -> fixed(value.toDouble(), precision ?: 6)
                    null -> null
                    else -> whole(value)?.toString()
                }
                else -> null
            }
            if (said != null) out.append(said) else out.append(chars, index, cursor + 1)
            index = cursor + 1
        }
        return out.toString()
    }

    private fun spoken(value: Any): String = when (value) {
        is Double -> decimal(value)
        is Float -> decimal(value.toDouble())
        else -> value.toString()
    }

    private fun fixed(number: Double, places: Int): String {
        val style = NumberFormat.getNumberInstance(locale)
        style.isGroupingUsed = false
        style.minimumFractionDigits = places
        style.maximumFractionDigits = places
        return style.format(number)
    }
}
