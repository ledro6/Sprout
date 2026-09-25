package com.ledro6.sprout.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.Motion

/**
 * Ступень входа: после заставки элемент поднимается на место и наводится на
 * резкость — узор, заголовок, комнаты, сетка, вкладки. Размытие — на
 * Android 12+; раньше элемент просто проявляется.
 */
@Composable
fun Modifier.enter(step: Int): Modifier {
    val shown by animateFloatAsState(if (Effects.step >= step) 1f else 0f, Motion.enter, label = "вход")
    if (shown >= 1f) return this
    return this
        .graphicsLayer {
            alpha = shown
            translationY = Motion.ENTER_RISE * density * (1 - shown)
        }
        .blur((12 * (1 - shown)).dp)
}
