package com.ledro6.sprout.ui.settings

import android.content.Intent
import android.os.Build
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.ledro6.sprout.BuildConfig
import com.ledro6.sprout.R
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Paragraph
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutLogo
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermCard

/** Страница-текст: шапка со стрелкой и одна плашка с абзацами. */
@Composable
fun Page(title: String, go: Go, content: @Composable ColumnScope.() -> Unit) {
    SubScreen(title, onBack = go::back, large = true) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 40.dp),
        ) {
            Plate(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
            }
        }
    }
}

@Composable
fun AboutScreen(go: Go) {
    val context = LocalContext.current
    Page(Lang.text("Сведения о приложении"), go) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            SproutLogo(44.dp)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Sprout", style = MaterialTheme.typography.titleLarge)
                Text(
                    Lang.text("Напоминалка о поливе комнатных растений"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        SproutDivider()
        Pair(Lang.text("Версия"), "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
        Pair(Lang.text("Система"), Lang.format("Android %@ и новее", "8"))
        Pair("Android", Build.VERSION.RELEASE)
        SproutDivider()
        Paragraph(
            Lang.text(
                "Час сада проходит здесь за секунду настоящего времени: иначе за один сеанс проценты " +
                    "влажности не сдвинулись бы ни на один. По этим же часам считаются и напоминания.",
            ),
            Lang.text("Время идёт быстрее"),
        )
        TextButton(onClick = {
            runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, "https://github.com/ledro6/Sprout".toUri())) }
        }) {
            Text(Lang.text("Исходный код на GitHub"))
            Icon(painterResource(R.drawable.ic_arrow_outward), null, Modifier.padding(start = 6.dp).size(16.dp))
        }
    }
}

@Composable
private fun Pair(name: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(name, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun PrivacyScreen(go: Go) {
    Page(Lang.text("Политика конфиденциальности"), go) {
        Paragraph(Lang.text("Sprout не собирает о вас никаких сведений и никуда их не передаёт."))
        Paragraph(
            Lang.text(
                "Клички растений, виды, влажность, даты — всё, что вы вводите, — лежит в файле внутри " +
                    "приложения, на самом телефоне. Там же настройки. Ничего из этого не покидает устройство.",
            ),
            Lang.text("Что хранится"),
        )
        Paragraph(
            Lang.text("Приложение не выходит в интернет. У него нет ни учётной записи, ни сервера, ни аналитики, ни рекламы."),
            Lang.text("Сеть"),
        )
        Paragraph(
            Lang.text(
                "Наклон телефона чуть двигает узор на фоне. Показания используются только для этого, " +
                    "не сохраняются и никуда не уходят.",
            ),
            Lang.text("Датчик движения"),
        )
        Paragraph(
            Lang.text(
                "Снимки растений распознаются на самом телефоне — фото никуда не отправляются.",
            ),
            Lang.text("Камера и фото"),
        )
        Paragraph(
            Lang.text(
                "Напоминания о поливе создаёт сам телефон по срокам, посчитанным на нём же. " +
                    "Пуш-сервер в этом не участвует.",
            ),
            Lang.text("Уведомления"),
        )
        Paragraph(
            Lang.text(
                "Файл сада попадает в резервную копию Android — туда же, куда и остальные данные " +
                    "приложений, по правилам Google.",
            ),
            Lang.text("Резервная копия"),
        )
        Paragraph(
            Lang.text("Удалите приложение — вместе с ним исчезнет и всё, что оно помнило."),
            Lang.text("Удаление"),
        )
    }
}

@Composable
fun GlossaryScreen(go: Go) {
    Page(Lang.text("Словарик"), go) {
        Term.entries.forEachIndexed { index, term ->
            if (index > 0) SproutDivider()
            TermCard(term)
        }
    }
}
