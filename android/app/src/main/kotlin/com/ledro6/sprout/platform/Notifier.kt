package com.ledro6.sprout.platform

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.ledro6.sprout.MainActivity
import com.ledro6.sprout.R
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Reminder
import com.ledro6.sprout.model.Room
import java.util.concurrent.TimeUnit

/**
 * Напоминания о поливе и уходе. Кого и когда — считает `Reminder`; будит
 * `WorkManager`: переживает и выгрузку приложения, и перезагрузку телефона.
 * У напоминания о поливе — кнопка «Полил»: поливает прямо из шторки.
 */
object Notifier {
    private const val WATERING = "watering"
    private const val CARE = "care"
    const val POUR = "com.ledro6.sprout.POUR"
    const val PLANTS = "plants"
    private const val TITLE = "title"
    private const val TEXT = "text"
    private const val KIND = "kind"
    private const val WATER_ID = 1
    private const val CARE_ID = 2

    /** Каналы — один раз; названия — на языке приложения. */
    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(WATERING, Lang.text("Полив"), NotificationManager.IMPORTANCE_DEFAULT),
        )
        manager.createNotificationChannel(
            NotificationChannel(CARE, Lang.text("Уход"), NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    /** Нужно ли спрашивать разрешение (Android 13+) и дано ли оно. */
    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun schedule(context: Context, rooms: List<Room>, threshold: Double) {
        clear(context)
        if (!allowed(context)) return
        val work = WorkManager.getInstance(context)
        Reminder.next(rooms, threshold)?.let { due ->
            val request = OneTimeWorkRequestBuilder<Ring>()
                .setInitialDelay((due.after * 1000).toLong(), TimeUnit.MILLISECONDS)
                .setInputData(
                    workDataOf(
                        KIND to WATERING,
                        TITLE to Reminder.title,
                        TEXT to Reminder.text(due),
                        PLANTS to due.ids.toTypedArray(),
                    ),
                )
                .build()
            work.enqueueUniqueWork(WATERING, ExistingWorkPolicy.REPLACE, request)
        }
        Reminder.chore(rooms)?.let { chore ->
            val request = OneTimeWorkRequestBuilder<Ring>()
                .setInitialDelay((chore.after * 1000).toLong(), TimeUnit.MILLISECONDS)
                .setInputData(workDataOf(KIND to CARE, TITLE to Reminder.title(chore), TEXT to Reminder.text(chore)))
                .build()
            work.enqueueUniqueWork(CARE, ExistingWorkPolicy.REPLACE, request)
        }
    }

    /** Приложение открыли — ждать нечего: пересчитаем, когда уйдёт с экрана. */
    fun clear(context: Context) {
        runCatching {
            val work = WorkManager.getInstance(context)
            work.cancelUniqueWork(WATERING)
            work.cancelUniqueWork(CARE)
        }
    }

    fun post(context: Context, kind: String, title: String, text: String, plants: List<String>) {
        if (!allowed(context)) return
        register(context)
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val note = NotificationCompat.Builder(context, kind)
            .setSmallIcon(R.drawable.ic_stat_drop)
            .setColor(ContextCompat.getColor(context, R.color.sprout_accent))
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
        if (kind == WATERING && plants.isNotEmpty()) {
            val pour = PendingIntent.getBroadcast(
                context, 1,
                Intent(context, Pour::class.java).setAction(POUR).putExtra(PLANTS, plants.toTypedArray()),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            note.addAction(NotificationCompat.Action.Builder(R.drawable.ic_water_drop_fill, Lang.text("Полил"), pour).build())
        }
        runCatching {
            NotificationManagerCompat.from(context).notify(if (kind == WATERING) WATER_ID else CARE_ID, note.build())
        }
    }

    fun dismissWatering(context: Context) {
        runCatching { NotificationManagerCompat.from(context).cancel(WATER_ID) }
    }

    /** Будильник напоминания: текст готов заранее, остаётся показать. */
    class Ring(context: Context, params: WorkerParameters) : Worker(context, params) {
        override fun doWork(): Result {
            val data = inputData
            post(
                applicationContext,
                data.getString(KIND) ?: WATERING,
                data.getString(TITLE).orEmpty(),
                data.getString(TEXT).orEmpty(),
                data.getStringArray(PLANTS)?.toList().orEmpty(),
            )
            return Result.success()
        }
    }

    /**
     * «Полил» из шторки. Приложение могло быть выгружено — сад читается с
     * файла; могло стоять в фоне — сперва чужие правки (виджет), потом
     * прошедшее время.
     */
    class Pour : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != POUR) return
            val ids = intent.getStringArrayExtra(PLANTS)?.toList().orEmpty()
            val sprout = Sprout.get(context)
            sprout.garden.reload()
            sprout.garden.advance()
            for (id in ids) sprout.garden.water(id)
            dismissWatering(context)
            Widgets.nudge(context)
        }
    }
}
