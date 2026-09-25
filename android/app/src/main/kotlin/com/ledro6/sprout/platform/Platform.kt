package com.ledro6.sprout.platform

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import android.text.format.DateFormat
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Skeleton
import java.util.Locale

/** Связь модели с телефоном: откуда брать переводы и как писать даты. */
object Platform {
    private const val LANGUAGE = "language"

    /** Зовётся при запуске и при смене языка или формата времени. */
    fun speak(context: Context) {
        Lang.source = AndroidStrings(localized(context))
        Skeleton.resolve = { skeleton, locale -> DateFormat.getBestDateTimePattern(locale, skeleton) }
        Skeleton.hours24 = DateFormat.is24HourFormat(context)
    }

    /**
     * Свой язык приложения. С Android 13 его помнит и применяет система; раньше
     * — AppCompat, но только к экранам. Виджету и шторке язык даём сами.
     */
    fun localized(context: Context): Context {
        if (Build.VERSION.SDK_INT >= 33) return context
        val tag = chosen(context) ?: return context
        val config = Configuration(context.resources.configuration)
        config.setLocales(LocaleList.forLanguageTags(tag))
        return context.createConfigurationContext(config)
    }

    /** Выбранный язык; пусто — как в телефоне. */
    fun chosen(context: Context): String? {
        if (Build.VERSION.SDK_INT >= 33) {
            return AppCompatDelegate.getApplicationLocales().toLanguageTags().ifEmpty { null }
        }
        return context.getSharedPreferences("sprout", Context.MODE_PRIVATE).getString(LANGUAGE, null)?.ifEmpty { null }
    }

    fun choose(context: Context, tag: String?) {
        context.getSharedPreferences("sprout", Context.MODE_PRIVATE).edit().putString(LANGUAGE, tag.orEmpty()).apply()
        AppCompatDelegate.setApplicationLocales(
            if (tag == null) LocaleListCompat.getEmptyLocaleList() else LocaleListCompat.forLanguageTags(tag),
        )
    }

    /** Название языка на нём самом: «Deutsch», «日本語». */
    fun languageName(tag: String): String {
        val locale = Locale.forLanguageTag(tag)
        return locale.getDisplayName(locale).replaceFirstChar { it.titlecase(locale) }
    }
}
