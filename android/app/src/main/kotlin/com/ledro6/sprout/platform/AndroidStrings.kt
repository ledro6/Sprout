package com.ledro6.sprout.platform

import android.content.Context
import android.content.res.Resources
import com.ledro6.sprout.model.Lang
import java.util.Locale

/**
 * Переводы из ресурсов Android: язык выбирает система — язык телефона или
 * свой язык приложения из настроек Android 13+. Нет строки — пусто, и `Lang`
 * покажет русский ключ, а не упадёт.
 */
class AndroidStrings(private val resources: Resources) : Lang.Source {
    constructor(context: Context) : this(context.resources)

    override val locale: Locale
        get() = resources.configuration.locales.get(0) ?: Locale.getDefault()

    override fun text(key: String): String? {
        val id = StringTable.texts[key] ?: return null
        return runCatching { resources.getString(id) }.getOrNull()
    }

    override fun plural(key: String, count: Long): String? {
        val id = StringTable.plurals[key] ?: return null
        val quantity = count.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
        return runCatching { resources.getQuantityString(id, quantity) }.getOrNull()
    }
}
