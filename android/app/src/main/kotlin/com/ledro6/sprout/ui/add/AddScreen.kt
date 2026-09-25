package com.ledro6.sprout.ui.add

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.design.SproutShapes
import com.ledro6.sprout.model.Guess
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.model.roundedInt
import com.ledro6.sprout.platform.Eye
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.CardShape
import com.ledro6.sprout.ui.components.PeriodWheel
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.SproutBlock
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.TabScreen
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.components.rememberPhotoSource
import com.ledro6.sprout.ui.home.Ask
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max

/**
 * «Добавить»: снимок, кличка и вид, комната и срок — и «Посадить». Вид
 * подсказывает телефон по снимку; обычный срок подставляется сам.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddScreen(go: Go, outer: PaddingValues) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current.density
    val focus = LocalFocusManager.current
    var raw by remember { mutableStateOf<Bitmap?>(null) }
    var shot by remember { mutableStateOf<Bitmap?>(null) }
    var trimming by remember { mutableStateOf(false) }
    var guess by remember { mutableStateOf<Guess?>(null) }
    var looking by remember { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var species by rememberSaveable { mutableStateOf("") }
    var room by rememberSaveable { mutableStateOf(garden.rooms.firstOrNull()?.name ?: Lang.text("Дом")) }
    var period by rememberSaveable { mutableStateOf(7.0) }
    var naming by remember { mutableStateOf(false) }
    var roomsOpen by remember { mutableStateOf(false) }
    var planted by remember { mutableStateOf<Pair<String, String>?>(null) }
    var button by remember { mutableStateOf<Rect?>(null) }

    val photos = rememberPhotoSource { uri ->
        scope.launch {
            raw = withContext(Dispatchers.IO) { Eye.load(context, uri, 2048) }
            if (raw != null) trimming = true
        }
    }

    fun take(image: Bitmap) {
        shot = image
        looking = true
        scope.launch {
            val seen = Eye.guess(image)
            guess = seen
            looking = false
            if (seen != null && species.isBlank()) {
                species = seen.species
                period = max(seen.dryingDays.roundedInt().toDouble(), 1.0)
            }
        }
    }

    fun forget() {
        shot = null
        raw = null
        guess = null
    }

    fun plant() {
        val nickname = name.trim()
        if (nickname.isEmpty()) return
        val typed = species.trim()
        val kind = typed.ifEmpty { guess?.species ?: Lang.text("Комнатное растение") }
        val place = room.trim().ifEmpty { Lang.text("Дом") }
        val image = shot
        scope.launch {
            val saved = image?.let { Eye.keep(it) }
            val seedling = Plant.new(nickname, kind, period, shot = saved)
            garden.add(seedling, place)
            Effects.cheer(button, density)
            Feel.planted()
            focus.clearFocus()
            planted = nickname to (
                Lang.format("Растёт в комнате «%@».", place) + "\n" +
                    Lang.format("Полито, следующий полив через %lld дней.", period.roundedInt())
                )
            name = ""
            species = ""
            forget()
            period = 7.0
        }
    }

    TabScreen(Lang.text("Добавить"), Walk.ADD, onSettings = go::settings) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = inner.calculateTopPadding())
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = outer.calculateBottomPadding() + 28.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            SproutGroup(Lang.text("Снимок"), Modifier.hintSpot(Hint.Target.ADD_PICTURE)) {
                Plate(
                    Modifier
                        .fillMaxWidth()
                        .aspectRatio(1f)
                        .clip(CardShape)
                        .clickable(enabled = raw != null) { trimming = true },
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        val image = shot
                        if (image != null) {
                            Image(image.asImageBitmap(), Lang.text("Снимок растения"), contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                        } else {
                            Sprout(Modifier.size(64.dp))
                        }
                        if (looking) CircularProgressIndicator()
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    FilledTonalButton(onClick = photos.gallery) {
                        Icon(painterResource(R.drawable.ic_photo_library), null, Modifier.size(18.dp))
                        Text(Lang.text("Фото"), Modifier.padding(start = 8.dp))
                    }
                    if (photos.hasCamera) {
                        FilledTonalButton(onClick = photos.camera) {
                            Icon(painterResource(R.drawable.ic_photo_camera), null, Modifier.size(18.dp))
                            Text(Lang.text("Снять"), Modifier.padding(start = 8.dp))
                        }
                    }
                    if (shot != null) {
                        FilledTonalIconButton(onClick = { forget() }) {
                            Icon(painterResource(R.drawable.ic_close), Lang.text("Убрать снимок"))
                        }
                    }
                }
                if (shot != null && !looking) {
                    val seen = guess
                    Text(
                        if (seen == null) Lang.text("Растения на снимке телефон не узнал — впишите вид сами.")
                        else Lang.format(
                            "Телефон узнал: %1\$@ — уверен на %2\$lld%%. Поправьте, если не так.",
                            seen.species, (seen.confidence * 100).roundedInt(),
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            SproutGroup(Lang.text("Растение"), Modifier.hintSpot(Hint.Target.ADD_ABOUT)) {
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
            SproutGroup(Lang.text("Уход"), Modifier.hintSpot(Hint.Target.ADD_HABITS)) {
                SproutBlock(Lang.text("Комната")) {
                    val rooms = garden.rooms.map { it.name }.let { if (room.isEmpty() || room in it) it else it + room }
                    ExposedDropdownMenuBox(expanded = roomsOpen, onExpandedChange = { roomsOpen = it }) {
                        OutlinedTextField(
                            value = room.ifEmpty { Lang.text("Выбрать") },
                            onValueChange = {},
                            readOnly = true,
                            singleLine = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(roomsOpen) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
                        )
                        ExposedDropdownMenu(expanded = roomsOpen, onDismissRequest = { roomsOpen = false }) {
                            for (option in rooms) DropdownMenuItem(text = { Text(option) }, onClick = { room = option; roomsOpen = false })
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
                }
            }
            Button(
                onClick = { plant() },
                enabled = name.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .hintSpot(Hint.Target.ADD_PLANT)
                    .onGloballyPositioned { button = it.boundsInRoot() },
            ) { Text(Lang.text("Посадить"), style = MaterialTheme.typography.titleMedium) }
        }
    }

    if (trimming) {
        raw?.let { image ->
            Trim(image, cancel = { trimming = false }) { cut ->
                trimming = false
                take(cut)
            }
        }
    }
    if (naming) {
        Ask(Lang.text("Новая комната"), Lang.text("Растения в неё можно будет посадить или перевезти."), Lang.text("Название"), "", Lang.text("Завести")) { made ->
            naming = false
            val trimmed = made?.trim().orEmpty()
            if (trimmed.isNotEmpty()) room = trimmed
        }
    }
    planted?.let { (title, note) ->
        AlertDialog(
            onDismissRequest = { planted = null },
            title = { Text(title) },
            text = { Text(note) },
            confirmButton = { TextButton(onClick = { planted = null }) { Text(Lang.text("Хорошо")) } },
        )
    }
}

/** Росток из узора — пока снимка нет. */
@Composable
private fun Sprout(modifier: Modifier) {
    val ink = MaterialTheme.colorScheme.onSurface.copy(alpha = Metrics.PIECE_OFF)
    Canvas(modifier) {
        val piece = SproutShapes.pieces[0]
        val scale = minOf(size.width / SproutShapes.PIECE_W, size.height / SproutShapes.PIECE_H)
        drawIntoCanvas {
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = ink.toArgb() }
            it.nativeCanvas.save()
            it.nativeCanvas.translate(size.width / 2, size.height / 2)
            it.nativeCanvas.scale(scale, scale)
            it.nativeCanvas.translate(-piece.centreX, -piece.centreY)
            it.nativeCanvas.drawPath(piece.path, paint)
            it.nativeCanvas.restore()
        }
    }
}
