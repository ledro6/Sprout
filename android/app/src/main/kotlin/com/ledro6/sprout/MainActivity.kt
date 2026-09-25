package com.ledro6.sprout

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.navigation.compose.rememberNavController
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.ar.ArActivity
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.SproutTheme
import com.ledro6.sprout.model.Season
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Platform
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.SproutRoot
import com.ledro6.sprout.ui.Tab
import com.ledro6.sprout.ui.onboarding.LockScreen
import com.ledro6.sprout.ui.onboarding.TourGate
import com.ledro6.sprout.ui.onboarding.TourScreen
import com.ledro6.sprout.ui.onboarding.Welcome
import kotlinx.coroutines.delay
import java.util.Calendar
import java.util.Locale

/**
 * Единственный экран-активити: всё приложение — Compose. Здесь — то, что на
 * iPhone делает корень: часы сада, заставка, знакомство, замок, напоминания
 * при уходе с экрана и возвращение к саду, который мог полить виджет.
 */
class MainActivity : AppCompatActivity() {
    private val sprout by lazy { Sprout.get(this) }

    /** Вкладка из ярлыка на значке. */
    private var asked by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        Platform.speak(this)
        val settings = sprout.settings
        if (!counted) {
            settings.launched()
            counted = true
        }
        asked = intent?.getStringExtra(TAB)
        setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(settings) { Content(settings) }
            }
        }
    }

    @androidx.compose.runtime.Composable
    private fun Content(settings: Settings) {
        val dark = when (settings.theme) {
            Settings.Theme.SYSTEM -> isSystemInDarkTheme()
            Settings.Theme.LIGHT -> false
            Settings.Theme.DARK -> true
        }
        DisposableEffect(dark) {
            enableEdgeToEdge(
                statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT) { dark },
                navigationBarStyle = SystemBarStyle.auto(LIGHT_SCRIM, DARK_SCRIM) { dark },
            )
            onDispose {}
        }
        val nav = rememberNavController()
        val go = remember(nav) { Go(nav) { ids -> startActivity(ArActivity.intent(this, ids)) } }
        LaunchedEffect(Unit) { Effects.run { Feel.sprout() } }
        // Часы сада: раз в секунду сад подсыхает.
        LaunchedEffect(Unit) {
            while (true) {
                delay(1_000)
                sprout.garden.advance()
            }
        }
        LaunchedEffect(asked) {
            val route = asked ?: return@LaunchedEffect
            Tab.entries.firstOrNull { it.route == route }?.let { go.tab(it) }
            asked = null
        }
        LaunchedEffect(settings.seasons) { settle(settings) }
        Box(Modifier.fillMaxSize()) {
            SproutRoot(nav, go)
            AnimatedVisibility(Effects.greeting, exit = fadeOut(tween((Motion.WELCOME_LEAVE * 1000).toInt()))) { Welcome() }
            val touring = !settings.toured && Effects.step >= Effects.LAST && !Lock.locked
            if (touring || (TourGate.open && !Lock.locked)) {
                TourScreen {
                    settings.toured = true
                    TourGate.open = false
                }
            }
            if (Lock.locked) LockScreen()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(TAB)?.let { asked = it }
    }

    override fun onStart() {
        super.onStart()
        // Сад под замком — спрашиваем отпечаток, как только экран виден.
        Lock.unlock(this)
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(!Lock.on)
    }

    private fun settle(settings: Settings) {
        Season.settle(settings.seasons, Calendar.getInstance().get(Calendar.MONTH) + 1, Locale.getDefault().country)
    }

    companion object {
        const val TAB = "tab"
        private val LIGHT_SCRIM = Color.argb(0xE6, 0xFF, 0xFF, 0xFF)
        private val DARK_SCRIM = Color.argb(0x80, 0x1B, 0x1B, 0x1B)

        /** Запуск считается один раз на процесс, а не на каждый поворот экрана. */
        private var counted = false
    }
}
