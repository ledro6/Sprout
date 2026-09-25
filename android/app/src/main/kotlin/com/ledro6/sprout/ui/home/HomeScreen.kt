package com.ledro6.sprout.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PrimaryScrollableTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.SproutBackground
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Room
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.platform.ArSupport
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.SproutGear
import com.ledro6.sprout.ui.components.enter
import kotlinx.coroutines.launch

/**
 * Главная. Комнаты — страницами: листаются пальцем вбок, у каждой своя
 * прокрутка, за последней — «Новая комната». Сверху — крупный заголовок
 * Material, который сворачивается при прокрутке, и вкладки комнат, идущие за
 * листанием.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(go: Go, outer: PaddingValues) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val settings = sprout.settings
    val rooms = garden.rooms
    val names = rooms.map { it.name }
    var current by rememberSaveable { mutableStateOf(names.firstOrNull()) }
    val pager = rememberPagerState(initialPage = names.indexOf(current).coerceAtLeast(0)) { rooms.size + 1 }
    val scope = rememberCoroutineScope()
    val shelf = remember { ShelfState() }
    val bar = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    var viewMenu by remember { mutableStateOf(false) }

    // Страница держится на комнате, а не на номере: переставили — едет с ней.
    LaunchedEffect(names) {
        val name = current
        val index = names.indexOf(name)
        when {
            index >= 0 && index != pager.currentPage -> pager.scrollToPage(index)
            index < 0 && name != null -> {
                val fallback = pager.currentPage.coerceAtMost(names.size)
                pager.scrollToPage(fallback)
            }
        }
    }
    var turned by remember { mutableIntStateOf(-1) }
    LaunchedEffect(pager.currentPage) {
        val page = pager.currentPage
        current = names.getOrNull(page)
        if (turned >= 0 && turned != page) Feel.turn(if (page == names.size && names.isNotEmpty()) 1.0 else 0.7)
        turned = page
        if (page >= names.size) finish(shelf)
    }

    fun begin() {
        if (shelf.editing) return
        val room = rooms.getOrNull(pager.currentPage) ?: return
        garden.line(settings.order.arrange(room.plants).map { it.id })
        settings.order = Settings.Order.MANUAL
        shelf.editing = true
        Feel.pick()
    }

    val density = LocalDensity.current.density
    val actions = ShelfActions(
        open = { if (!shelf.editing) go.plant(it) },
        menu = { shelf.menu = it },
        begin = { begin() },
        move = { who, spot -> garden.move(who, spot) },
        water = { id ->
            if (sprout.bin.water(id)) {
                Effects.cheer(Cards.rects[id], density)
                Feel.water()
            }
        },
        toss = { id -> sprout.bin.toss(id, Cards.rects[id]) },
    )

    Box(Modifier.fillMaxSize()) {
        SproutBackground()
        val fraction = bar.state.collapsedFraction
        val chrome = lerp(Color.Transparent, MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.96f), fraction)
        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0),
            modifier = Modifier.nestedScroll(bar.nestedScrollConnection),
            topBar = {
                Column(Modifier.background(chrome)) {
                    LargeTopAppBar(
                        title = { Text(Lang.text("Главная"), Modifier.enter(2)) },
                        actions = {
                            Row(Modifier.enter(3), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                                AnimatedVisibility(shelf.editing, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
                                    FilledIconButton(onClick = { finish(shelf) }) {
                                        Icon(painterResource(R.drawable.ic_check), contentDescription = Lang.text("Готово"))
                                    }
                                }
                                Box {
                                    FilledTonalIconButton(onClick = { viewMenu = true }) {
                                        Icon(
                                            painterResource(if (settings.look == Settings.Look.GRID) R.drawable.ic_grid_view else R.drawable.ic_view_list),
                                            contentDescription = Lang.text("Вид и порядок"),
                                        )
                                    }
                                    ViewMenu(viewMenu, { viewMenu = false }, go, rooms.getOrNull(pager.currentPage), shelf)
                                }
                                SproutGear { go.settings() }
                            }
                        },
                        scrollBehavior = bar,
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.Transparent,
                            scrolledContainerColor = Color.Transparent,
                        ),
                    )
                    if (Effects.step >= 3) {
                        PrimaryScrollableTabRow(
                            selectedTabIndex = pager.currentPage.coerceIn(0, rooms.size),
                            containerColor = Color.Transparent,
                            edgePadding = 16.dp,
                            divider = {},
                            modifier = Modifier.enter(3),
                        ) {
                            rooms.forEachIndexed { index, room ->
                                Tab(
                                    selected = pager.currentPage == index,
                                    onClick = { scope.launch { pager.animateScrollToPage(index) } },
                                    text = { Text(room.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                )
                            }
                            Tab(
                                selected = pager.currentPage == rooms.size,
                                onClick = { scope.launch { pager.animateScrollToPage(rooms.size) } },
                                text = { Text(Lang.text("Новая комната")) },
                                icon = { Icon(painterResource(R.drawable.ic_add), contentDescription = null, modifier = Modifier.size(18.dp)) },
                            )
                        }
                    }
                }
            },
        ) { inner ->
            HorizontalPager(
                state = pager,
                userScrollEnabled = !shelf.editing,
                beyondViewportPageCount = 1,
                key = { page -> rooms.getOrNull(page)?.name ?: "\u0000new" },
                modifier = Modifier.fillMaxSize().padding(top = inner.calculateTopPadding()),
            ) { page ->
                val bottom = outer.calculateBottomPadding() + 96.dp
                if (Effects.step < 4) return@HorizontalPager
                val room = rooms.getOrNull(page)
                if (room == null) {
                    NewRoom(go, bottom) { made ->
                        current = made
                        scope.launch {
                            val index = garden.rooms.indexOfFirst { it.name == made }
                            if (index >= 0) pager.animateScrollToPage(index)
                        }
                    }
                } else {
                    RoomPage(room, settings, shelf, actions, bottom, go)
                }
            }
        }
    }
}

private fun finish(shelf: ShelfState) {
    shelf.editing = false
    shelf.dragged = null
}

@Composable
private fun RoomPage(room: Room, settings: Settings, shelf: ShelfState, actions: ShelfActions, bottom: androidx.compose.ui.unit.Dp, go: Go) {
    val plants = settings.order.arrange(room.plants)
    if (plants.isEmpty()) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 48.dp).padding(top = 100.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(painterResource(R.drawable.ic_eco), contentDescription = null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(32.dp))
            Text(
                Lang.text(
                    "В этой комнате пока ничего не растёт. Посадите сюда растение во вкладке «Добавить» " +
                        "или перевезите из другой комнаты.",
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        return
    }
    val grid = rememberLazyGridState()
    Shelf(
        plants = plants,
        look = settings.look,
        state = shelf,
        grid = grid,
        padding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = bottom),
        actions = actions,
    ) { plant -> PlantMenu(plant, shelf, actions, go) }
}

/** Вид и порядок — одним меню, как в «Файлах»; там же «Сад в AR», «Уезжаю…» и комнаты. */
@Composable
private fun ViewMenu(open: Boolean, close: () -> Unit, go: Go, room: Room?, shelf: ShelfState) {
    val sprout = LocalSprout.current
    val settings = sprout.settings
    DropdownMenu(expanded = open, onDismissRequest = close) {
        MenuHeading(Lang.text("Вид"))
        for (look in Settings.Look.entries) {
            DropdownMenuItem(
                text = { Text(look.title) },
                leadingIcon = { Icon(painterResource(if (look == Settings.Look.GRID) R.drawable.ic_grid_view else R.drawable.ic_view_list), null) },
                trailingIcon = { if (settings.look == look) Icon(painterResource(R.drawable.ic_check), null) },
                onClick = {
                    settings.look = look
                    shelf.revealed.clear()
                    close()
                },
            )
        }
        HorizontalDivider()
        MenuHeading(Lang.text("Порядок"))
        for (order in Settings.Order.entries) {
            DropdownMenuItem(
                text = { Text(order.title) },
                leadingIcon = { Icon(painterResource(order.icon()), null) },
                trailingIcon = { if (settings.order == order) Icon(painterResource(R.drawable.ic_check), null) },
                onClick = {
                    settings.order = order
                    if (order != Settings.Order.MANUAL) finish(shelf)
                    close()
                },
            )
        }
        HorizontalDivider()
        val plants = room?.plants.orEmpty()
        if (ArSupport.available && plants.isNotEmpty()) {
            DropdownMenuItem(
                text = { Text(Lang.text("Сад в AR")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_view_in_ar), null) },
                onClick = {
                    close()
                    go.ar(plants.sortedBy { it.moisture }.map { it.id })
                },
            )
        }
        DropdownMenuItem(
            text = { Text(Lang.text("Уезжаю…")) },
            leadingIcon = { Icon(painterResource(R.drawable.ic_flight_takeoff), null) },
            onClick = {
                close()
                go.trip()
            },
        )
        DropdownMenuItem(
            text = { Text(Lang.text("Изменить комнаты…")) },
            leadingIcon = { Icon(painterResource(R.drawable.ic_edit), null) },
            onClick = {
                close()
                go.rooms()
            },
        )
    }
}

@Composable
fun MenuHeading(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
    )
}

fun Settings.Order.icon(): Int = when (this) {
    Settings.Order.MANUAL -> R.drawable.ic_draw
    Settings.Order.THIRSTY -> R.drawable.ic_water_drop
    Settings.Order.NAME -> R.drawable.ic_sort_by_alpha
    Settings.Order.NEWEST -> R.drawable.ic_calendar_month
}
