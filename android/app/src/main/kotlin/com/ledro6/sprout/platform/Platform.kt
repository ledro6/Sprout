package com.ledro6.sprout.platform

import android.content.Context
import android.text.format.DateFormat
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Skeleton

/** Связь модели с телефоном: откуда брать переводы и как писать даты. */
object Platform {
    /** Зовётся при запуске и при смене языка или формата времени. */
    fun speak(context: Context) {
        Lang.source = AndroidStrings(context)
        Skeleton.resolve = { skeleton, locale -> DateFormat.getBestDateTimePattern(locale, skeleton) }
        Skeleton.hours24 = DateFormat.is24HourFormat(context)
    }
}
