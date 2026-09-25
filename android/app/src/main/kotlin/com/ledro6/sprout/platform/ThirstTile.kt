package com.ledro6.sprout.platform

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.ledro6.sprout.MainActivity
import com.ledro6.sprout.R
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Thirst

/**
 * Плитка в быстрых настройках: сколько растений ждут воды. Горит, если хоть
 * одному пора; нажатие открывает сад.
 */
class ThirstTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val garden = Sprout.get(this).garden
        garden.reload()
        val count = garden.plants.count { it.thirst == Thirst.ALARM }
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_drop)
        tile.label = Lang.text("Ждут воды")
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = Lang.format("%lld растений", count)
        tile.contentDescription = "${Lang.text("Ждут воды")}: ${Lang.format("%lld растений", count)}"
        tile.state = if (count > 0) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
