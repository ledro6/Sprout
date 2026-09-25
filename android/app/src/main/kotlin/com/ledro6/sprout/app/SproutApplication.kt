package com.ledro6.sprout.app

import android.app.Application
import android.content.res.Configuration
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.ledro6.sprout.platform.ArSupport
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Notifier
import com.ledro6.sprout.platform.Platform
import com.ledro6.sprout.platform.Widgets

/**
 * Процесс приложения: язык и формат дат — до первого экрана, виджета или
 * кнопки «Полил» в шторке; каналы уведомлений — на этом языке. Уход всего
 * приложения с экрана (а не одного экрана — AR открывается поверх сада)
 * запирает сад, пишет его на диск и ставит напоминания.
 */
open class SproutApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Platform.speak(this)
        Notifier.register(this)
        checkAr()
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = back()

            override fun onStop(owner: LifecycleOwner) = away()
        })
    }

    /** Умеет ли телефон AR — спрашиваем сервисы Google Play для AR. */
    protected open fun checkAr() = ArSupport.check(this)

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        Platform.speak(this)
        Notifier.register(this)
    }

    /** Вернулись: сад мог полить виджет или кнопка в уведомлении; ждать напоминаний незачем. */
    private fun back() {
        val sprout = Sprout.get(this)
        sprout.garden.reload()
        sprout.settle()
        Notifier.clear(this)
    }

    /** Ушли: сад под замок и на диск, удалённое — насовсем, напоминания — в очередь. */
    private fun away() {
        val sprout = Sprout.get(this)
        Lock.close()
        sprout.garden.save()
        sprout.bin.commit()
        if (sprout.settings.reminders) Notifier.schedule(this, sprout.garden.rooms, sprout.settings.threshold)
        Widgets.nudge(this)
    }
}
