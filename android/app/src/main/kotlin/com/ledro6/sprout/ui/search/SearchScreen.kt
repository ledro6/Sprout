package com.ledro6.sprout.ui.search

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.RowShape
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.TabScreen
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.home.Cards
import com.ledro6.sprout.ui.home.PlantMenu
import com.ledro6.sprout.ui.home.Shelf
import com.ledro6.sprout.ui.home.ShelfActions
import com.ledro6.sprout.ui.home.ShelfState

/**
 * Поиск по кличке и виду. Пока строка пуста — недавние запросы; запрос
 * запоминается, когда им воспользовались: открыли растение или нажали «Найти».
 */
@Composable
fun SearchScreen(go: Go, outer: PaddingValues) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val settings = sprout.settings
    val recents = sprout.recents
    val focus = LocalFocusManager.current
    val density = LocalDensity.current.density
    var query by rememberSaveable { mutableStateOf("") }
    val asked = query.trim()
    val shelf = remember { ShelfState() }
    val grid = rememberLazyGridState()
    val bottom = outer.calculateBottomPadding() + 28.dp

    val actions = ShelfActions(
        open = { id ->
            recents.remember(asked)
            go.plant(id)
        },
        menu = { shelf.menu = it },
        begin = {},
        move = { _, _ -> },
        water = { id ->
            if (sprout.bin.water(id)) {
                Effects.cheer(Cards.rects[id], density)
                Feel.water()
            }
        },
        toss = { id -> sprout.bin.toss(id, Cards.rects[id]) },
    )

    TabScreen(Lang.text("Поиск"), Walk.SEARCH, onSettings = go::settings) { inner ->
        Column(Modifier.fillMaxSize().padding(top = inner.calculateTopPadding())) {
            TextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                placeholder = { Text(Lang.text("Найти растение")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_search), null) },
                trailingIcon = {
                    if (query.isNotEmpty()) {
                        IconButton(onClick = { query = "" }) {
                            Icon(painterResource(R.drawable.ic_close), Lang.text("Очистить"))
                        }
                    }
                },
                singleLine = true,
                shape = CircleShape,
                colors = TextFieldDefaults.colors(
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = {
                    recents.remember(asked)
                    focus.clearFocus()
                }),
            )
            val results = if (asked.isEmpty()) emptyList() else settings.order.arrange(garden.search(asked))
            Box(Modifier.weight(1f).fillMaxWidth().hintSpot(Hint.Target.SEARCH_BOARD)) {
                when {
                    asked.isEmpty() && recents.queries.isEmpty() ->
                        Blank(Lang.text("Найдётся по кличке или по виду — «Баксик», «Монстера»."), R.drawable.ic_search)
                    asked.isEmpty() -> History(bottom) { past ->
                        query = past
                        recents.remember(past)
                    }
                    results.isEmpty() ->
                        Blank(Lang.format("По запросу «%@» в квартире ничего не растёт.", asked), R.drawable.ic_eco)
                    else -> Shelf(
                        plants = results,
                        look = settings.look,
                        state = shelf,
                        grid = grid,
                        padding = PaddingValues(start = 16.dp, end = 16.dp, top = 14.dp, bottom = bottom),
                        actions = actions,
                    ) { plant -> PlantMenu(plant, shelf, actions, go) }
                }
            }
        }
    }
}

@Composable
private fun Blank(text: String, icon: Int) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 48.dp).padding(top = 120.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(painterResource(icon), null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(30.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun History(bottom: androidx.compose.ui.unit.Dp, again: (String) -> Unit) {
    val recents = LocalSprout.current.recents
    var doomed by remember { mutableStateOf<String?>(null) }
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(top = 8.dp, bottom = bottom),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SproutGroup(Lang.text("Недавно искали"), Modifier.hintSpot(Hint.Target.SEARCH_RECENTS)) {
            recents.queries.forEachIndexed { index, past ->
                if (index > 0) SproutDivider()
                Box {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RowShape)
                            .combinedClickable(onClick = { again(past) }, onLongClick = { doomed = past; Feel.pick() })
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(painterResource(R.drawable.ic_history), null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
                        Text(past, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                        Icon(painterResource(R.drawable.ic_north_west), null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(20.dp))
                    }
                    DropdownMenu(expanded = doomed == past, onDismissRequest = { doomed = null }) {
                        DropdownMenuItem(
                            { Text(Lang.text("Забыть")) },
                            {
                                doomed = null
                                recents.forget(past)
                            },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_close), null) },
                        )
                    }
                }
            }
        }
        FilledTonalButton(onClick = { recents.clear() }) { Text(Lang.text("Очистить")) }
    }
}
