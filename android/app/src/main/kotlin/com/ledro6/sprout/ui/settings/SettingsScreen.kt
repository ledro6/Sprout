package com.ledro6.sprout.ui.settings

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings as System
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.design.SproutShapes
import com.ledro6.sprout.model.Front
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Season
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.model.roundedInt
import com.ledro6.sprout.platform.Chime
import com.ledro6.sprout.platform.Chimes
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.platform.Notifier
import com.ledro6.sprout.platform.Platform
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Coach
import com.ledro6.sprout.ui.components.PercentWheel
import com.ledro6.sprout.ui.components.SproutBlock
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SproutLink
import com.ledro6.sprout.ui.components.SproutTints
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermHint
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.onboarding.TourGate
import com.ledro6.sprout.ui.stats.Segments
import java.util.Calendar
import java.util.Locale

/** Языки приложения — те же 48, что на iPhone. */
val LANGUAGES = listOf(
    "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr",
    "gu", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "kn", "ko", "lt",
    "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro",
    "ru", "sk", "sl", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi",
    "zh-Hans", "zh-Hant",
)

/** Настройки: оформление, фон, звук и вибрация, полив, защита и сведения. */
@Composable
fun SettingsScreen(go: Go) {
    SubScreen(Lang.text("Настройки"), onBack = go::back, walk = Walk.SETTINGS, large = true) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Look(Modifier.hintSpot(Hint.Target.SETTINGS_LOOK))
            Backdrop(Modifier.hintSpot(Hint.Target.SETTINGS_BACKDROP))
            Senses()
            Watering(Modifier.hintSpot(Hint.Target.SETTINGS_WATERING))
            Protection()
            About(go, Modifier.hintSpot(Hint.Target.SETTINGS_ABOUT))
        }
    }
}

/** Строка с переключателем: вся строка нажимается, как в настройках Android. */
@Composable
fun SwitchRow(title: String, checked: Boolean, term: Term? = null, note: String? = null, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .toggleable(checked, enabled = enabled, role = Role.Switch, onValueChange = onChange),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f),
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (term != null) TermHint(term)
            }
            if (note != null) {
                Text(note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Switch(checked = checked, onCheckedChange = null, enabled = enabled)
    }
}

@Composable
private fun Look(modifier: Modifier) {
    val settings = LocalSprout.current.settings
    val density = LocalDensity.current.density
    val context = LocalContext.current
    var languages by remember { mutableStateOf(false) }
    SproutGroup(Lang.text("Оформление"), modifier) {
        SproutBlock(Lang.text("Тема")) {
            Segments(Settings.Theme.entries, settings.theme, { it.short }) {
                settings.theme = it
                Feel.pick()
            }
        }
        if (Build.VERSION.SDK_INT >= 31) {
            SproutDivider()
            SwitchRow(Lang.text("Цвета обоев"), settings.dynamicColor, note = Lang.text("Кнопки и плашки — в цветах обоев телефона.")) {
                settings.dynamicColor = it
                Feel.pick()
            }
        }
        SproutDivider()
        val chosen = Platform.chosen(context)
        Row(
            Modifier
                .fillMaxWidth()
                .clickable(role = Role.Button) {
                    if (Build.VERSION.SDK_INT >= 33) {
                        val intent = Intent(System.ACTION_APP_LOCALE_SETTINGS, Uri.fromParts("package", context.packageName, null))
                        runCatching { context.startActivity(intent) }.onFailure { languages = true }
                    } else {
                        languages = true
                    }
                }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(Lang.text("Язык"), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Text(
                chosen?.let { Platform.languageName(it) } ?: Lang.text("Как в телефоне"),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Icon(painterResource(R.drawable.ic_chevron_right), null, tint = MaterialTheme.colorScheme.outline)
        }
        SproutDivider()
        SproutBlock(Lang.text("Цвет узора")) {
            SproutTints(settings.patternTint) { tint, spot ->
                Feel.pick()
                Effects.repaint(settings.patternTint, settings.waveTint, tint, settings.waveTint, spot)
                settings.patternTint = tint
            }
        }
        SproutDivider()
        SproutBlock(Lang.text("Цвет волны"), term = Term.WAVE) {
            SproutTints(settings.waveTint) { tint, spot ->
                settings.waveTint = tint
                Effects.cheer(Rect(spot, 1f), density)
                Feel.pick()
            }
        }
    }
    if (languages) Languages { languages = false }
}

/** Выбор языка до Android 13 — там системного выбора для приложения нет. */
@Composable
private fun Languages(close: () -> Unit) {
    val context = LocalContext.current
    val chosen = Platform.chosen(context)
    val options = listOf<String?>(null) + LANGUAGES.sortedBy { Platform.languageName(it).lowercase(Locale.ROOT) }
    AlertDialog(
        onDismissRequest = close,
        title = { Text(Lang.text("Язык")) },
        text = {
            LazyColumn(Modifier.height(420.dp)) {
                items(options) { tag ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable {
                                close()
                                if (tag != chosen) Platform.choose(context, tag)
                            }
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = tag == chosen, onClick = null)
                        Text(tag?.let { Platform.languageName(it) } ?: Lang.text("Как в телефоне"), Modifier.padding(start = 12.dp))
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = close) { Text(Lang.text("Отмена")) } },
    )
}

private val shapeNames = listOf(Lang.key("Росток"), Lang.key("Капля"), Lang.key("Цветок"), Lang.key("Горшок"))

@Composable
private fun Backdrop(modifier: Modifier) {
    val settings = LocalSprout.current.settings
    SproutGroup(Lang.text("Фон"), modifier) {
        SproutBlock(Lang.text("Фигурки"), note = Lang.text("Хотя бы одна остаётся.")) { Pieces() }
        SproutDivider()
        SwitchRow(Lang.text("Узор за наклоном"), settings.parallax, term = Term.PARALLAX) { settings.parallax = it }
        SproutDivider()
        SwitchRow(Lang.text("Фигурки плывут порознь"), settings.sway, term = Term.SWAY, enabled = settings.parallax) { settings.sway = it }
    }
}

@Composable
private fun Pieces() {
    val settings = LocalSprout.current.settings
    val palette = LocalPalette.current
    val accent = MaterialTheme.colorScheme.primary
    val spots = remember { HashMap<Int, Rect>() }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (index in 0 until Settings.SHAPE_COUNT) {
            val on = index in settings.shapes
            val colour = if (on) palette.swatch(settings.patternTint) else palette.ink.copy(alpha = Metrics.PIECE_OFF)
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (on) accent.copy(alpha = 0.14f) else Color.Transparent)
                    .onGloballyPositioned { spots[index] = it.boundsInRoot() }
                    .clickable(role = Role.Checkbox) {
                        val before = settings.chosen
                        if (!settings.toggle(index)) return@clickable
                        Feel.pick()
                        val spot = spots[index]?.center ?: Offset.Zero
                        val front = if (on) Front.Collapse(spot.x.toDouble(), spot.y.toDouble()) else Front.Point(spot.x.toDouble(), spot.y.toDouble())
                        Effects.reshape(before, settings.chosen, front)
                    }
                    .semantics {
                        contentDescription = Lang.text(shapeNames[index])
                        selected = on
                    }
                    .padding(vertical = 7.dp),
                contentAlignment = Alignment.Center,
            ) {
                Canvas(Modifier.width(52.dp).height(44.dp)) {
                    val piece = SproutShapes.pieces[index]
                    val scale = minOf(size.width / SproutShapes.PIECE_W, size.height / SproutShapes.PIECE_H)
                    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = colour.toArgb() }
                    drawIntoCanvas { canvas ->
                        val native = canvas.nativeCanvas
                        native.save()
                        native.translate(size.width / 2, size.height / 2)
                        native.scale(scale, scale)
                        native.translate(-piece.centreX, -piece.centreY)
                        native.drawPath(piece.path, paint)
                        native.restore()
                    }
                }
            }
        }
    }
}

@Composable
private fun Senses() {
    val settings = LocalSprout.current.settings
    SproutGroup(Lang.text("Звук и вибрация")) {
        SwitchRow(Lang.text("Звуки"), settings.sounds) {
            settings.sounds = it
            if (it) Chimes.play(Chime.POUR)
        }
        SproutDivider()
        SproutBlock(Lang.text("Сила вибрации")) {
            val percent = Lang.format("%lld%%", (settings.hapticStrength * 100).roundedInt())
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Slider(
                    value = settings.hapticStrength.toFloat(),
                    onValueChange = { next ->
                        val before = (settings.hapticStrength * 10).toInt()
                        settings.hapticStrength = next.toDouble()
                        if ((next * 10).toInt() != before) Feel.pick()
                    },
                    onValueChangeFinished = { Feel.sample() },
                    valueRange = 0f..1f,
                    steps = 19,
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = Lang.text("Сила вибрации") },
                )
                Text(percent, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.width(52.dp))
            }
        }
    }
}

@Composable
private fun Watering(modifier: Modifier) {
    val sprout = LocalSprout.current
    val settings = sprout.settings
    val context = LocalContext.current
    var denied by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && Notifier.allowed(context)) settings.reminders = true else denied = true
    }

    fun want(on: Boolean) {
        if (!on) {
            settings.reminders = false
            Notifier.clear(context)
            return
        }
        when {
            Notifier.allowed(context) -> settings.reminders = true
            Build.VERSION.SDK_INT >= 33 -> ask.launch(Manifest.permission.POST_NOTIFICATIONS)
            else -> denied = true
        }
    }

    SproutGroup(Lang.text("Полив"), modifier) {
        SwitchRow(Lang.text("Учитывать время года"), settings.seasons, term = Term.SEASONS) {
            settings.seasons = it
            Season.settle(it, Calendar.getInstance().get(Calendar.MONTH) + 1, Locale.getDefault().country)
        }
        SproutDivider()
        SwitchRow(Lang.text("Напоминать о поливе"), settings.reminders, term = Term.REMINDERS) { want(it) }
        AnimatedVisibility(settings.reminders) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SproutDivider()
                SproutBlock(Lang.text("Когда влажность ниже")) {
                    PercentWheel(settings.threshold) { settings.threshold = it }
                }
            }
        }
    }
    if (denied) {
        AlertDialog(
            onDismissRequest = { denied = false },
            title = { Text(Lang.text("Уведомления выключены")) },
            text = { Text(Lang.text("Их включают в настройках телефона: Sprout → Уведомления.")) },
            confirmButton = {
                TextButton(onClick = {
                    denied = false
                    val intent = Intent(System.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(System.EXTRA_APP_PACKAGE, context.packageName)
                    runCatching { context.startActivity(intent) }
                }) { Text(Lang.text("Открыть настройки")) }
            },
            dismissButton = { TextButton(onClick = { denied = false }) { Text(Lang.text("Отмена")) } },
        )
    }
}

@Composable
private fun Protection() {
    val context = LocalContext.current
    val ready = remember { Lock.ready(context) }
    SproutGroup(Lang.text("Защита")) {
        SwitchRow(
            Lang.text("Запирать приложение"), Lock.on, term = Term.LOCK,
            note = if (ready) null else Lang.text("На телефоне не настроена блокировка экрана."),
            enabled = ready || Lock.on,
        ) {
            Lock.turn(it)
            Feel.pick()
        }
        AnimatedVisibility(Lock.on) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SproutDivider()
                SproutLink(Lang.text("Запереть сейчас"), R.drawable.ic_lock) { Lock.close() }
            }
        }
    }
}

@Composable
private fun About(go: Go, modifier: Modifier) {
    val settings = LocalSprout.current.settings
    SproutGroup(Lang.text("О приложении"), modifier) {
        SproutLink(Lang.text("Как пользоваться"), R.drawable.ic_touch_app) { TourGate.open = true }
        SproutDivider()
        SproutLink(Lang.text("Словарик"), R.drawable.ic_dictionary, onClick = go::glossary)
        SproutDivider()
        SproutLink(Lang.text("Показать подсказки снова"), R.drawable.ic_lightbulb) {
            settings.rewalk()
            Coach.start(Walk.SETTINGS)
        }
        SproutDivider()
        SproutLink(Lang.text("Политика конфиденциальности"), R.drawable.ic_verified_user, onClick = go::privacy)
        SproutDivider()
        SproutLink(Lang.text("Сведения о приложении"), R.drawable.ic_info, onClick = go::about)
    }
}
