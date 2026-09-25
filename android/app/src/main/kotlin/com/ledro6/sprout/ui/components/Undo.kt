package com.ledro6.sprout.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.app.Bin
import com.ledro6.sprout.app.Slip
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.Palette
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Tint

/**
 * Плашка «Вернуть» — как Snackbar Material: снизу, над вкладками, пять
 * секунд. Кольцо отсчёта тает, число секунд идёт вниз.
 */
@Composable
fun UndoToast(bin: Bin, modifier: Modifier = Modifier) {
    val slip = bin.pending
    AnimatedContent(
        slip,
        transitionSpec = {
            (slideInVertically { it / 2 } + fadeIn()).togetherWith(slideOutVertically { it / 2 } + fadeOut())
        },
        contentKey = { it?.key },
        modifier = modifier,
        label = "вернуть",
    ) { shown ->
        if (shown != null) Toast(bin, shown)
    }
}

@Composable
private fun Toast(bin: Bin, slip: Slip) {
    val palette = LocalPalette.current
    val tint = if (slip is Slip.Gone) palette.alarm else palette.water
    Surface(
        shape = RoundedCornerShape(28.dp),
        color = MaterialTheme.colorScheme.inverseSurface,
        contentColor = MaterialTheme.colorScheme.inverseOnSurface,
        shadowElevation = 6.dp,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics { liveRegion = LiveRegionMode.Polite },
    ) {
        Row(
            Modifier.padding(start = 10.dp, end = 4.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Countdown(bin, tint)
            // Читалка экрана: живая область скажет это один раз, без тиканья секунд.
            val spoken = if (slip is Slip.Gone) Lang.format("Растение «%@» удалено. Его можно вернуть.", slip.name) else "${slip.title}, ${slip.name}"
            Column(Modifier.weight(1f).clearAndSetSemantics { contentDescription = spoken }) {
                Text(slip.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(slip.name, style = MaterialTheme.typography.bodySmall, maxLines = 1)
            }
            TextButton(onClick = { bin.undo() }) {
                Text(Lang.text("Вернуть"), color = MaterialTheme.colorScheme.inversePrimary, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun Countdown(bin: Bin, tint: Color) {
    var now by remember { mutableDoubleStateOf(Effects.now()) }
    LaunchedEffect(bin.since) {
        while (bin.since != null && !Effects.still) withFrameNanos { now = Effects.now() }
    }
    val since = bin.since
    val remaining = if (since == null) 0f else (1 - (now - since) / Motion.UNDO_SECONDS).toFloat().coerceIn(0f, 1f)
    val line = with(LocalDensity.current) { 2.5.dp.toPx() }
    Box(Modifier.size(30.dp).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(30.dp)) {
            drawCircle(tint.copy(alpha = 0.22f), style = Stroke(line))
            drawArc(tint, -90f, 360f * remaining, false, style = Stroke(line, cap = StrokeCap.Round))
        }
        AnimatedContent(bin.left, label = "секунды") {
            Text("$it", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = tint)
        }
    }
}

/** Цвета узора и волны — кружками; выбранный обведён. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SproutTints(current: Tint, onPick: (Tint, Offset) -> Unit) {
    val palette = LocalPalette.current
    val spots = remember { HashMap<Tint, Offset>() }
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        maxItemsInEachRow = 6,
    ) {
        for (tint in Tint.entries) {
            val picked = tint == current
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .then(if (picked) Modifier.border(2.dp, palette.accent, CircleShape) else Modifier)
                    .onGloballyPositioned { spots[tint] = it.boundsInRoot().center }
                    .clickable { onPick(tint, spots[tint] ?: Effects.middle.center) }
                    .semantics {
                        contentDescription = tint.title
                        selected = picked
                    },
                contentAlignment = Alignment.Center,
            ) {
                Canvas(Modifier.size(28.dp)) {
                    drawCircle(Palette.channels(tint.vivid))
                    drawCircle(palette.ink.copy(alpha = 0.12f), style = Stroke(1f))
                }
            }
        }
    }
}
