package com.example.ai_watch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ThinkingStatusService : Service() {
    companion object {
        private const val CHANNEL_ID = "oleksandrai_thinking_status"
        private const val CHANNEL_NAME = "OleksandrAI Thinking"
        private const val NOTIFICATION_ID = 1107

        const val ACTION_START = "com.example.ai_watch.action.START_THINKING"
        const val ACTION_STOP = "com.example.ai_watch.action.STOP_THINKING"
        const val EXTRA_LABEL = "extra_label"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            else -> {
                val label = intent?.getStringExtra(EXTRA_LABEL)
                    ?.takeIf { it.isNotBlank() }
                    ?: "Thinking..."
                startForegroundWithNotification(label)
                return START_STICKY
            }
        }
    }

    private fun startForegroundWithNotification(label: String) {
        ensureChannel()
        val now = System.currentTimeMillis()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("OleksandrAI")
            .setContentText(label)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setWhen(now)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows how long OleksandrAI is thinking in background"
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannel(channel)
    }
}
