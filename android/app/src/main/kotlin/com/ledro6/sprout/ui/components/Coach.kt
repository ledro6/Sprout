package com.ledro6.sprout.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

/**
 * Подсказки экрана: подсвеченное место и пузырь рядом. Сами показываются
 * один раз, в первый запуск после знакомства; дальше — по «?» в шапке.
 */
object Coach {
    var walk: Walk? by mutableStateOf(null)
        private set
    var step by mutableIntStateOf(0)
        private set

    /** Где стоят подсвечиваемые места — в пикселях от угла окна. */
    val spots = mutableStateMapOf<Hint.Target, Rect>()
    val reveal = HashMap<Hint.Target, BringIntoViewRequester>()

    fun offer(walk: Walk, settings: Settings) {
        if (this.walk != null || !settings.toured || !settings.firstRun || settings.seen(walk)) return
        start(walk)
    }

    fun start(walk: Walk) {
        this.walk = walk
        step = 0
    }

    fun next(count: Int, settings: Settings) {
        if (step + 1 >= count) return finish(settings)
        step += 1
        Feel.pick()
    }

    fun drop(walk: Walk) {
        if (this.walk != walk) return
        this.walk = null
        step = 0
    }

    fun finish(settings: Settings) {
        walk?.let { settings.mark(it) }
        walk = null
        step = 0
    }
}

/** Место, которое подсказка подсвечивает. */
@Composable
fun Modifier.hintSpot(target: Hint.Target): Modifier {
    val requester = remember { BringIntoViewRequester() }
    DisposableEffect(target) {
        Coach.reveal[target] = requester
        onDispose {
            if (Coach.reveal[target] === requester) Coach.reveal.remove(target)
            Coach.spots.remove(target)
        }
    }
    return this
        .bringIntoViewRequester(requester)
        .onGloballyPositioned { Coach.spots[target] = it.boundsInRoot() }
}

/** Экран с подсказками: предлагает их, когда экран встал, и забывает, уходя. */
@Composable
fun WalkHost(walk: Walk) {
    val settings = LocalSprout.current.settings
    LaunchedEffect(walk) {
        delay(700)
        Coach.offer(walk, settings)
    }
    DisposableEffect(walk) { onDispose { Coach.drop(walk) } }
}

/** «?» в шапке экрана — показать подсказки снова. */
@Composable
fun WalkButton(walk: Walk) {
    FilledTonalIconButton(onClick = { Coach.start(walk) }) {
        Icon(painterResource(R.drawable.ic_question_mark), contentDescription = Lang.text("Подсказки"))
    }
}

/** Слой подсказок — поверх всего приложения. */
@Composable
fun CoachLayer() {
    val walk = Coach.walk ?: return
    val settings = LocalSprout.current.settings
    val hints = walk.hints.mapNotNull { hint ->
        Coach.spots[hint.target]?.takeIf { it.width > 16 && it.height > 16 }?.let { hint to it }
    }
    if (hints.isEmpty()) {
        LaunchedEffect(walk) {
            delay(300)
            if (walk.hints.none { Coach.spots.containsKey(it.target) }) Coach.drop(walk)
        }
        return
    }
    val step = Coach.step.coerceIn(0, hints.size - 1)
    val (hint, rect) = hints[step]
    LaunchedEffect(hint.target) { Coach.reveal[hint.target]?.bringIntoView() }
    val density = LocalDensity.current
    val reach = with(density) { 8.dp.toPx() }
    val hole = Rect(rect.left - reach, rect.top - reach, rect.right + reach, rect.bottom + reach)
    val radius = minOf(with(density) { (Metrics.CARD_RADIUS + 8).dp.toPx() }, minOf(hole.width, hole.height) / 2)
    val accent = MaterialTheme.colorScheme.primary
    val glow = rememberInfiniteTransition(label = "обводка")
    val lit by glow.animateFloat(0.35f, 0.9f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "обводка")
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .semantics { isTraversalGroup = true }
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                Coach.next(hints.size, settings)
            },
    ) {
        Canvas(Modifier.fillMaxSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            drawRect(Color.Black.copy(alpha = 0.55f))
            drawRoundRect(Color.Transparent, hole.topLeft, hole.size, CornerRadius(radius), blendMode = BlendMode.Clear)
            drawRoundRect(accent.copy(alpha = lit), hole.topLeft, hole.size, CornerRadius(radius), style = Stroke(2.dp.toPx()))
        }
        val height = constraints.maxHeight.toFloat()
        var tall by remember { mutableIntStateOf(with(density) { 230.dp.roundToPx() }) }
        val gap = with(density) { 22.dp.toPx() }
        val floor = with(density) { 96.dp.toPx() }
        val below = height - floor - hole.bottom >= tall + gap
        val above = hole.top - with(density) { 48.dp.toPx() } >= tall + gap
        val y = when {
            below -> hole.bottom + gap
            above -> hole.top - gap - tall
            else -> height - floor - tall
        }
        AnimatedContent(
            hint to step,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "подсказка",
            modifier = Modifier
                .offset { IntOffset(0, y.roundToInt()) }
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) { (shown, index) ->
            Bubble(shown, index, hints.size, settings, Modifier.onSizeChanged { tall = it.height })
        }
    }
}

@Composable
private fun Bubble(hint: Hint, step: Int, count: Int, settings: Settings, modifier: Modifier) {
    val last = step == count - 1
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Surface(
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            shadowElevation = 12.dp,
            modifier = modifier.widthIn(max = 420.dp).fillMaxWidth(),
        ) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    Lang.format("%1\$lld из %2\$lld", step + 1, count),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(hint.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(hint.text, style = MaterialTheme.typography.bodyLarge)
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                    if (!last) TextButton(onClick = { Coach.finish(settings) }) { Text(Lang.text("Пропустить")) }
                    Spacer(Modifier.weight(1f))
                    Button(onClick = { Coach.next(count, settings) }) {
                        Text(if (last) Lang.text("Понятно") else Lang.text("Дальше"))
                    }
                }
            }
        }
    }
}

@Suppress("unused")
private fun Offset.toSize() = Size(x, y)
