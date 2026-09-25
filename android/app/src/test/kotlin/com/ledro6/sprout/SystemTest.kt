package com.ledro6.sprout

import android.Manifest
import android.app.Application
import android.app.NotificationManager
import android.content.Intent
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.appwidget.compose
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.WorkManagerTestInitHelper
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.MemoryPrefs
import com.ledro6.sprout.model.MemoryShelf
import com.ledro6.sprout.model.Reminder
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Notifier
import com.ledro6.sprout.platform.Platform
import com.ledro6.sprout.platform.ThirstTile
import com.ledro6.sprout.platform.ThirstWidget
import com.ledro6.sprout.ui.Tab
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowBiometricManager
import org.xmlpull.v1.XmlPullParser

/**
 * Система без телефона: то, чего не видно на снимках экранов, — запуск
 * приложения и ярлыки, замок, уведомление с «Полил», будильник напоминания,
 * уход в фон, плитка и виджет. Всё — настоящими частями Android под
 * Robolectric, а не вызовами кода в обход них.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [36], qualifiers = "ru-w411dp-h891dp-xxhdpi")
class SystemTest {
    @get:Rule val compose = createEmptyComposeRule()

    private val app: Application get() = ApplicationProvider.getApplicationContext()
    private lateinit var sprout: Sprout
    private val notes get() = shadowOf(app.getSystemService(NotificationManager::class.java))

    @Before
    fun setUp() {
        Effects.still = true
        Effects.skip()
        sprout = Sprout(MemoryPrefs(), MemoryShelf())
        sprout.settings.toured = true
        Walk.entries.forEach { sprout.settings.mark(it) }
        Sprout.install(sprout)
        Lock.attach(sprout.settings)
        Platform.speak(app)
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        WorkManagerTestInitHelper.initializeTestWorkManager(
            app,
            Configuration.Builder().setExecutor(SynchronousExecutor()).build(),
        )
    }

    @After
    fun tearDown() {
        Effects.still = false
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun shows(text: String): Boolean {
        compose.waitForIdle()
        return compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
    }

    /** Приложение встаёт с заставкой и открывает вкладку из ярлыка — и при запуске, и поверх открытого. */
    @Test
    fun launchOpensShortcutTab() {
        val start = Intent(app, MainActivity::class.java).putExtra(MainActivity.TAB, Tab.STATS.route)
        val activity = Robolectric.buildActivity(MainActivity::class.java, start).setup()
        check(shows(Lang.text("Планетарий сада"))) { "ярлык «Статистика» не открыл статистику" }
        activity.newIntent(Intent(app, MainActivity::class.java).putExtra(MainActivity.TAB, Tab.SEARCH.route))
        check(shows(Lang.text("Найти растение"))) { "ярлык поверх открытого приложения не сработал" }
        activity.pause().stop().destroy()
    }

    /** Ярлыки на значке ведут в это приложение и на существующие вкладки. */
    @Test
    fun shortcutsPointToTabs() {
        val parser = app.resources.getXml(R.xml.shortcuts)
        val tabs = mutableListOf<String>()
        val labels = mutableListOf<Int>()
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            val ns = "http://schemas.android.com/apk/res/android"
            when (parser.name) {
                "shortcut" -> labels += parser.getAttributeResourceValue(ns, "shortcutShortLabel", 0)
                "intent" -> {
                    check(parser.getAttributeValue(ns, "targetPackage") == app.packageName) { "ярлык ведёт в чужое приложение" }
                    check(parser.getAttributeValue(ns, "targetClass") == MainActivity::class.java.name) { "ярлык ведёт мимо главного экрана" }
                }
                "extra" -> tabs += parser.getAttributeValue(ns, "value")
            }
        }
        check(tabs.isNotEmpty()) { "ярлыков нет" }
        check(tabs.all { tab -> Tab.entries.any { it.route == tab } }) { "ярлык на несуществующую вкладку: $tabs" }
        check(labels.all { it != 0 && app.getString(it).isNotBlank() }) { "у ярлыка нет подписи" }
    }

    private fun screenLock(on: Boolean) =
        Shadow.extract<ShadowBiometricManager>(app.getSystemService(android.hardware.biometrics.BiometricManager::class.java))
            .setCanAuthenticate(on)

    /** Замок: телефон с блокировкой экрана — сад заперт и спрашивает отпечаток или код. */
    @Test
    fun lockAsks() {
        screenLock(true)
        sprout.settings.lock = true
        // Замок читает настройку при подключении — подключаем заново.
        Lock.attach(Sprout(MemoryPrefs(), MemoryShelf()).settings)
        Lock.attach(sprout.settings)
        val activity = Robolectric.buildActivity(MainActivity::class.java).setup()
        idle()
        check(Lock.locked && Lock.asking) { "запертый сад не спросил отпечаток" }
        check(shows(Lang.text("Сад заперт"))) { "запертый сад виден" }
        activity.pause().stop().destroy()
    }

    /** Замок: без блокировки экрана на телефоне сад запертым не остаётся. */
    @Test
    fun lockWithoutScreenLockOpens() {
        screenLock(false)
        sprout.settings.lock = true
        // Замок читает настройку при подключении — подключаем заново.
        Lock.attach(Sprout(MemoryPrefs(), MemoryShelf()).settings)
        Lock.attach(sprout.settings)
        check(Lock.locked) { "включённый замок не запер сад" }
        val activity = Robolectric.buildActivity(MainActivity::class.java).setup()
        idle()
        check(!Lock.locked) { "сад остался заперт на телефоне без блокировки экрана" }
        check(!sprout.settings.lock) { "замок не выключился" }
        activity.pause().stop().destroy()
    }

    /** «Полил» в уведомлении поливает сад, убирает уведомление. */
    @Test
    fun pourFromNotification() {
        val dry = sprout.garden.plants.minBy { it.moisture }
        check(dry.moisture < 1.0)
        Notifier.register(app)
        val channels = notes.notificationChannels.map { (it as android.app.NotificationChannel).id }
        check("watering" in channels && "care" in channels) { "каналов уведомлений нет: $channels" }
        Notifier.post(app, "watering", "Заголовок", "Текст", listOf(dry.id))
        val shown = notes.allNotifications.singleOrNull() ?: error("уведомление не показано")
        val pour = shown.actions?.singleOrNull() ?: error("нет кнопки «Полил»")
        check(pour.title.toString() == Lang.text("Полил")) { "кнопка подписана «${pour.title}»" }
        // Кнопка шлёт приёмнику `Pour` его действие со списком растений.
        val sent = shadowOf(pour.actionIntent).savedIntent
        check(shadowOf(pour.actionIntent).isBroadcast) { "«Полил» не рассылка" }
        check(sent.component?.className == Notifier.Pour::class.java.name) { "«Полил» уходит не тому: ${sent.component}" }
        Notifier.Pour().onReceive(app, sent)
        idle()
        check(sprout.garden.plant(dry.id)!!.moisture == 1.0) { "«Полил» не полил" }
        check(notes.allNotifications.isEmpty()) { "уведомление не убралось после полива" }
    }

    /** Без разрешения на уведомления — ни уведомлений, ни будильников. */
    @Test
    fun noPermissionNoReminders() {
        shadowOf(app).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        Notifier.post(app, "watering", "Заголовок", "Текст", emptyList())
        check(notes.allNotifications.isEmpty()) { "уведомление без разрешения" }
        Notifier.schedule(app, sprout.garden.rooms, sprout.settings.threshold)
        val work = WorkManager.getInstance(app).getWorkInfosForUniqueWork("watering").get()
        check(work.none { it.state == WorkInfo.State.ENQUEUED }) { "будильник без разрешения" }
    }

    /** Будильник напоминания: ставится при уходе, срабатывает — уведомление с текстом `Reminder`. */
    @Test
    fun reminderRings() {
        val due = Reminder.next(sprout.garden.rooms, sprout.settings.threshold) ?: error("в саду некого поливать")
        Notifier.schedule(app, sprout.garden.rooms, sprout.settings.threshold)
        val work = WorkManager.getInstance(app).getWorkInfosForUniqueWork("watering").get().single()
        check(work.state == WorkInfo.State.ENQUEUED) { "будильник не поставлен: ${work.state}" }
        WorkManagerTestInitHelper.getTestDriver(app)!!.setInitialDelayMet(work.id)
        val shown = notes.allNotifications.singleOrNull() ?: error("будильник не показал уведомление")
        val extras = shown.extras
        check(extras.getString("android.title") == Reminder.title) { "заголовок: ${extras.getString("android.title")}" }
        check(extras.getCharSequence("android.text").toString() == Reminder.text(due)) { "текст не тот" }
        check(shown.actions?.size == 1) { "у напоминания о поливе нет «Полил»" }
        // Открыли приложение — ждать больше нечего.
        Notifier.clear(app)
        val after = WorkManager.getInstance(app).getWorkInfosForUniqueWork("watering").get().single()
        check(after.state != WorkInfo.State.ENQUEUED) { "будильник не снят при возвращении" }
    }

    /** Плитка в шторке: сколько ждут воды, горит, если хоть одному пора. */
    @Test
    fun quickSettingsTile() {
        val service = Robolectric.buildService(ThirstTile::class.java).create().get()
        service.onStartListening()
        val tile = service.qsTile ?: return
        check(tile.label.toString() == Lang.text("Ждут воды")) { "подпись плитки: ${tile.label}" }
        check(tile.state == android.service.quicksettings.Tile.STATE_ACTIVE) { "в саду есть сухие, а плитка не горит" }
    }

    /** Виджет по-настоящему собирается в RemoteViews и раскладывается — во всех трёх размерах. */
    @OptIn(DelicateCoroutinesApi::class, ExperimentalCoroutinesApi::class, ExperimentalGlanceApi::class)
    @Test
    fun widgetInflates() {
        val driest = sprout.garden.plants.sortedBy { it.moisture }
        for (size in listOf(DpSize(110.dp, 110.dp), DpSize(250.dp, 110.dp), DpSize(250.dp, 250.dp))) {
            val job = GlobalScope.async(Dispatchers.Default) { ThirstWidget().compose(app, size = size) }
            while (!job.isCompleted) {
                idle()
                Thread.sleep(5)
            }
            val root = job.getCompleted().apply(app, FrameLayout(app))
            val texts = texts(root)
            check(driest.first().name in texts) { "виджет $size без самого сухого растения: $texts" }
        }
        sprout.garden.erase()
        val job = GlobalScope.async(Dispatchers.Default) { ThirstWidget().compose(app, size = DpSize(250.dp, 250.dp)) }
        while (!job.isCompleted) {
            idle()
            Thread.sleep(5)
        }
        val texts = texts(job.getCompleted().apply(app, FrameLayout(app)))
        check(Lang.text("В саду пока пусто.") in texts) { "пустой сад на виджете: $texts" }
    }

    private fun texts(view: View): List<String> = when (view) {
        is TextView -> listOf(view.text.toString())
        is ViewGroup -> (0 until view.childCount).flatMap { texts(view.getChildAt(it)) }
        else -> emptyList()
    }
}
