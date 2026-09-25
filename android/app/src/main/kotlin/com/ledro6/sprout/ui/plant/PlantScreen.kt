package com.ledro6.sprout.ui.plant

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.model.Diary
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Rhythm
import com.ledro6.sprout.model.Season
import com.ledro6.sprout.model.Species
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.model.Watering
import com.ledro6.sprout.platform.ArSupport
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.CardShape
import com.ledro6.sprout.ui.components.Coach
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.PlantPhoto
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermHint
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.components.plantGlow
import com.ledro6.sprout.ui.home.Ask

/** Экран растения: снимок, полив, модель и AR, уход, заметки и поливы. */
@Composable
fun PlantScreen(id: String, go: Go) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val plant = garden.plant(id)
    val density = LocalDensity.current.density
    var spot by remember { mutableStateOf<Rect?>(null) }
    var menu by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf(false) }
    var moving by remember { mutableStateOf(false) }
    var asking by remember { mutableStateOf(false) }

    // Растение удалили — экран закрывается сам; вернуть можно с плашки.
    var seen by remember { mutableStateOf(false) }
    LaunchedEffect(plant == null) {
        if (plant == null && seen) go.back()
        if (plant != null) seen = true
    }
    if (plant == null) {
        SubScreen("", onBack = go::back) {}
        return
    }

    fun water() {
        if (!sprout.bin.water(id)) return
        Effects.cheer(spot, density)
        Feel.water()
    }

    SubScreen(
        title = plant.name,
        onBack = go::back,
        actions = {
            Box {
                IconButton(onClick = { menu = true }) {
                    Icon(painterResource(R.drawable.ic_more_vert), contentDescription = Lang.text("Действия"))
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false; moving = false }) {
                    if (!moving) {
                        DropdownMenuItem({ Text(Lang.text("Переименовать")) }, { menu = false; renaming = true }, leadingIcon = { Icon(painterResource(R.drawable.ic_edit), null) })
                        DropdownMenuItem({ Text(Lang.text("Настройки")) }, { menu = false; go.tune(id) }, leadingIcon = { Icon(painterResource(R.drawable.ic_tune), null) })
                        DropdownMenuItem({ Text(Lang.text("Подсказки")) }, { menu = false; Coach.start(Walk.PLANT) }, leadingIcon = { Icon(painterResource(R.drawable.ic_help), null) })
                        DropdownMenuItem(
                            { Text(Lang.text("Переехать")) }, { moving = true },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_door_open), null) },
                            trailingIcon = { Icon(painterResource(R.drawable.ic_chevron_right), null) },
                        )
                        HorizontalDivider()
                        DropdownMenuItem(
                            { Text(Lang.text("Удалить"), color = MaterialTheme.colorScheme.error) },
                            {
                                menu = false
                                sprout.bin.toss(id, spot)
                            },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_delete), null, tint = MaterialTheme.colorScheme.error) },
                        )
                    } else {
                        val here = garden.roomName(id)
                        DropdownMenuItem({ Text(Lang.text("Переехать")) }, { moving = false }, leadingIcon = { Icon(painterResource(R.drawable.ic_arrow_back), null) })
                        HorizontalDivider()
                        for (room in garden.rooms.map { it.name }.filter { it != here }) {
                            DropdownMenuItem({ Text(room) }, { menu = false; moving = false; garden.relocate(id, room) })
                        }
                        DropdownMenuItem(
                            { Text(Lang.text("Новая комната…")) }, { menu = false; moving = false; asking = true },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_add), null) },
                        )
                    }
                }
            }
        },
    ) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 24.dp)
                .padding(top = 8.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Plate(
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(336f / 347f)
                    .plantGlow(plant)
                    .hintSpot(Hint.Target.PLANT_PHOTO)
                    .onGloballyPositioned { spot = it.boundsInRoot() },
            ) {
                PlantPhoto(plant, Modifier.fillMaxSize().padding(vertical = 6.dp), radius = 20.dp)
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = { water() },
                    modifier = Modifier.fillMaxWidth().height(60.dp).hintSpot(Hint.Target.PLANT_POUR),
                ) {
                    Icon(painterResource(R.drawable.ic_water_drop_fill), null, Modifier.size(22.dp))
                    Text(Lang.text("Полить сейчас"), Modifier.padding(start = 8.dp), style = MaterialTheme.typography.titleMedium)
                }
                Row(Modifier.hintSpot(Hint.Target.PLANT_TOOLS), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (ArSupport.available) {
                        Tool(Lang.text("В AR"), R.drawable.ic_view_in_ar) { go.ar(listOf(id)) }
                    }
                    Tool(Lang.text("Модель"), R.drawable.ic_deployed_code) { go.model(id) }
                    Tool(Lang.text("Настройки"), R.drawable.ic_tune) { go.tune(id) }
                }
            }
            Rhythm.suggest(plant, garden.log)?.let { days -> RhythmCard(plant, days) }
            CareCard(plant)
            Facts(plant)
            Notes(plant)
            DiaryCard(plant)
        }
    }
    if (renaming) {
        Ask(Lang.text("Переименовать"), Lang.text("Как теперь зовут растение?"), Lang.text("Кличка"), plant.name, Lang.text("Сохранить")) { name ->
            renaming = false
            if (name != null) garden.rename(id, name)
        }
    }
    if (asking) {
        Ask(Lang.text("Новая комната"), Lang.text("Растение переедет туда, и комната появится в списке."), Lang.text("Балкон"), "", Lang.text("Переехать")) { name ->
            asking = false
            if (name != null) garden.relocate(id, name)
        }
    }
    com.ledro6.sprout.ui.components.WalkHost(Walk.PLANT)
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.Tool(title: String, icon: Int, action: () -> Unit) {
    FilledTonalButton(
        onClick = action,
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.weight(1f).height(72.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(4.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(painterResource(icon), null)
            Text(title, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** Плашка экрана растения — с полями побольше, как на iPhone. */
@Composable
private fun Card(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Plate(modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

@Composable
private fun Heading(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun RhythmCard(plant: Plant, days: Double) {
    val garden = LocalSprout.current.garden
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(painterResource(R.drawable.ic_event_repeat), null, tint = MaterialTheme.colorScheme.primary)
            Text(Lang.text("Поливаете раньше срока"), Modifier.padding(start = 8.dp).weight(1f, fill = false), style = MaterialTheme.typography.titleMedium)
            TermHint(Term.RHYTHM)
        }
        Text(
            Lang.format("Похоже, земля сохнет быстрее: %1\$@ вместо %2\$@.", Species.periodPhrase(days), Species.periodPhrase(plant.dryingDays)),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                onClick = {
                    garden.tune(plant.id, plant.name, plant.species, days)
                    Feel.done()
                },
                modifier = Modifier.weight(1f),
            ) { Text(Lang.text("Поменять срок")) }
            OutlinedButton(onClick = { garden.quiet(plant.id, days) }, modifier = Modifier.weight(1f)) { Text(Lang.text("Оставить")) }
        }
    }
}

@Composable
private fun CareCard(plant: Plant) {
    val garden = LocalSprout.current.garden
    val tending = plant.tending
    if (tending.feedEvery == null && tending.repotEvery == null) return
    Card {
        Heading(Lang.text("Уход"))
        tending.feedLabel?.let { line ->
            Chore(line, tending.feedDue, Lang.text("Подкормил"), R.drawable.ic_auto_awesome, Term.FEEDING) { garden.feed(plant.id) }
        }
        tending.repotLabel?.let { line ->
            Chore(line, tending.repotDue, Lang.text("Пересадил"), R.drawable.ic_potted_plant, Term.REPOTTING) { garden.repot(plant.id) }
        }
    }
}

@Composable
private fun Chore(line: String, due: Boolean, done: String, icon: Int, term: Term, action: () -> Unit) {
    Layout({
        Hinted(term) {
            Text(
                line,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = if (due) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
        }
        FilledTonalButton(
            onClick = {
                action()
                Feel.done()
            },
            contentPadding = ButtonDefaults.ButtonWithIconContentPadding,
        ) {
            Icon(painterResource(icon), null, Modifier.size(ButtonDefaults.IconSize))
            Text(done, Modifier.padding(start = ButtonDefaults.IconSpacing), maxLines = 1)
        }
    }) { (label, press), limits ->
        val button = press.measure(limits.copy(minWidth = 0))
        val gap = 12.dp.roundToPx()
        val room = limits.maxWidth - button.width - gap
        // Кнопка справа, если текст с «?» влезает рядом одной строкой; иначе
        // (крупный шрифт, длинный язык) — под текстом, а не сжимая его в столбик.
        if (label.maxIntrinsicWidth(limits.maxHeight) <= room) {
            val text = label.measure(limits.copy(minWidth = 0, maxWidth = room))
            val height = maxOf(text.height, button.height)
            layout(limits.maxWidth, height) {
                text.placeRelative(0, (height - text.height) / 2)
                button.placeRelative(limits.maxWidth - button.width, (height - button.height) / 2)
            }
        } else {
            val text = label.measure(limits.copy(minWidth = 0))
            layout(limits.maxWidth, text.height + gap / 2 + button.height) {
                text.placeRelative(0, 0)
                button.placeRelative(0, text.height + gap / 2)
            }
        }
    }
}

/**
 * Текст и «?» сразу за ним — шириной по тексту, а не по строке. Длинный
 * текст переносится, но «?» не выдавливает.
 */
@Composable
private fun Hinted(term: Term, text: @Composable () -> Unit) {
    Layout({ text(); TermHint(term) }) { (words, mark), limits ->
        val hint = mark.measure(limits.copy(minWidth = 0))
        // При замере «сколько нужно в одну строку» ширина бесконечна — её не уменьшить.
        val rest = if (limits.hasBoundedWidth) (limits.maxWidth - hint.width).coerceAtLeast(0) else Constraints.Infinity
        val body = words.measure(limits.copy(minWidth = 0, maxWidth = rest))
        val height = maxOf(body.height, hint.height)
        layout(body.width + hint.width, height) {
            body.placeRelative(0, (height - body.height) / 2)
            hint.placeRelative(body.width, (height - hint.height) / 2)
        }
    }
}

@Composable
private fun Facts(plant: Plant) {
    val garden = LocalSprout.current.garden
    Card {
        Fact(Lang.format("Влажность %@", plant.moistureLabel), Term.MOISTURE)
        Fact(plant.species)
        Fact(plant.wateringLabel, Term.PERIOD)
        garden.roomName(plant.id)?.let { Fact(Lang.format("Комната «%@»", it)) }
        Season.line(Season.stretch)?.let { Fact(it) }
        Fact(plant.addedLabel)
    }
}

@Composable
private fun Fact(text: String, term: Term? = null) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("•  $text", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f, fill = false))
        if (term != null) TermHint(term)
    }
}

@Composable
private fun Notes(plant: Plant) {
    val garden = LocalSprout.current.garden
    var draft by remember(plant.id) { mutableStateOf(plant.note.orEmpty()) }
    val latest by rememberUpdatedState(draft)
    fun keep(text: String) {
        val before = garden.plant(plant.id)?.note
        garden.note(plant.id, text)
        val after = garden.plant(plant.id)?.note
        if (after != before) Feel.done()
    }
    // Ушли с экрана, не отпустив поле, — заметка всё равно сохраняется.
    DisposableEffect(plant.id) { onDispose { keep(latest) } }
    Card(Modifier.hintSpot(Hint.Target.PLANT_NOTES)) {
        Heading(Lang.text("Заметки"))
        Box {
            if (draft.isEmpty()) {
                Text(Lang.text("Пересадка, удобрения, где любит стоять…"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.outline)
            }
            BasicTextField(
                value = draft,
                onValueChange = { draft = it },
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                maxLines = 12,
                modifier = Modifier.fillMaxWidth().onFocusChanged { if (!it.isFocused) keep(draft) },
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DiaryCard(plant: Plant) {
    val garden = LocalSprout.current.garden
    val palette = LocalPalette.current
    val diary = Diary.of(garden.log, plant.id)
    var doomed by remember { mutableStateOf<Long?>(null) }
    Card(Modifier.hintSpot(Hint.Target.PLANT_DIARY)) {
        Heading(Lang.text("Поливы"))
        if (diary.entries.isEmpty()) {
            Text(Lang.text("Поливов ещё не было."), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            return@Card
        }
        Row(horizontalArrangement = Arrangement.spacedBy(28.dp)) {
            Figure("${diary.total}", Lang.text("Всего"))
            diary.average?.let { Figure(Diary.rhythm(it), Lang.text("В среднем")) }
        }
        val now = System.currentTimeMillis()
        for (moment in diary.entries.take(Diary.SHOWN)) {
            Box {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .combinedClickable(onClick = {}, onLongClick = { doomed = moment; Feel.pick() })
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(painterResource(R.drawable.ic_water_drop_fill), null, tint = palette.water, modifier = Modifier.size(16.dp))
                    Text(Diary.label(moment, now, com.ledro6.sprout.model.Days.current), style = MaterialTheme.typography.bodyLarge)
                }
                DropdownMenu(expanded = doomed == moment, onDismissRequest = { doomed = null }) {
                    DropdownMenuItem(
                        text = { Text(Lang.text("Удалить запись"), color = MaterialTheme.colorScheme.error) },
                        leadingIcon = { Icon(painterResource(R.drawable.ic_delete), null, tint = MaterialTheme.colorScheme.error) },
                        onClick = {
                            doomed = null
                            garden.forget(Watering(plant.id, moment))
                            Feel.toss()
                        },
                    )
                }
            }
        }
        Text(Lang.text("Ошибочную запись удалит долгое нажатие."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun Figure(value: String, caption: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
        Text(caption, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Suppress("unused")
private val shape = CardShape
