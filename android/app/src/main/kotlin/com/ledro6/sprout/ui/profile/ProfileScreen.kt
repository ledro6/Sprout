package com.ledro6.sprout.ui.profile

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.model.Days
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Rival
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Eye
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.Shots
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Figure
import com.ledro6.sprout.ui.components.RowShape
import com.ledro6.sprout.ui.components.Snapshot
import com.ledro6.sprout.ui.components.SproutBlock
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SproutLink
import com.ledro6.sprout.ui.components.SproutTints
import com.ledro6.sprout.ui.components.TabScreen
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.ui.components.rememberPhotoSource
import com.ledro6.sprout.ui.home.Ask
import com.ledro6.sprout.ui.stats.Stats
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate

/** Профиль: хозяин, сад в цифрах, друзья-соперники и прочее. */
@Composable
fun ProfileScreen(go: Go, outer: PaddingValues) {
    TabScreen(Lang.text("Профиль"), Walk.PROFILE, onSettings = go::settings) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = inner.calculateTopPadding())
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = outer.calculateBottomPadding() + 28.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Person(Modifier.hintSpot(Hint.Target.PROFILE_PERSON))
            Plot(Modifier.hintSpot(Hint.Target.PROFILE_PLOT))
            Rivals(Modifier.hintSpot(Hint.Target.PROFILE_RIVALS))
            More(go, Modifier.hintSpot(Hint.Target.PROFILE_MORE))
        }
    }
}

@Composable
private fun Person(modifier: Modifier) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val settings = sprout.settings
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val named = garden.owner.isNotEmpty()
    var renaming by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }

    val photos = rememberPhotoSource { uri ->
        scope.launch {
            val image = withContext(Dispatchers.IO) { Eye.load(context, uri, 1024) } ?: return@launch Feel.wrong()
            val side = minOf(image.width, image.height)
            val square = Bitmap.createBitmap(image, (image.width - side) / 2, (image.height - side) / 2, side, side)
            val name = Eye.keep(square) ?: return@launch Feel.wrong()
            val old = settings.avatarShot
            settings.avatarShot = name
            old?.let {
                Snapshot.forget(it)
                Shots.drop(it)
            }
            Feel.done()
        }
    }

    SproutGroup(Lang.text("Хозяин"), modifier) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box {
                Avatar(Modifier.clickable { menu = true }.semantics { contentDescription = Lang.text("Фото") })
                Box(
                    Modifier
                        .align(Alignment.BottomEnd)
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary)
                        .border(1.5.dp, MaterialTheme.colorScheme.surfaceContainerLow, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(painterResource(R.drawable.ic_photo_camera_fill), null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(12.dp))
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        { Text(Lang.text("Из галереи")) }, { menu = false; photos.gallery() },
                        leadingIcon = { Icon(painterResource(R.drawable.ic_photo_library), null) },
                    )
                    if (photos.hasCamera) {
                        DropdownMenuItem(
                            { Text(Lang.text("Снять")) }, { menu = false; photos.camera() },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_photo_camera), null) },
                        )
                    }
                    settings.avatarShot?.let { shot ->
                        DropdownMenuItem(
                            { Text(Lang.text("Убрать фото"), color = MaterialTheme.colorScheme.error) },
                            {
                                menu = false
                                settings.avatarShot = null
                                Snapshot.forget(shot)
                                Shots.drop(shot)
                                Feel.toss()
                            },
                            leadingIcon = { Icon(painterResource(R.drawable.ic_delete), null, tint = MaterialTheme.colorScheme.error) },
                        )
                    }
                }
            }
            // Кнопка — под именем: рядом с ним на крупном шрифте имя сжалось бы в столбик.
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    if (named) garden.owner else Lang.text("Имя не задано"),
                    style = MaterialTheme.typography.titleLarge,
                    color = if (named) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    if (named) Lang.format("Сад с %@", Stats.date(Days.current.day(garden.since), "dMMMMy"))
                    else Lang.text("Назовитесь — имя встретит вас при запуске"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                FilledTonalButton(onClick = { renaming = true }, modifier = Modifier.padding(top = 6.dp)) {
                    Text(if (named) Lang.text("Изменить") else Lang.text("Назвать"))
                }
            }
        }
        AnimatedVisibility(settings.avatarShot == null) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SproutDivider()
                SproutBlock(Lang.text("Цвет")) {
                    SproutTints(settings.avatarTint) { tint, _ ->
                        settings.avatarTint = tint
                        Feel.pick()
                    }
                }
            }
        }
    }
    if (renaming) {
        Ask(
            Lang.text("Как вас зовут?"),
            Lang.text("Имя стоит в профиле и уходит вместе со счётом друзьям."),
            Lang.text("Имя"),
            garden.owner,
            Lang.text("Сохранить"),
        ) { name ->
            renaming = false
            if (name != null) {
                garden.renameOwner(name)
                Feel.done()
            }
        }
    }
}

/** Кружок хозяина: снимок, а без него — буква на выбранном цвете. */
@Composable
fun Avatar(modifier: Modifier = Modifier) {
    val sprout = LocalSprout.current
    val settings = sprout.settings
    val owner = sprout.garden.owner.trim()
    val shot = settings.avatarShot?.let { remember(it) { Snapshot.image(it, 512) } }
    val side = Modifier.size(64.dp).clip(CircleShape)
    if (shot != null) {
        Image(shot, null, modifier.then(side), contentScale = ContentScale.Crop)
        return
    }
    Box(modifier.then(side).background(LocalPalette.current.swatch(settings.avatarTint)), contentAlignment = Alignment.Center) {
        if (owner.isNotEmpty()) {
            val letter = String(Character.toChars(owner.codePointAt(0))).uppercase(Lang.locale)
            Text(letter, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold, color = Color.White)
        } else {
            Icon(painterResource(R.drawable.ic_person_fill), null, tint = Color.White, modifier = Modifier.size(30.dp))
        }
    }
}

@Composable
private fun Plot(modifier: Modifier) {
    val garden = LocalSprout.current.garden
    val days = Days.current
    val age = maxOf(0L, days.between(days.day(garden.since), LocalDate.now(days.zone))).toInt()
    SproutGroup(Lang.text("Сад"), modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Figure(Lang.text("Растений"), Lang.number(garden.plantCount), Modifier.weight(1f))
            Figure(Lang.text("Комнат"), Lang.number(garden.rooms.size), Modifier.weight(1f))
            Figure(Lang.text("Дней"), Lang.number(age), Modifier.weight(1f))
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Rivals(modifier: Modifier) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val friends = sprout.friends
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val score by produceState(garden.score(), garden.log, garden.roster) {
        while (true) {
            value = garden.score()
            delay(30_000)
        }
    }
    val me = Rival.mine(garden.signed, score, garden.plantCount, System.currentTimeMillis())
    val standings = (listOf(me) + friends.rivals.filter { it.id != me.id })
        .sortedWith(compareByDescending<Rival> { it.total }.thenBy { it.name })
    var trouble by remember { mutableStateOf<String?>(null) }
    var welcomed by remember { mutableStateOf<Rival?>(null) }
    var doomed by remember { mutableStateOf<String?>(null) }
    var paste by remember { mutableStateOf<Rect?>(null) }

    fun invite() {
        val text = runCatching {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString()
        }.getOrNull().orEmpty()
        val rival = friends.take(text, garden.owner)
        if (rival == null) {
            trouble = if (Rival.read(text) == null) {
                Lang.text("В скопированном нет кода Sprout. Скопируйте сообщение друга целиком — код лежит в нём последней строкой.")
            } else {
                Lang.text("Это ваш собственный код: в таблице вы и так есть.")
            }
            Feel.wrong()
            return
        }
        welcomed = rival
        Effects.cheer(paste, density)
        Feel.done()
    }

    SproutGroup(Lang.text("Друзья"), modifier) {
        standings.forEachIndexed { index, rival ->
            if (index > 0) SproutDivider()
            val mine = rival.id == me.id
            Box {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RowShape)
                        .combinedClickable(enabled = !mine, onClick = {}, onLongClick = { doomed = rival.id; Feel.pick() })
                        .semantics(mergeDescendants = true) {},
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        Lang.number(index + 1), style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.outline, modifier = Modifier.width(18.dp),
                    )
                    Column(Modifier.weight(1f)) {
                        Text(rival.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(
                            if (mine) Lang.text("вы") else Lang.format("счёт от %@", Stats.date(Days.current.day(rival.stamp), "dMMM")),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(Lang.number(rival.total), style = MaterialTheme.typography.bodyLarge)
                        Text(Lang.format("череда %lld", rival.streak), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                DropdownMenu(expanded = doomed == rival.id, onDismissRequest = { doomed = null }) {
                    DropdownMenuItem(
                        { Text(Lang.text("Убрать из таблицы"), color = MaterialTheme.colorScheme.error) },
                        {
                            doomed = null
                            friends.remove(rival.id)
                            Feel.toss()
                        },
                        leadingIcon = { Icon(painterResource(R.drawable.ic_person_remove), null, tint = MaterialTheme.colorScheme.error) },
                    )
                }
            }
        }
        SproutDivider()
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            FilledTonalButton(onClick = {
                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, me.card)
                runCatching { context.startActivity(Intent.createChooser(send, Lang.text("Позвать"))) }
            }) {
                Icon(painterResource(R.drawable.ic_share), null, Modifier.size(18.dp))
                Text(Lang.text("Позвать"), Modifier.padding(start = 8.dp))
            }
            OutlinedButton(onClick = ::invite, modifier = Modifier.onGloballyPositioned { paste = it.boundsInRoot() }) {
                Icon(painterResource(R.drawable.ic_content_paste), null, Modifier.size(18.dp))
                Text(Lang.text("Вставить"), Modifier.padding(start = 8.dp))
            }
        }
    }

    trouble?.let { text ->
        AlertDialog(
            onDismissRequest = { trouble = null },
            title = { Text(Lang.text("Не вышло")) },
            text = { Text(text) },
            confirmButton = { TextButton(onClick = { trouble = null }) { Text(Lang.text("Понятно")) } },
        )
    }
    welcomed?.let { rival ->
        AlertDialog(
            onDismissRequest = { welcomed = null },
            title = { Text(rival.name) },
            text = {
                Text(Lang.format("Счёт от %@. Обновится, когда друг пришлёт код снова.", Stats.date(Days.current.day(rival.stamp), "dMMMM")))
            },
            confirmButton = { TextButton(onClick = { welcomed = null }) { Text(Lang.text("Хорошо")) } },
        )
    }
}

@Composable
private fun More(go: Go, modifier: Modifier) {
    val garden = LocalSprout.current.garden
    var erasing by remember { mutableStateOf(false) }
    SproutGroup(Lang.text("Ещё"), modifier) {
        SproutLink(Lang.text("Настройки"), R.drawable.ic_settings, onClick = go::settings)
        SproutDivider()
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RowShape)
                .clickable { erasing = true }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(painterResource(R.drawable.ic_delete), null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(22.dp))
            Text(Lang.text("Стереть сад"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.error)
        }
    }
    if (erasing) {
        AlertDialog(
            onDismissRequest = { erasing = false },
            icon = { Icon(painterResource(R.drawable.ic_delete), null) },
            title = { Text(Lang.text("Стереть сад?")) },
            text = { Text(Lang.text("Исчезнут все растения и весь журнал поливов. Вернуть их будет нельзя.")) },
            confirmButton = {
                TextButton(onClick = {
                    erasing = false
                    garden.erase()
                    Feel.toss()
                }) { Text(Lang.text("Стереть"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { erasing = false }) { Text(Lang.text("Отмена")) } },
        )
    }
}
