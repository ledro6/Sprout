package com.ledro6.sprout.model

import kotlin.math.abs
import kotlin.math.floor

/**
 * Округление «как в школе» — половина от нуля, как `rounded()` в Swift.
 * `kotlin.math.round` округляет половину к чётному: 2.5 дня стали бы двумя.
 */
fun Double.rounded(): Double {
    if (isNaN() || isInfinite()) return this
    val whole = floor(abs(this))
    val up = if (abs(this) - whole >= 0.5) whole + 1 else whole
    return if (this < 0) -up else up
}

fun Double.roundedInt(): Int = rounded().toInt()

/** Остаток с тем же знаком, что у делимого, — как `truncatingRemainder`. */
fun Double.remainder(by: Double): Double = this % by
