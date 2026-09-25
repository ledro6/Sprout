package com.ledro6.sprout.ui.home

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DateRangePicker
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDateRangePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Skeleton
import com.ledro6.sprout.model.Trip
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.hintSpot
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * «Уезжаю»: кто дождётся хозяина, а кого должен полить сосед и когда. Даты —
 * выбором диапазона Material; памятка уходит соседу любым мессенджером.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TripScreen(go: Go) {
    val garden = LocalSprout.current.garden
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val today = LocalDate.now()
    var leave by rememberSaveable { mutableLongStateOf(today.plusDays(1).toEpochDay()) }
    var back by rememberSaveable { mutableLongStateOf(today.plusDays(8).toEpochDay()) }
    var picking by remember { mutableStateOf(false) }
    var watered by rememberSaveable { mutableStateOf(false) }
    var button by remember { mutableStateOf<Rect?>(null) }
    val from = LocalDate.ofEpochDay(leave)
    val to = LocalDate.ofEpochDay(back)
    val days = Trip.days(from, to)
    val needs = Trip.needs(garden.rooms, days)

    SubScreen(Lang.text("Уезжаю"), onBack = go::back, walk = Walk.TRIP) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            SproutGroup(Lang.text("Когда"), Modifier.hintSpot(Hint.Target.TRIP_DATES)) {
                DateRow(Lang.text("Уезжаю"), from) { picking = true }
                SproutDivider()
                DateRow(Lang.text("Вернусь"), to) { picking = true }
                Text(
                    Lang.format("Поездка — %lld дней", days),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (needs.isEmpty()) {
                SproutGroup(Lang.text("Сад"), Modifier.hintSpot(Hint.Target.TRIP_PLAN)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(painterResource(R.drawable.ic_check_circle), null, tint = MaterialTheme.colorScheme.secondary)
                        Text(Lang.text("Все дождутся вас: перед отъездом полейте — и можно ехать."), style = MaterialTheme.typography.bodyLarge)
                    }
                }
            } else {
                SproutGroup(Lang.text("Кого полить соседу"), Modifier.hintSpot(Hint.Target.TRIP_PLAN)) {
                    needs.forEachIndexed { index, need ->
                        if (index > 0) SproutDivider()
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(need.plant.name, style = MaterialTheme.typography.bodyLarge)
                            val dates = need.visits.map { Skeleton.format(from.plusDays(it.toLong()), "dMMM") }
                            Text(
                                Lang.format("%1\$@ · полить: %2\$@", need.room, dates.joinToString(", ")),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    val others = Trip.fine(garden.rooms, days).size
                    if (others > 0) {
                        SproutDivider()
                        Text(
                            Lang.format("Остальные дождутся сами: %@.", Lang.format("%lld растений", others)),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            Column(Modifier.hintSpot(Hint.Target.TRIP_ACTIONS), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = {
                        for (plant in garden.plants) garden.water(plant.id)
                        watered = true
                        Effects.cheer(button, density)
                        Feel.water()
                    },
                    enabled = !watered && garden.plants.isNotEmpty(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .onGloballyPositioned { button = it.boundsInRoot() },
                ) {
                    Icon(painterResource(if (watered) R.drawable.ic_check else R.drawable.ic_water_drop_fill), null, Modifier.size(20.dp))
                    Text(
                        if (watered) Lang.text("Все политы") else Lang.text("Полить всех перед отъездом"),
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
                if (needs.isNotEmpty()) {
                    OutlinedButton(
                        onClick = {
                            val memo = Trip.memo(needs, from, to)
                            val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, memo)
                            runCatching { context.startActivity(Intent.createChooser(send, null)) }
                        },
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                    ) {
                        Icon(painterResource(R.drawable.ic_share), null, Modifier.size(20.dp))
                        Text(Lang.text("Отправить памятку соседу"), modifier = Modifier.padding(start = 8.dp))
                    }
                }
            }
        }
    }

    if (picking) {
        val start = today.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli()
        val state = rememberDateRangePickerState(
            initialSelectedStartDateMillis = from.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
            initialSelectedEndDateMillis = to.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= start
            },
        )
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        state.selectedStartDateMillis?.let { leave = day(it).toEpochDay() }
                        back = maxOf(state.selectedEndDateMillis?.let { day(it).toEpochDay() } ?: back, leave)
                        picking = false
                    },
                    enabled = state.selectedStartDateMillis != null,
                ) { Text(Lang.text("Готово")) }
            },
            dismissButton = { TextButton(onClick = { picking = false }) { Text(Lang.text("Отмена")) } },
        ) {
            DateRangePicker(state, modifier = Modifier.weight(1f), showModeToggle = false)
        }
    }
}

private fun day(millis: Long): LocalDate = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()

@Composable
private fun DateRow(title: String, date: LocalDate, pick: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        TextButton(onClick = pick) { Text(Skeleton.format(date, "dMMMMy")) }
    }
}
