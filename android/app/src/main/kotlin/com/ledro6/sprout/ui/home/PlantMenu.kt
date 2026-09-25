package com.ledro6.sprout.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.platform.ArSupport
import com.ledro6.sprout.ui.Go

/**
 * Меню по долгому нажатию — те же пункты, что на iPhone. «Переехать»
 * открывает список комнат прямо в меню: вложенных меню у Material нет.
 */
@Composable
fun PlantMenu(plant: Plant, shelf: ShelfState, actions: ShelfActions, go: Go) {
    val garden = LocalSprout.current.garden
    var moving by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf(false) }
    var asking by remember { mutableStateOf(false) }
    val close = {
        shelf.menu = null
        moving = false
    }
    DropdownMenu(expanded = shelf.menu == plant.id && !renaming && !asking, onDismissRequest = close) {
        if (!moving) {
            DropdownMenuItem(
                text = { Text(Lang.text("Полить сейчас")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_water_drop), null) },
                onClick = {
                    close()
                    actions.water(plant.id)
                },
            )
            DropdownMenuItem(
                text = { Text(Lang.text("Переименовать")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_edit), null) },
                onClick = { renaming = true },
            )
            DropdownMenuItem(
                text = { Text(Lang.text("Настройки")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_tune), null) },
                onClick = {
                    close()
                    go.tune(plant.id)
                },
            )
            if (ArSupport.available) {
                DropdownMenuItem(
                    text = { Text(Lang.text("Посмотреть в AR")) },
                    leadingIcon = { Icon(painterResource(R.drawable.ic_view_in_ar), null) },
                    onClick = {
                        close()
                        go.ar(listOf(plant.id))
                    },
                )
            }
            DropdownMenuItem(
                text = { Text(Lang.text("Переехать")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_door_open), null) },
                trailingIcon = { Icon(painterResource(R.drawable.ic_chevron_right), null) },
                onClick = { moving = true },
            )
            DropdownMenuItem(
                text = { Text(Lang.text("Расставить")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_apps), null) },
                onClick = {
                    close()
                    actions.begin()
                },
            )
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text(Lang.text("Удалить"), color = MaterialTheme.colorScheme.error) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_delete), null, tint = MaterialTheme.colorScheme.error) },
                onClick = {
                    close()
                    actions.toss(plant.id)
                },
            )
        } else {
            val here = garden.roomName(plant.id)
            DropdownMenuItem(
                text = { Text(Lang.text("Переехать")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_arrow_back), null) },
                onClick = { moving = false },
            )
            HorizontalDivider()
            for (room in garden.rooms.map { it.name }.filter { it != here }) {
                DropdownMenuItem(
                    text = { Text(room) },
                    onClick = {
                        close()
                        garden.relocate(plant.id, room)
                    },
                )
            }
            DropdownMenuItem(
                text = { Text(Lang.text("Новая комната…")) },
                leadingIcon = { Icon(painterResource(R.drawable.ic_add), null) },
                onClick = { asking = true },
            )
        }
    }
    if (renaming) {
        Ask(
            title = Lang.text("Переименовать"),
            message = Lang.text("Как теперь зовут растение?"),
            hint = Lang.text("Кличка"),
            start = plant.name,
            confirm = Lang.text("Сохранить"),
            done = { name ->
                renaming = false
                close()
                if (name != null) garden.rename(plant.id, name)
            },
        )
    }
    if (asking) {
        Ask(
            title = Lang.text("Новая комната"),
            message = Lang.text("Растение переедет туда, и комната появится в списке."),
            hint = Lang.text("Балкон"),
            start = "",
            confirm = Lang.text("Переехать"),
            done = { name ->
                asking = false
                close()
                if (name != null) garden.relocate(plant.id, name)
            },
        )
    }
}

/** Вопрос с полем ввода — диалогом Material. Пусто — отмена. */
@Composable
fun Ask(title: String, message: String, hint: String, start: String, confirm: String, done: (String?) -> Unit) {
    var text by remember { mutableStateOf(start) }
    AlertDialog(
        onDismissRequest = { done(null) },
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(message)
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    placeholder = { Text(hint) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { done(text) }),
                )
            }
        },
        confirmButton = { TextButton(onClick = { done(text) }, enabled = text.isNotBlank()) { Text(confirm) } },
        dismissButton = { TextButton(onClick = { done(null) }) { Text(Lang.text("Отмена")) } },
    )
}
