package com.ledro6.sprout

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.SproutBackground
import com.ledro6.sprout.design.SproutTheme
import com.ledro6.sprout.model.MemoryPrefs
import com.ledro6.sprout.model.MemoryShelf
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [36], qualifiers = "w411dp-h891dp-xxhdpi")
class HelloShotTest {
    @get:Rule val compose = createComposeRule()

    @Test fun background() {
        Effects.still = true
        Effects.skip()
        val sprout = Sprout(MemoryPrefs(), MemoryShelf())
        var dark by mutableStateOf(false)
        compose.setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                SproutTheme(dark = dark) { SproutBackground() }
            }
        }
        compose.onRoot().captureRoboImage("build/shots/background-light.png")
        dark = true
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/shots/background-dark.png")
    }
}
