package com.ledro6.sprout.ar

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.runtime.CompositionLocalProvider
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.design.SproutTheme
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Platform

/**
 * AR — отдельным экраном поверх сада: камере и сцене нужно всё окно. Сад
 * тот же, поливы идут в него же.
 */
class ArActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Platform.speak(this)
        val sprout = Sprout.get(this)
        val ids = intent.getStringArrayExtra(PLANTS)?.toList().orEmpty()
        setContent {
            CompositionLocalProvider(LocalSprout provides sprout) {
                // Поверх камеры читается тёмная тема: светлые плашки на фото слепят.
                SproutTheme(dark = true, dynamic = sprout.settings.dynamicColor) {
                    ArScreen(ids, close = ::finish)
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        // Сад заперли, пока AR был в фоне, — отпирают его на главном экране.
        if (Lock.locked) finish()
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(!Lock.on)
    }

    companion object {
        private const val PLANTS = "plants"

        fun intent(context: Context, ids: List<String>): Intent =
            Intent(context, ArActivity::class.java).putExtra(PLANTS, ids.toTypedArray())
    }
}
