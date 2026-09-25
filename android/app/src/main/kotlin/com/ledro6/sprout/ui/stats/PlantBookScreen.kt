package com.ledro6.sprout.ui.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.model.Days
import com.ledro6.sprout.model.Diary
import com.ledro6.sprout.model.Garden
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.PlantBook
import com.ledro6.sprout.model.Rhythm
import com.ledro6.sprout.model.Species
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.PlantPhoto
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.hintSpot
import kotlinx.coroutines.delay

/** Статистика одного растения: цифры, когда поливают, история и следующие поливы. */
@Composable
fun PlantBookScreen(id: String, go: Go) {
    val garden = LocalSprout.current.garden
    val period = StatsPeriod.period
    val plant = garden.plant(id)
    val first = remember { plant?.let { read(it, garden, period) } ?: PlantBook() }
    val book by produceState(first, id, period, garden.log, garden.roster) {
        while (true) {
            garden.plant(id)?.let { value = read(it, garden, period) }
            delay(3_000)
        }
    }
    SubScreen(plant?.name.orEmpty(), onBack = go::back, walk = Walk.BOOK) { inner ->
        if (plant == null) return@SubScreen
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Header(plant, garden)
            Figures(book, Modifier.hintSpot(Hint.Target.BOOK_FIGURES))
            Aim(book.aim, Lang.text("Когда поливаете"), Modifier.hintSpot(Hint.Target.BOOK_AIM))
            History(book, Modifier.hintSpot(Hint.Target.BOOK_HISTORY))
            Upcoming(plant, book, garden)
            FilledTonalButton(onClick = { go.plant(id) }, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                Icon(painterResource(R.drawable.ic_eco), null, Modifier.size(20.dp))
                Text(Lang.text("Открыть растение"), Modifier.padding(start = 8.dp), style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

private fun read(plant: Plant, garden: Garden, period: com.ledro6.sprout.model.Almanac.Period): PlantBook =
    PlantBook.of(plant, garden.log, period, garden.since, System.currentTimeMillis(), Days.current)

@Composable
private fun Header(plant: Plant, garden: Garden) {
    val palette = LocalPalette.current
    Plate(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            PlantPhoto(plant, Modifier.size(72.dp), radius = 16.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(plant.name, style = MaterialTheme.typography.titleLarge, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Note(listOf(plant.species, garden.roomName(plant.id).orEmpty()).filter { it.isNotEmpty() }.joinToString(" · "))
                Text(
                    Lang.format("Влажность %@", plant.moistureLabel),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = palette.level(plant.moisture),
                )
            }
        }
    }
}

@Composable
private fun Figures(book: PlantBook, modifier: Modifier) {
    SproutGroup(Lang.text("Цифры"), modifier) {
        TileRow { weight ->
            StatTile(Lang.number(book.inPeriod), Lang.text("За период"), weight)
            StatTile(Lang.number(book.total), Lang.text("Всего"), weight)
        }
        TileRow { weight ->
            StatTile(book.last?.let { Diary.label(it, System.currentTimeMillis(), Days.current) } ?: "—", Lang.text("Последний полив"), weight)
            StatTile(book.average?.let { Diary.rhythm(it) } ?: "—", Lang.text("В среднем"), weight)
        }
    }
}

@Composable
private fun History(book: PlantBook, modifier: Modifier) {
    val points = book.recent.mapNotNull { entry -> entry.left?.let { entry.at to it } }
    SproutGroup(Lang.text("История"), modifier) {
        if (points.isEmpty()) {
            Note(Lang.text("За этот период поливов не было."))
            return@SproutGroup
        }
        val days = Days.current
        LevelChart(
            points,
            Stats.date(days.day(points.minOf { it.first }), "dMMM"),
            Stats.date(days.day(points.maxOf { it.first }), "dMMM"),
        )
    }
}

@Composable
private fun Upcoming(plant: Plant, book: PlantBook, garden: Garden) {
    SproutGroup(Lang.text("Следующие поливы")) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            book.dues.forEachIndexed { index, day ->
                Text(
                    Stats.day(day),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (index == 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }
        Rhythm.suggest(plant, garden.log)?.let { days ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(painterResource(R.drawable.ic_event_upcoming), null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                Text(Lang.text("Поливаете раньше срока"), style = MaterialTheme.typography.bodyLarge)
            }
            Note(
                Lang.format(
                    "Похоже, земля сохнет быстрее: %1\$@ вместо %2\$@.",
                    Species.periodPhrase(days),
                    Species.periodPhrase(plant.dryingDays),
                ),
            )
        }
    }
}
