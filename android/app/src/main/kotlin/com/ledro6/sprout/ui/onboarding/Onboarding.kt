package com.ledro6.sprout.ui.onboarding

import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.fragment.app.FragmentActivity
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.SproutBackground
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Seed
import com.ledro6.sprout.model.Tour
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.Lock
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.SproutBadge
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutLogo
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermCard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Знакомство просят из настроек («Как пользоваться») или при первом запуске. */
object TourGate {
    var open by mutableStateOf(false)
}

fun Tour.Icon.drawable(): Int = when (this) {
    Tour.Icon.LEAF -> R.drawable.ic_eco
    Tour.Icon.TAP -> R.drawable.ic_touch_app
    Tour.Icon.HOLD -> R.drawable.ic_back_hand
    Tour.Icon.SWIPE -> R.drawable.ic_swipe
    Tour.Icon.GRID -> R.drawable.ic_apps
    Tour.Icon.AR -> R.drawable.ic_view_in_ar
    Tour.Icon.QUESTION -> R.drawable.ic_help
}

/**
 * Знакомство: страницы листаются пальцем, точки внизу, «Дальше» и
 * «Пропустить». На последней — вход в словарик.
 */
@Composable
fun TourScreen(done: () -> Unit) {
    val pages = Tour.pages
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    var glossary by remember { mutableStateOf(false) }
    val last = pager.currentPage == pages.size - 1
    Dialog(
        onDismissRequest = done,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        if (glossary) {
            BackHandler { glossary = false }
            SubScreen(Lang.text("Словарик"), onBack = { glossary = false }, large = true) { inner ->
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(inner)
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 40.dp),
                ) {
                    Plate(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            com.ledro6.sprout.model.Term.entries.forEachIndexed { index, term ->
                                if (index > 0) SproutDivider()
                                TermCard(term)
                            }
                        }
                    }
                }
            }
            return@Dialog
        }
        Box(Modifier.fillMaxSize()) {
            SproutBackground()
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                Row(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.weight(1f))
                    AnimatedVisibility(!last, enter = fadeIn(), exit = fadeOut()) {
                        TextButton(onClick = done) { Text(Lang.text("Пропустить")) }
                    }
                }
                HorizontalPager(pager, Modifier.weight(1f)) { index -> TourPage(pages[index], pager.currentPage == index) }
                Dots(pages.size, pager.currentPage)
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 16.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    AnimatedVisibility(last) {
                        FilledTonalButton(onClick = { glossary = true }) {
                            Icon(painterResource(R.drawable.ic_dictionary), null, Modifier.size(18.dp))
                            Text(Lang.text("Словарик"), Modifier.padding(start = 8.dp))
                        }
                    }
                    Button(
                        onClick = {
                            if (last) {
                                done()
                            } else {
                                Feel.pick()
                                scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                            }
                        },
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                    ) {
                        Text(if (last) Lang.text("Начать") else Lang.text("Дальше"), style = MaterialTheme.typography.titleMedium)
                    }
                }
            }
        }
    }
}

@Composable
private fun TourPage(page: Tour.Page, shown: Boolean) {
    val bounce = remember { Animatable(1f) }
    LaunchedEffect(shown) {
        if (!shown || Effects.still) return@LaunchedEffect
        bounce.snapTo(0.8f)
        bounce.animateTo(1f, Motion.appear)
    }
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp, Alignment.CenterVertically),
    ) {
        Plate(Modifier.size(96.dp), shape = CircleShape) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    painterResource(page.icon.drawable()), null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(44.dp).graphicsLayer {
                        scaleX = bounce.value
                        scaleY = bounce.value
                    },
                )
            }
        }
        Text(page.title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        Text(page.text, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
        Spacer(Modifier.height(60.dp))
    }
}

@Composable
private fun Dots(count: Int, current: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
        repeat(count) { index ->
            Box(
                Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(
                        if (index == current) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f),
                    ),
            )
        }
    }
}

/** Активити под контекстом Compose — для системного окна замка. */
fun Context.activity(): FragmentActivity? {
    var context: Context? = this
    while (context is ContextWrapper) {
        if (context is FragmentActivity) return context
        context = context.baseContext
    }
    return null
}

/** Сад заперт: поверх всего, касания не пропускает. */
@Composable
fun LockScreen() {
    val context = LocalContext.current
    val activity = context.activity()
    LaunchedEffect(Unit) { activity?.let { Lock.unlock(it) } }
    Box(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {},
    ) {
        SproutBackground()
        Column(
            Modifier.fillMaxSize().padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
        ) {
            Plate(Modifier.size(72.dp), shape = CircleShape) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(painterResource(R.drawable.ic_lock_fill), null, Modifier.size(34.dp))
                }
            }
            Text(Lang.text("Сад заперт"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
            FilledTonalButton(onClick = { activity?.let { Lock.unlock(it) } }, enabled = !Lock.asking) {
                Text(Lang.text("Открыть"))
            }
        }
    }
}

/**
 * Заставка: «Добро пожаловать» проявляется из дымки, логотип дорастает лист
 * за листом. Цвет — как у системной заставки Android, переход не виден.
 */
@Composable
fun Welcome() {
    val palette = LocalPalette.current
    val owner = LocalSprout.current.garden.owner
    val hello = remember { Animatable(if (Effects.still) 1f else 0f) }
    val mark = remember { Animatable(if (Effects.still) 1f else 0f) }
    LaunchedEffect(Unit) {
        if (Effects.still) return@LaunchedEffect
        delay(30)
        launch { hello.animateTo(1f, Motion.enter) }
        delay((Motion.WELCOME_STEP * 1000).toLong())
        mark.animateTo(1f, tween((Motion.LOGO_SECONDS * 1000).toInt(), easing = LinearEasing))
    }
    Box(
        Modifier
            .fillMaxSize()
            .background(palette.welcome)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {},
    ) {
        SproutLogo(342.dp, Modifier.align(Alignment.Center), reveal = mark.value)
        Column(
            Modifier.fillMaxWidth().statusBarsPadding().padding(top = 8.dp, start = 24.dp, end = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(40.dp),
        ) {
            SproutBadge()
            Text(
                Seed.greeting(owner),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
                color = palette.welcomeInk,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .graphicsLayer {
                        alpha = hello.value
                        val scale = Motion.WELCOME_SCALE + (1 - Motion.WELCOME_SCALE) * hello.value
                        scaleX = scale
                        scaleY = scale
                    }
                    .blur((12 * (1 - hello.value)).dp),
            )
        }
    }
}
