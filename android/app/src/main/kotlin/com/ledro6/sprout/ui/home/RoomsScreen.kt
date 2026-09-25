package com.ledro6.sprout.ui.home

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Room
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.hintSpot
import kotlinx.coroutines.launch

/**
 * Комнаты: имя правится прямо в строке, порядок — за ручку справа, удалить —
 * смахнуть влево. Комнату с растениями удаляют только после вопроса.
 */
@Composable
fun RoomsScreen(go: Go) {
    val garden = LocalSprout.current.garden
    var naming by remember { mutableStateOf(false) }
    var doomed by remember { mutableStateOf<Room?>(null) }
    val list = rememberLazyListState()
    var dragged by remember { mutableStateOf<String?>(null) }
    var drift by remember { mutableFloatStateOf(0f) }

    SubScreen(
        title = Lang.text("Комнаты"),
        onBack = go::back,
        walk = Walk.ROOMS,
        large = true,
        actions = {
            IconButton(onClick = { naming = true }) {
                Icon(painterResource(R.drawable.ic_add), contentDescription = Lang.text("Новая комната"))
            }
        },
    ) { inner ->
        if (garden.rooms.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(inner).padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(painterResource(R.drawable.ic_home), null, Modifier.size(40.dp), tint = MaterialTheme.colorScheme.outline)
                Text(Lang.text("Комнат нет"), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp))
                Text(
                    Lang.text("Нажмите «+», чтобы завести первую."),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            return@SubScreen
        }
        LazyColumn(
            state = list,
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = inner.calculateTopPadding() + 4.dp, bottom = inner.calculateBottomPadding() + 40.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize().hintSpot(Hint.Target.ROOMS_LIST),
        ) {
            itemsIndexed(garden.rooms, key = { _, room -> room.name }) { index, room ->
                val moving = dragged == room.name
                Box(
                    Modifier
                        .zIndex(if (moving) 1f else 0f)
                        .animateItem()
                        .graphicsLayer { if (moving) translationY = drift },
                ) {
                    RoomRow(
                        room = room,
                        ask = { doomed = it },
                        grip = Modifier.pointerInput(room.name) {
                            detectDragGestures(
                                onDragStart = {
                                    dragged = room.name
                                    drift = 0f
                                    Feel.pick()
                                },
                                onDragEnd = { dragged = null; drift = 0f },
                                onDragCancel = { dragged = null; drift = 0f },
                            ) { change, amount ->
                                change.consume()
                                drift += amount.y
                                drift = reorder(room.name, drift, list, garden::moveRoom, garden.rooms)
                            }
                        },
                    )
                }
            }
            item {
                Text(
                    Lang.text(
                        "Имя правится прямо в строке. Потяните за ручку справа, чтобы поменять порядок, — " +
                            "в том же порядке комнаты листаются на главной.",
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                )
            }
        }
    }

    if (naming) {
        Ask(
            title = Lang.text("Новая комната"),
            message = Lang.text("Растения в неё можно будет посадить или перевезти."),
            hint = Lang.text("Балкон"),
            start = "",
            confirm = Lang.text("Завести"),
        ) { name ->
            naming = false
            if (name != null && !garden.addRoom(name)) Feel.wrong()
        }
    }
    doomed?.let { room ->
        AlertDialog(
            onDismissRequest = { doomed = null },
            title = { Text(Lang.format("Удалить комнату «%@»?", room.name)) },
            text = { Text(Lang.format("Вместе с ней уйдут %lld растений. Вернуть их будет нельзя.", room.plants.size)) },
            confirmButton = {
                TextButton(onClick = {
                    garden.deleteRoom(room.name)
                    doomed = null
                    Feel.toss()
                }) { Text(Lang.text("Удалить"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { doomed = null }) { Text(Lang.text("Отмена")) } },
        )
    }
}

/** Ведут строку — встаёт на место соседа, над которым её держат. */
private fun reorder(name: String, drift: Float, list: LazyListState, move: (Int, Int) -> Unit, rooms: List<Room>): Float {
    val info = list.layoutInfo.visibleItemsInfo
    val mine = info.firstOrNull { it.key == name } ?: return drift
    val centre = mine.offset + drift + mine.size / 2f
    val target = info.firstOrNull { it.key != name && it.key is String && centre > it.offset && centre < it.offset + it.size }
        ?: return drift
    val from = rooms.indexOfFirst { it.name == name }
    val to = rooms.indexOfFirst { it.name == target.key }
    if (from < 0 || to < 0) return drift
    move(from, to)
    Feel.pick()
    // Строка встала на новое место — сдвиг считается уже от него.
    return drift - (target.offset - mine.offset)
}

// `grip` — жест для ручки справа, а не оформление всей строки.
@Suppress("ModifierParameter")
@Composable
private fun RoomRow(room: Room, ask: (Room) -> Unit, grip: Modifier) {
    val garden = LocalSprout.current.garden
    val swipe = rememberSwipeToDismissBoxState()
    val scope = rememberCoroutineScope()
    SwipeToDismissBox(
        state = swipe,
        enableDismissFromStartToEnd = false,
        // Смахнули — спрашиваем или удаляем пустую; строка возвращается на место.
        onDismiss = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                if (room.plants.isEmpty()) garden.deleteRoom(room.name) else ask(room)
            }
            scope.launch { swipe.reset() }
        },
        backgroundContent = {
            Row(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                Icon(painterResource(R.drawable.ic_delete), contentDescription = Lang.text("Удалить"), tint = MaterialTheme.colorScheme.error)
            }
        },
    ) {
        Plate(Modifier.fillMaxWidth()) {
            var draft by remember(room.name) { mutableStateOf(room.name) }
            val focus = LocalFocusManager.current
            fun commit() {
                if (draft == room.name) return
                if (!garden.renameRoom(room.name, draft)) {
                    draft = room.name
                    Feel.wrong()
                }
            }
            Row(
                Modifier.padding(start = 16.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                    cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = {
                        commit()
                        focus.clearFocus()
                    }),
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = 12.dp)
                        .onFocusChanged { if (!it.isFocused) commit() },
                )
                Text(
                    Lang.format("%lld растений", room.plants.size),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Box(grip.padding(12.dp)) {
                    Icon(painterResource(R.drawable.ic_drag_handle), contentDescription = Lang.text("Переставить"), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
