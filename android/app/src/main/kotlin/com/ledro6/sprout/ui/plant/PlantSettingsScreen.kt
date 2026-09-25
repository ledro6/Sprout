package com.ledro6.sprout.ui.plant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AssistChip
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.model.Care
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Species
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.PeriodWheel
import com.ledro6.sprout.ui.components.SproutBlock
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermHint
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.home.Ask

/**
 * Настройки растения: кличка, вид, комната, срок полива, подкормка и
 * пересадка. Черновик — до «Готово»; назад — как «Отмена».
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlantSettingsScreen(id: String, go: Go) {
    val garden = LocalSprout.current.garden
    val plant = garden.plant(id)
    if (plant == null) {
        SubScreen(Lang.text("Настройки растения"), onBack = go::back) {}
        return
    }
    var name by rememberSaveable { mutableStateOf(plant.name) }
    var species by rememberSaveable { mutableStateOf(plant.species) }
    var room by rememberSaveable { mutableStateOf(garden.roomName(id).orEmpty()) }
    var period by rememberSaveable { mutableStateOf(plant.dryingDays) }
    var feeds by rememberSaveable { mutableStateOf(plant.tending.feedEvery != null) }
    var feedEvery by rememberSaveable { mutableStateOf(plant.tending.feedEvery ?: 21.0) }
    var repotMonths by rememberSaveable { mutableStateOf(plant.tending.repotEvery?.let { Care.months(it) }) }
    var naming by remember { mutableStateOf(false) }
    var roomsOpen by remember { mutableStateOf(false) }
    var repotOpen by remember { mutableStateOf(false) }

    val valid = name.isNotBlank()
    val feedDraft = if (feeds) feedEvery else null
    val repotDraft = repotMonths?.let { months ->
        val old = plant.tending.repotEvery
        if (old != null && Care.months(old) == months) old else Care.days(months)
    }
    val usual = Species.usual(species)?.takeIf { it != period }
    val rooms = garden.rooms.map { it.name }.let { if (room.isEmpty() || room in it) it else it + room }

    fun save() {
        if (!valid) return
        val changed = name.trim() != plant.name || species.trim() != plant.species || period != plant.dryingDays ||
            room != garden.roomName(id).orEmpty() || feedDraft != plant.tending.feedEvery || repotDraft != plant.tending.repotEvery
        garden.tune(id, name, species, period)
        garden.tend(id, feedDraft, repotDraft)
        garden.relocate(id, room)
        if (changed) Feel.done()
        go.back()
    }

    SubScreen(
        title = Lang.text("Настройки растения"),
        onBack = go::back,
        walk = Walk.TUNING,
        actions = { TextButton(onClick = { save() }, enabled = valid) { Text(Lang.text("Готово")) } },
    ) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            SproutGroup(Lang.text("Растение"), Modifier.hintSpot(Hint.Target.TUNING_ABOUT)) {
                SproutBlock(Lang.text("Кличка")) {
                    OutlinedTextField(
                        name, { name = it }, singleLine = true, placeholder = { Text(Lang.text("Баксик")) },
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                SproutDivider()
                SproutBlock(Lang.text("Вид")) {
                    OutlinedTextField(
                        species, { species = it }, singleLine = true, placeholder = { Text(Lang.text("Монстера")) },
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            SproutGroup(Lang.text("Уход"), Modifier.hintSpot(Hint.Target.TUNING_HABITS)) {
                SproutBlock(Lang.text("Комната")) {
                    ExposedDropdownMenuBox(expanded = roomsOpen, onExpandedChange = { roomsOpen = it }) {
                        OutlinedTextField(
                            value = room,
                            onValueChange = {},
                            readOnly = true,
                            singleLine = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(roomsOpen) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
                        )
                        ExposedDropdownMenu(expanded = roomsOpen, onDismissRequest = { roomsOpen = false }) {
                            for (option in rooms) {
                                DropdownMenuItem(text = { Text(option) }, onClick = { room = option; roomsOpen = false })
                            }
                            HorizontalDivider()
                            DropdownMenuItem(
                                text = { Text(Lang.text("Новая комната…")) },
                                leadingIcon = { Icon(painterResource(R.drawable.ic_add), null) },
                                onClick = { roomsOpen = false; naming = true },
                            )
                        }
                    }
                }
                SproutDivider()
                SproutBlock(Lang.text("Полив"), term = Term.PERIOD) {
                    PeriodWheel(period) { period = it }
                    Text(
                        plant.retimed(period).wateringLabel,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    AnimatedVisibility(usual != null) {
                        val days = usual ?: period
                        AssistChip(
                            onClick = { period = days; Feel.pick() },
                            label = { Text(Lang.format("Обычно для вида: %@", Species.periodPhrase(days))) },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_auto_awesome), null, Modifier.size(18.dp)) },
                        )
                    }
                }
            }
            SproutGroup(Lang.text("Подкормка и пересадка"), Modifier.hintSpot(Hint.Target.TUNING_TENDING)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                        Text(Lang.text("Напоминать о подкормке"), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f, fill = false))
                        TermHint(Term.FEEDING)
                    }
                    Switch(feeds, { feeds = it })
                }
                AnimatedVisibility(feeds) { PeriodWheel(feedEvery) { feedEvery = it } }
                SproutDivider()
                SproutBlock(Lang.text("Пересадка"), term = Term.REPOTTING) {
                    val label = repotMonths?.let { Lang.format("Раз в %lld месяцев", it) } ?: Lang.text("Не напоминать")
                    ExposedDropdownMenuBox(expanded = repotOpen, onExpandedChange = { repotOpen = it }) {
                        OutlinedTextField(
                            value = label,
                            onValueChange = {},
                            readOnly = true,
                            singleLine = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(repotOpen) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
                        )
                        ExposedDropdownMenu(expanded = repotOpen, onDismissRequest = { repotOpen = false }) {
                            DropdownMenuItem(text = { Text(Lang.text("Не напоминать")) }, onClick = { repotMonths = null; repotOpen = false })
                            for (months in Care.repotMonths) {
                                DropdownMenuItem(
                                    text = { Text(Lang.format("Раз в %lld месяцев", months)) },
                                    onClick = { repotMonths = months; repotOpen = false },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    if (naming) {
        Ask(Lang.text("Новая комната"), Lang.text("Комната появится, когда вы нажмёте «Готово»."), Lang.text("Балкон"), "", Lang.text("Выбрать")) { made ->
            naming = false
            val trimmed = made?.trim().orEmpty()
            if (trimmed.isNotEmpty()) room = trimmed
        }
    }
}
