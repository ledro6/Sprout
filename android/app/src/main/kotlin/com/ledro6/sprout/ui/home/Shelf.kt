package com.ledro6.sprout.ui.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.ledro6.sprout.R
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.components.CardShape
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.PlantPhoto
import com.ledro6.sprout.ui.components.plantGlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.sin

/** Где стоят карточки — для волны полива и тления: они идут от карточки. */
object Cards {
    val rects = HashMap<String, Rect>()
}

/**
 * Полка качается, как значки на рабочем столе: подержал карточку — меню,
 * держишь дальше или повёл пальцем — карточки закачались, и их можно
 * переставить. Кого тащат — один на всю полку.
 */
class ShelfState {
    var editing by mutableStateOf(false)
    var dragged: String? by mutableStateOf(null)
    var delta by mutableStateOf(Offset.Zero)
    var start = Offset.Zero
    var menu: String? by mutableStateOf(null)
    val revealed = HashSet<String>()
}

/** Что делает полка с растениями — снаружи: сад и переходы знает экран. */
class ShelfActions(
    val open: (String) -> Unit,
    val menu: (String) -> Unit,
    val begin: () -> Unit,
    val move: (String, String) -> Unit,
    val water: (String) -> Unit,
    val toss: (String) -> Unit,
)

@Composable
fun Shelf(
    plants: List<Plant>,
    look: Settings.Look,
    state: ShelfState,
    grid: LazyGridState,
    padding: PaddingValues,
    actions: ShelfActions,
    menu: @Composable (Plant) -> Unit,
) {
    val jiggle = rememberInfiniteTransition(label = "качание")
    val swing by jiggle.animateFloat(0f, 1f, infiniteRepeatable(tween((Motion.JIGGLE_PERIOD * 1000).toInt(), easing = LinearEasing)), label = "качание")
    val amplitude by animateFloatAsState(if (state.editing && look == Settings.Look.GRID) 1f else 0f, tween(250), label = "размах")
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    // Тащат к краю — полка едет сама.
    LaunchedEffect(state.dragged) {
        while (state.dragged != null) {
            val info = grid.layoutInfo
            val mine = info.visibleItemsInfo.firstOrNull { it.key == state.dragged }
            if (mine != null) {
                val y = state.start.y + state.delta.y + mine.size.height / 2f
                val top = info.viewportStartOffset + 80f
                val bottom = info.viewportEndOffset - 160f
                val push = when {
                    y < top -> -(top - y).coerceAtMost(120f) / 6
                    y > bottom -> (y - bottom).coerceAtMost(120f) / 6
                    else -> 0f
                }
                if (push != 0f) grid.scrollBy(push)
            }
            delay(16)
        }
    }

    LazyVerticalGrid(
        // На телефоне — две карточки в ряд, на планшете и раскрытом складном — сколько влезет.
        columns = if (look == Settings.Look.GRID) GridCells.Adaptive(150.dp) else GridCells.Adaptive(360.dp),
        state = grid,
        contentPadding = padding,
        horizontalArrangement = Arrangement.spacedBy(if (look == Settings.Look.GRID) 18.dp else 0.dp),
        verticalArrangement = Arrangement.spacedBy(if (look == Settings.Look.GRID) 20.dp else 12.dp),
        modifier = Modifier,
    ) {
        items(plants, key = { it.id }) { plant ->
            val index = plants.indexOf(plant)
            val appear = remember(plant.id) { Animatable(if (plant.id in state.revealed || Effects.still) 1f else 0f) }
            LaunchedEffect(plant.id) {
                if (appear.value < 1f) {
                    state.revealed.add(plant.id)
                    delay((index.coerceAtMost(12) * Motion.STAGGER * 1000).toLong())
                    appear.animateTo(1f, Motion.appear)
                }
            }
            val dragging = state.dragged == plant.id
            val ghost by animateFloatAsState(if (dragging) 0.92f else 1f, label = "подъём")
            Box(
                Modifier
                    .zIndex(if (dragging) 1f else 0f)
                    .animateItem(fadeInSpec = null, fadeOutSpec = null)
                    .graphicsLayer {
                        val shown = appear.value
                        alpha = shown
                        val rise = (1 - shown)
                        scaleX = (1 - 0.1f * rise) * (if (dragging) 1.04f else 1f)
                        scaleY = scaleX
                        translationY = Motion.ENTER_RISE * density * rise
                        if (dragging) {
                            val now = grid.layoutInfo.visibleItemsInfo.firstOrNull { it.key == plant.id }
                            if (now != null) {
                                translationX = state.start.x + state.delta.x - now.offset.x
                                translationY = state.start.y + state.delta.y - now.offset.y
                            }
                        }
                        val phase = plant.pulsePhase.toFloat()
                        rotationZ = amplitude * Motion.JIGGLE_ANGLE * sin(2 * PI.toFloat() * (swing + phase))
                    }
                    .onGloballyPositioned { Cards.rects[plant.id] = it.boundsInRoot() },
            ) {
                PlantTile(plant, look, state, grid, actions, ghost)
                if (state.menu == plant.id) menu(plant)
            }
        }
    }
}

/** Карточка с жестами: нажатие, удержание, перетаскивание. */
@Composable
private fun PlantTile(
    plant: Plant,
    look: Settings.Look,
    state: ShelfState,
    grid: LazyGridState,
    actions: ShelfActions,
    alpha: Float,
) {
    val source = remember { MutableInteractionSource() }
    val act by rememberUpdatedState(actions)
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val gestures = Modifier.pointerInput(plant.id) {
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false)
            val press = PressInteraction.Press(down.position)
            scope.launch { source.emit(press) }
            // До удержания: отпустили — нажатие; повели — это прокрутка.
            var outcome = 0
            val timeout = viewConfiguration.longPressTimeoutMillis
            val quick = withTimeoutOrNull(timeout) {
                while (true) {
                    val event = awaitPointerEvent()
                    val change = event.changes.firstOrNull { it.id == down.id } ?: return@withTimeoutOrNull 2
                    if (!change.pressed) return@withTimeoutOrNull 1
                    if ((change.position - down.position).getDistance() > viewConfiguration.touchSlop) return@withTimeoutOrNull 2
                }
                @Suppress("UNREACHABLE_CODE") 0
            }
            outcome = quick ?: 3
            if (outcome != 3) {
                scope.launch { source.emit(PressInteraction.Release(press)) }
                if (outcome == 1 && !state.editing) act.open(plant.id)
                return@awaitEachGesture
            }
            // Удержали.
            scope.launch { source.emit(PressInteraction.Release(press)) }
            var dragging = false
            if (state.editing) {
                dragging = true
            } else {
                Feel.pick()
                act.menu(plant.id)
                val held = withTimeoutOrNull((Motion.HOLD_TO_ARRANGE * 1000).toLong()) {
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: return@withTimeoutOrNull false
                        if (!change.pressed) return@withTimeoutOrNull false
                        if ((change.position - down.position).getDistance() > viewConfiguration.touchSlop) return@withTimeoutOrNull true
                    }
                    @Suppress("UNREACHABLE_CODE") false
                }
                if (held == false) return@awaitEachGesture
                // Держат дольше меню или повели — меню уходит, полка качается.
                state.menu = null
                act.begin()
                dragging = true
            }
            if (!dragging) return@awaitEachGesture
            val mine = grid.layoutInfo.visibleItemsInfo.firstOrNull { it.key == plant.id } ?: return@awaitEachGesture
            state.start = Offset(mine.offset.x.toFloat(), mine.offset.y.toFloat())
            state.delta = Offset.Zero
            state.dragged = plant.id
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                if (!change.pressed) break
                val step = change.positionChange()
                change.consume()
                if (step != Offset.Zero) {
                    state.delta += step
                    swapUnder(plant.id, state, grid, act)
                }
            }
            state.dragged = null
            state.delta = Offset.Zero
        }
    }
    val body = Modifier
        .clip(CardShape)
        .indication(source, ripple())
        .then(gestures)
        .semantics {
            onClick(Lang.text("Открыть")) {
                if (!state.editing) act.open(plant.id)
                true
            }
            onLongClick(Lang.text("Действия")) {
                act.menu(plant.id)
                true
            }
            customActions = listOf(
                CustomAccessibilityAction(Lang.text("Полить сейчас")) { act.water(plant.id); true },
                CustomAccessibilityAction(Lang.text("Удалить")) { act.toss(plant.id); true },
            )
        }
    Box(Modifier.graphicsLayer { this.alpha = alpha }) {
        when (look) {
            Settings.Look.GRID -> PlantCard(plant, body)
            Settings.Look.LIST -> PlantRow(plant, state.editing, body)
        }
    }
}

/** Под пальцем другая карточка — тащимая встаёт на её место. */
private fun swapUnder(id: String, state: ShelfState, grid: LazyGridState, actions: ShelfActions) {
    val info = grid.layoutInfo.visibleItemsInfo
    val mine = info.firstOrNull { it.key == id } ?: return
    val centre = state.start + state.delta + Offset(mine.size.width / 2f, mine.size.height / 2f)
    val target = info.firstOrNull { item ->
        item.key != id && item.key is String &&
            centre.x >= item.offset.x && centre.x <= item.offset.x + item.size.width &&
            centre.y >= item.offset.y && centre.y <= item.offset.y + item.size.height
    } ?: return
    actions.move(id, target.key as String)
}

/** Карточка плиткой: снимок, кличка с процентом и срок полива. */
@Composable
fun PlantCard(plant: Plant, modifier: Modifier = Modifier) {
    Plate(modifier.plantGlow(plant)) {
        Column(Modifier.padding(horizontal = Metrics.CARD_PADDING.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            PlantPhoto(plant, Modifier.fillMaxWidth().aspectRatio(1f))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    plant.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(4.dp))
                Text(plant.moistureLabel, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Medium)
            }
            Text(
                plant.wateringLabel,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** Строкой: вдвое плотнее; в правке — ручка справа. */
@Composable
fun PlantRow(plant: Plant, editing: Boolean, modifier: Modifier = Modifier) {
    Plate(modifier.plantGlow(plant)) {
        Row(
            Modifier.padding(start = 10.dp, top = 10.dp, bottom = 10.dp, end = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PlantPhoto(plant, Modifier.size(60.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(plant.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(plant.wateringLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            Text(plant.moistureLabel, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Medium)
            if (editing) {
                Icon(painterResource(R.drawable.ic_drag_handle), contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
