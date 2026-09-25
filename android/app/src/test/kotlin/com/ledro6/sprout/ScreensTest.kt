package com.ledro6.sprout

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.SproutTheme
import com.ledro6.sprout.model.Almanac
import com.ledro6.sprout.model.MemoryPrefs
import com.ledro6.sprout.model.MemoryShelf
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Skeleton
import com.ledro6.sprout.model.Traits
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Platform
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.SproutRoot
import com.ledro6.sprout.ui.Tab
import com.ledro6.sprout.ui.onboarding.LockScreen
import com.ledro6.sprout.ui.onboarding.TourScreen
import com.ledro6.sprout.ui.onboarding.Welcome
import com.ledro6.sprout.ui.stats.StatsPeriod
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Обход всех экранов без телефона: каждый открывается, рисуется и
 * снимается в build/shots — светлая и тёмная тема, русский, английский,
 * арабский (справа налево), немецкий с крупным шрифтом, маленький экран и
 * планшет. Упал экран — падает проверка; снимки смотрит человек.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [36], qualifiers = "ru-w411dp-h891dp-xxhdpi")
class ScreensTest {
    @get:Rule val compose = createComposeRule()

    private lateinit var sprout: Sprout
    private lateinit var go: Go
    private val day = 86_400_000L

    @Before
    fun setUp() {
        Effects.still = true
        Effects.skip()
        StatsPeriod.period = Almanac.Period.MONTH
        var now = System.currentTimeMillis() - 24 * day
        sprout = Sprout(MemoryPrefs(), MemoryShelf()) { now }
        // Три недели поливов — чтобы статистике было что показать.
        val ids = sprout.garden.plants.map { it.id }
        repeat(24) { step ->
            now += day
            ids.filterIndexed { index, _ -> (index + step) % 3 == 0 }.forEach { sprout.garden.water(it) }
            sprout.garden.advance(now)
        }
        now = System.currentTimeMillis()
        sprout.garden.advance(now)
        sprout.settings.toured = true
        Walk.entries.forEach { sprout.settings.mark(it) }
        Sprout.install(sprout)
        Lock.attach(sprout.settings)
    }

    @After
    fun tearDown() {
        Effects.still = false
    }

    private fun speak() {
        Platform.speak(ApplicationProvider.getApplicationContext<Context>())
        Skeleton.hours24 = true
    }

    private fun app(dark: Boolean) {
        // Язык — из ресурсов экрана, как на телефоне.
        speak()
        compose.setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(dark = dark) {
                    val nav = rememberNavController()
                    go = remember(nav) { Go(nav) {} }
                    SproutRoot(nav, go)
                }
            }
        }
        compose.waitForIdle()
    }

    private fun shoot(name: String) {
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/shots/$name.png")
    }

    private fun open(step: Go.() -> Unit) {
        compose.runOnUiThread { go.step() }
        compose.waitForIdle()
    }

    /** Все экраны по очереди — как их пролистал бы человек. */
    private fun walk(prefix: String, all: Boolean = true) {
        val plant = sprout.garden.plants.first().id
        shoot("$prefix-01-home")
        open { tab(Tab.STATS) }
        shoot("$prefix-02-stats")
        open { tab(Tab.ADD) }
        shoot("$prefix-03-add")
        open { tab(Tab.PROFILE) }
        shoot("$prefix-04-profile")
        open { tab(Tab.SEARCH) }
        shoot("$prefix-05-search")
        open { tab(Tab.HOME) }
        open { plant(plant) }
        shoot("$prefix-06-plant")
        if (!all) return
        open { tune(plant) }
        shoot("$prefix-07-tune")
        open { back() }
        open { model(plant) }
        shoot("$prefix-08-model")
        open { back() }
        open { back() }
        open { book(plant) }
        shoot("$prefix-09-book")
        open { back() }
        open { orrery() }
        shoot("$prefix-10-orrery")
        open { back() }
        open { settings() }
        shoot("$prefix-11-settings")
        open { about() }
        shoot("$prefix-12-about")
        open { back() }
        open { privacy() }
        shoot("$prefix-13-privacy")
        open { back() }
        open { glossary() }
        shoot("$prefix-14-glossary")
        open { back() }
        open { back() }
        open { rooms() }
        shoot("$prefix-15-rooms")
        open { back() }
        open { trip() }
        shoot("$prefix-16-trip")
        open { back() }
    }

    @Test fun lightRussian() {
        app(dark = false)
        walk("ru-light")
    }

    @Test fun darkRussian() {
        app(dark = true)
        walk("ru-dark")
    }

    @Test @Config(qualifiers = "en-w411dp-h891dp-xxhdpi")
    fun english() {
        app(dark = false)
        walk("en-light")
    }

    @Test @Config(qualifiers = "ar-w411dp-h891dp-xxhdpi")
    fun arabicRightToLeft() {
        app(dark = false)
        walk("ar-rtl", all = false)
        open { settings() }
        shoot("ar-rtl-11-settings")
    }

    @Test @Config(qualifiers = "de-w411dp-h891dp-xxhdpi", fontScale = 1.6f)
    fun germanLargeText() {
        app(dark = false)
        walk("de-font", all = false)
        open { settings() }
        shoot("de-font-11-settings")
    }

    @Test @Config(qualifiers = "ja-w360dp-h640dp-xhdpi")
    fun japaneseSmallPhone() {
        app(dark = true)
        walk("ja-small", all = false)
    }

    @Test @Config(qualifiers = "ru-w840dp-h1280dp-xhdpi")
    fun tablet() {
        app(dark = false)
        walk("tablet", all = false)
    }

    /** Телефон боком: вкладки уходят в боковую панель. */
    @Test @Config(qualifiers = "ru-w891dp-h411dp-land-xxhdpi")
    fun landscape() {
        app(dark = false)
        walk("land", all = false)
    }

    /** Полив с экрана растения: волна, плашка «Вернуть», отмена. */
    @Test fun waterAndUndo() {
        app(dark = false)
        val plant = sprout.garden.plants.first()
        open { plant(plant.id) }
        compose.runOnUiThread { sprout.bin.water(plant.id) }
        shoot("action-01-watered")
        check(sprout.garden.plant(plant.id)!!.moisture == 1.0) { "полив не дошёл до сада" }
        compose.runOnUiThread { sprout.bin.undo() }
        shoot("action-02-undone")
        check(sprout.garden.plant(plant.id)!!.moisture < 1.0) { "отмена не вернула влажность" }
        compose.runOnUiThread { sprout.bin.toss(plant.id, null) }
        shoot("action-03-tossed")
        check(sprout.garden.plant(plant.id) == null) { "удалённое осталось в саду" }
        compose.runOnUiThread { sprout.bin.undo() }
        shoot("action-04-back")
        check(sprout.garden.plant(plant.id) != null) { "растение не вернулось" }
    }

    /** Своя модель «по фото» — экран модели и статистика растения. */
    @Test fun imaginedModel() {
        val plant = sprout.garden.plants.first()
        sprout.garden.imagine(plant.id, Traits(leaf = com.ledro6.sprout.model.Channels(120.0, 170.0, 80.0)))
        app(dark = false)
        open { model(plant.id) }
        shoot("model-imagined")
    }

    /** Пустой сад: главная, статистика, поиск без растений. */
    @Test fun emptyGarden() {
        compose.runOnUiThread { sprout.garden.erase() }
        app(dark = false)
        shoot("empty-01-home")
        open { tab(Tab.STATS) }
        shoot("empty-02-stats")
        open { tab(Tab.SEARCH) }
        shoot("empty-03-search")
    }

    @Test fun onboarding() {
        speak()
        compose.setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(dark = false) { Box(Modifier.fillMaxSize()) { Welcome() } }
            }
        }
        shoot("start-01-welcome")
    }

    @OptIn(com.github.takahirom.roborazzi.ExperimentalRoborazziApi::class)
    @Test fun tour() {
        speak()
        compose.setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(dark = false) { TourScreen {} }
            }
        }
        compose.waitForIdle()
        // Окно диалога — отдельное; снимок — всего экрана.
        com.github.takahirom.roborazzi.captureScreenRoboImage("build/shots/start-02-tour.png")
    }

    @Test fun locked() {
        speak()
        sprout.settings.lock = true
        compose.setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(dark = true) { LockScreen() }
            }
        }
        shoot("start-03-locked")
    }

    @Test fun listLook() {
        sprout.settings.look = Settings.Look.LIST
        app(dark = false)
        shoot("home-list")
    }
}
