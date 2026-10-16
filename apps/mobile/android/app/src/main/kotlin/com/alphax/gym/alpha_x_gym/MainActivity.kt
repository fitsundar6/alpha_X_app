package com.alphax.gym.alpha_x_gym

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * Pre-registers High-Importance Android Notification Channels.
     * Android 8.0+ (API 26+) requires channels with IMPORTANCE_HIGH to display
     * heads-up popup banners and play notification sound.
     *
     * Adheres to Android channel immutability: existing channels are inspected
     * and preserved without overwriting user customizations.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val vibrationPattern = longArrayOf(0, 250, 250, 250)

            // Channels to configure with High Importance (heads-up banner + sound)
            val channelsToCreate = listOf(
                Triple(
                    "alpha_x_alerts",
                    "Alpha X Gym Alerts",
                    "High-priority workout, coach, and nutrition alerts"
                ),
                Triple(
                    "alpha_x_announcements",
                    "Alpha X Gym Announcements",
                    "Gym news, events, and important broadcast updates"
                )
            )

            for ((channelId, channelName, channelDesc) in channelsToCreate) {
                // If the channel has not been created yet, initialize it with IMPORTANCE_HIGH
                if (notificationManager.getNotificationChannel(channelId) == null) {
                    val channel = NotificationChannel(
                        channelId,
                        channelName,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = channelDesc
                        enableLights(true)
                        enableVibration(true)
                        this.vibrationPattern = vibrationPattern
                        setSound(defaultSoundUri, audioAttributes)
                        setShowBadge(true)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    }
                    notificationManager.createNotificationChannel(channel)
                }
            }
        }
    }
}
