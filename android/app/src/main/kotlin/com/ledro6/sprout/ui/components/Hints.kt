package com.ledro6.sprout.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RichTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipAnchorPosition
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Term
import kotlinx.coroutines.launch

/** Значок слова в словарике и в «?». */
fun Term.icon(): Int = when (this) {
    Term.AR -> R.drawable.ic_view_in_ar
    Term.MODEL -> R.drawable.ic_deployed_code
    Term.MOISTURE -> R.drawable.ic_water_drop
    Term.PERIOD -> R.drawable.ic_calendar_month
    Term.SEASONS -> R.drawable.ic_eco
    Term.RHYTHM -> R.drawable.ic_event_repeat
    Term.FEEDING -> R.drawable.ic_auto_awesome
    Term.REPOTTING -> R.drawable.ic_potted_plant
    Term.REMINDERS -> R.drawable.ic_notifications
    Term.PARALLAX -> R.drawable.ic_3d_rotation
    Term.SWAY -> R.drawable.ic_waves
    Term.WAVE -> R.drawable.ic_water
    Term.FROLIC -> R.drawable.ic_celebration
    Term.LOCK -> R.drawable.ic_lock
    Term.TRIP -> R.drawable.ic_flight_takeoff
    Term.ACCURACY -> R.drawable.ic_my_location
    Term.STREAK -> R.drawable.ic_local_fire_department
    Term.ORRERY -> R.drawable.ic_radio_button_checked
    Term.PARADE -> R.drawable.ic_stacks
}

/**
 * «?» рядом с непонятным словом — пояснение всплывает подсказкой Material
 * (RichTooltip) рядом со словом и уходит касанием мимо.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TermHint(term: Term) {
    val state = rememberTooltipState(isPersistent = true)
    val scope = rememberCoroutineScope()
    TooltipBox(
        positionProvider = TooltipDefaults.rememberTooltipPositionProvider(TooltipAnchorPosition.Above),
        tooltip = {
            RichTooltip(title = { Text(term.title) }) { Text(term.meaning) }
        },
        state = state,
    ) {
        // «?» стоит вплотную к слову: в строке он занимает 32 dp, а пальцем
        // ловится по-прежнему на 48 — касание рядом с мелкой кнопкой Compose
        // засчитывает ей сам.
        CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides Dp.Unspecified) {
            IconButton(onClick = { scope.launch { state.show() } }, modifier = Modifier.size(32.dp)) {
                Icon(
                    painterResource(R.drawable.ic_help),
                    contentDescription = Lang.format("Что значит «%@»", term.title),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

/** Слово словарика карточкой: значок, название, пояснение. */
@Composable
fun TermCard(term: Term, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        Icon(painterResource(term.icon()), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(term.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Text(term.meaning, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
