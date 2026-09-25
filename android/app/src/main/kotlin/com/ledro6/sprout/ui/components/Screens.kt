package com.ledro6.sprout.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.design.SproutBackground
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Walk

/**
 * Экран второго уровня: узор фона, шапка Material со стрелкой назад и
 * подсказками. Крупная шапка сворачивается при прокрутке, как в
 * приложениях Google.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubScreen(
    title: String,
    onBack: (() -> Unit)?,
    walk: Walk? = null,
    large: Boolean = false,
    actions: @Composable RowScope.() -> Unit = {},
    backdrop: @Composable () -> Unit = { SproutBackground() },
    content: @Composable (PaddingValues) -> Unit,
) {
    val colors = TopAppBarDefaults.topAppBarColors(
        containerColor = Color.Transparent,
        scrolledContainerColor = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.96f),
    )
    val behavior = if (large) TopAppBarDefaults.exitUntilCollapsedScrollBehavior() else TopAppBarDefaults.pinnedScrollBehavior()
    val back: @Composable () -> Unit = {
        if (onBack != null) {
            IconButton(onClick = onBack) {
                Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = Lang.text("Назад"))
            }
        }
    }
    val tools: @Composable RowScope.() -> Unit = {
        actions()
        if (walk != null) WalkButton(walk)
    }
    Box(Modifier.fillMaxSize()) {
        backdrop()
        Scaffold(
            containerColor = Color.Transparent,
            modifier = Modifier.nestedScroll(behavior.nestedScrollConnection),
            topBar = {
                if (large) {
                    LargeTopAppBar(
                        title = { Text(title, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                        navigationIcon = back,
                        actions = tools,
                        scrollBehavior = behavior,
                        colors = colors,
                    )
                } else {
                    TopAppBar(
                        title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        navigationIcon = back,
                        actions = tools,
                        scrollBehavior = behavior,
                        colors = colors,
                    )
                }
            },
            content = { Readable(it, content) },
        )
    }
    if (walk != null) WalkHost(walk)
}

/**
 * Экран вкладки: крупный заголовок, который сворачивается при прокрутке,
 * «?» подсказок и шестерёнка настроек справа.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TabScreen(
    title: String,
    walk: Walk?,
    onSettings: (() -> Unit)?,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    val behavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    Box(Modifier.fillMaxSize()) {
        SproutBackground()
        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = androidx.compose.foundation.layout.WindowInsets(0),
            modifier = Modifier.nestedScroll(behavior.nestedScrollConnection),
            topBar = {
                LargeTopAppBar(
                    title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    actions = {
                        actions()
                        if (walk != null) WalkButton(walk)
                        if (onSettings != null) SproutGear(onSettings)
                    },
                    scrollBehavior = behavior,
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        scrolledContainerColor = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.96f),
                    ),
                )
            },
            content = { Readable(it, content) },
        )
    }
    if (walk != null) WalkHost(walk)
}

/** Содержимое — посередине и не шире читаемого: на планшете строки не растягиваются во весь экран. */
@Composable
private fun Readable(padding: PaddingValues, content: @Composable (PaddingValues) -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Box(Modifier.fillMaxHeight().widthIn(max = Metrics.READABLE_WIDTH.dp).fillMaxWidth()) {
            content(padding)
        }
    }
}
