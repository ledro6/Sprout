package com.ledro6.sprout.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.geometry.Rect
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.model.Friends
import com.ledro6.sprout.model.Garden
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Pour
import com.ledro6.sprout.model.Prefs
import com.ledro6.sprout.model.Recents
import com.ledro6.sprout.model.Removal
import com.ledro6.sprout.model.Season
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Shelf
import com.ledro6.sprout.platform.AndroidPrefs
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.FileShelf
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Shots
import com.ledro6.sprout.platform.Widgets
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Locale

/**
 * Всё приложение в одном месте: сад, настройки, друзья, недавние запросы и
 * корзина отмены. Одно на процесс — его видят экраны, виджет и кнопка
 * «Полил» в уведомлении, и поливают один и тот же сад.
 */
class Sprout(prefs: Prefs, shelf: Shelf, clock: () -> Long = System::currentTimeMillis) {
    val settings = Settings(prefs)
    val garden = Garden(shelf, clock)
    val friends = Friends(prefs)
    val recents = Recents(prefs)
    val bin = Bin(garden)

    /** Поправка на время года — по сегодняшнему месяцу и стране телефона. */
    fun settle() = Season.settle(settings.seasons, Calendar.getInstance().get(Calendar.MONTH) + 1, Locale.getDefault().country)

    companion object {
        @Volatile
        private var made: Sprout? = null

        fun get(context: Context): Sprout = made ?: synchronized(this) {
            made ?: run {
                val app = context.applicationContext
                Shots.open(app)
                Sprout(AndroidPrefs(app), FileShelf(app)).also {
                    made = it
                    // Процесс мог подняться ради виджета, плитки или «Полил» —
                    // сроки и там с поправкой на время года, как в приложении.
                    it.settle()
                    Feel.open(app, it.settings)
                    Lock.attach(it.settings)
                    // Записали сад — виджету пора перерисоваться.
                    it.garden.saved = { Widgets.nudge(app) }
                }
            }
        }

        /** Для проверок: свой сад вместо файла. */
        fun install(sprout: Sprout) {
            made = sprout
        }
    }
}

val LocalSprout = staticCompositionLocalOf<Sprout> { error("Sprout не передан") }

/** Что можно вернуть: убранное растение или полив. */
sealed class Slip {
    data class Gone(val removal: Removal) : Slip()
    data class Poured(val pour: Pour) : Slip()

    val key: String
        get() = when (this) {
            is Gone -> "removal-${removal.plant.id}"
            is Poured -> "pour-${pour.plant}-${pour.at}"
        }

    val title: String
        get() = when (this) {
            is Gone -> Lang.text("Растение удалено")
            is Poured -> Lang.text("Полито")
        }

    val name: String
        get() = when (this) {
            is Gone -> removal.plant.name
            is Poured -> pour.name
        }
}

/**
 * Корзина отмены: пять секунд после удаления или полива можно всё вернуть.
 * Новое действие закрывает прежнее — отмена одна, как у Snackbar.
 */
class Bin(private val garden: Garden) {
    var pending: Slip? by mutableStateOf(null)
        private set
    var left by mutableIntStateOf(0)
        private set
    var since: Double? by mutableStateOf(null)
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var run: Job? = null

    fun toss(id: String, from: Rect?) {
        commit()
        val gone = garden.remove(id) ?: return
        Effects.light(from)
        Feel.toss()
        count(Slip.Gone(gone))
    }

    /** Отвечает, полилось ли: растения могло уже не быть. */
    fun water(id: String): Boolean {
        commit()
        val pour = garden.water(id) ?: return false
        count(Slip.Poured(pour))
        return true
    }

    private fun count(slip: Slip) {
        pending = slip
        since = Effects.now()
        left = Motion.UNDO_SECONDS.toInt()
        run?.cancel()
        run = scope.launch {
            for (second in Motion.UNDO_SECONDS.toInt() - 1 downTo 0) {
                delay(1000)
                if (second <= 0) {
                    commit()
                    return@launch
                }
                left = second
            }
        }
    }

    fun undo() {
        val slip = pending ?: return
        run?.cancel()
        when (slip) {
            is Slip.Gone -> garden.putBack(slip.removal)
            is Slip.Poured -> garden.unwater(slip.pour)
        }
        pending = null
        since = null
        Effects.douse()
        Feel.back()
    }

    /** Отсчёт вышел или начали новое — удалённое уходит насовсем, со снимком. */
    fun commit() {
        val slip = pending ?: return
        run?.cancel()
        if (slip is Slip.Gone) garden.dropShot(slip.removal.plant.shot)
        pending = null
        since = null
        Effects.douse()
    }
}
