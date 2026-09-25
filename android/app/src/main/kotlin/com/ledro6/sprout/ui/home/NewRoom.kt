package com.ledro6.sprout.ui.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.keyframes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import kotlinx.coroutines.launch

/**
 * «Новая комната» — страница за последней комнатой. Имя пишут, нажав на поле:
 * клавиатура сама не поднимается. Занятое или пустое имя — поле вздрагивает.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NewRoom(go: Go, bottom: Dp, made: (String) -> Unit) {
    val garden = LocalSprout.current.garden
    var draft by rememberSaveable { mutableStateOf("") }
    var misses by remember { mutableIntStateOf(0) }
    val shake = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    val bare = garden.rooms.isEmpty()
    val ideas = listOf("Гостиная", "Спальня", "Кухня", "Балкон", "Кабинет", "Детская", "Ванная", "Прихожая")
        .map { Lang.text(it) }
        .filter { idea -> garden.rooms.none { it.name.equals(idea, ignoreCase = true) } }

    fun create(name: String) {
        val trimmed = name.trim()
        if (garden.addRoom(trimmed)) {
            draft = ""
            focus.clearFocus()
            Feel.done()
            made(trimmed)
        } else {
            misses += 1
            Feel.wrong()
            scope.launch {
                shake.animateTo(0f, keyframes {
                    durationMillis = 470
                    -10f at 60
                    9f at 130
                    -6f at 200
                    3f at 270
                    0f at 470
                })
            }
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(top = 24.dp, bottom = bottom),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (bare) {
            Text(
                Lang.text("В саду пока ничего не растёт. Посадите первое растение во вкладке «Добавить»."),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        Text(
            Lang.text("Растения в неё можно будет посадить или перевезти."),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        OutlinedTextField(
            value = draft,
            onValueChange = { draft = it },
            placeholder = { Text(Lang.text("Название"), Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
            singleLine = true,
            textStyle = MaterialTheme.typography.titleLarge.copy(textAlign = TextAlign.Center),
            shape = RoundedCornerShape(50),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { create(draft) }),
            modifier = Modifier
                .fillMaxWidth()
                .graphicsLayer { translationX = shake.value * density },
        )
        Button(onClick = { create(draft) }, enabled = draft.isNotBlank(), modifier = Modifier.fillMaxWidth()) {
            Text(Lang.text("Завести комнату"))
        }
        if (ideas.isNotEmpty()) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                modifier = Modifier.fillMaxWidth(),
            ) {
                for (idea in ideas) SuggestionChip(onClick = { create(idea) }, label = { Text(idea) })
            }
        }
        if (!bare) {
            OutlinedButton(onClick = { go.rooms() }) {
                Icon(painterResource(R.drawable.ic_edit), contentDescription = null, modifier = Modifier.padding(end = 8.dp))
                Text(Lang.text("Изменить комнаты…"))
            }
        }
    }
}

