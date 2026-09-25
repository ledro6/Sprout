package com.ledro6.sprout.ui.components

import android.os.Build
import android.widget.NumberPicker
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Species
import com.ledro6.sprout.model.roundedInt
import com.ledro6.sprout.platform.Feel
import java.text.NumberFormat

/**
 * Барабан — родной `NumberPicker` Android: крутится пальцем, щёлкает на
 * каждом шаге и понятен TalkBack. Подписи — на языке приложения.
 */
@Composable
fun Wheel(
    value: Int,
    range: IntRange,
    label: (Int) -> String,
    modifier: Modifier = Modifier,
    onChange: (Int) -> Unit,
) {
    val change by rememberUpdatedState(onChange)
    val ink = MaterialTheme.colorScheme.onSurface.toArgb()
    val values = range.map(label).toTypedArray()
    AndroidView(
        factory = { context ->
            NumberPicker(context).apply {
                descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
                wrapSelectorWheel = false
                setOnValueChangedListener { _, _, new ->
                    Feel.pick()
                    change(range.first + new)
                }
            }
        },
        update = { picker ->
            // Подписи — прежде границ: иначе барабан спросит подпись, которой нет.
            if (picker.maxValue != values.size - 1 || picker.displayedValues?.contentEquals(values) != true) {
                picker.displayedValues = null
                picker.minValue = 0
                picker.maxValue = values.size - 1
                picker.displayedValues = values
            }
            val index = (value - range.first).coerceIn(0, values.size - 1)
            if (picker.value != index) picker.value = index
            if (Build.VERSION.SDK_INT >= 29) picker.textColor = ink
        },
        modifier = modifier.height(140.dp),
    )
}

/** Порог напоминания — любым целым процентом. */
@Composable
fun PercentWheel(share: Double, onChange: (Double) -> Unit) {
    val range = Settings.THRESHOLDS
    val whole = (share * 100).roundedInt().coerceIn(range.first, range.last)
    Wheel(whole, range, { Lang.format("%lld%%", it) }, Modifier.width(96.dp)) { onChange(it / 100.0) }
}

/**
 * Срок полива: «Раз в [7] дней» — число на барабане посреди фразы, как на
 * iPhone. Слова вокруг меняются вместе с числом: «день», «дня», «дней».
 */
@Composable
fun PeriodWheel(days: Double, onChange: (Double) -> Unit) {
    val whole = days.roundedInt().coerceIn(1, Species.LONGEST)
    val (before, after) = around(whole)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (before.isNotEmpty()) Text(before, style = MaterialTheme.typography.bodyLarge)
        Wheel(whole, 1..Species.LONGEST, { NumberFormat.getIntegerInstance(Lang.locale).format(it) }, Modifier.width(72.dp)) {
            onChange(it.toDouble())
        }
        if (after.isNotEmpty()) {
            AnimatedContent(after, label = "после числа") { Text(it, style = MaterialTheme.typography.bodyLarge) }
        }
    }
}

/** Фраза срока вокруг числа: «Раз в» и «дней». */
fun around(count: Int): Pair<String, String> {
    val line = Species.periodLabel(count.toDouble())
    val marks = listOf(NumberFormat.getIntegerInstance(Lang.locale).format(count), "$count")
    val at = marks.map { line.indexOf(it) to it }.firstOrNull { it.first >= 0 } ?: return line to ""
    return line.substring(0, at.first).trim() to line.substring(at.first + at.second.length).trim()
}
