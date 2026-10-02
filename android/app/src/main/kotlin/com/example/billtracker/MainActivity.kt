package com.example.billtracker

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "repairScheduledNotifications") {
                try {
                    repairScheduledNotifications()
                    result.success(null)
                } catch (error: Exception) {
                    result.error(
                        "notification_cache_repair_failed",
                        error.message,
                        null
                    )
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun repairScheduledNotifications() {
        val preferences = getSharedPreferences(
            SCHEDULED_NOTIFICATIONS,
            Context.MODE_PRIVATE
        )
        val serialized = preferences.getString(SCHEDULED_NOTIFICATIONS, null)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        try {
            if (!serialized.isNullOrBlank()) {
                val notifications = JSONArray(serialized)
                for (index in 0 until notifications.length()) {
                    val notification = notifications.optJSONObject(index) ?: continue
                    if (!notification.has("id")) continue
                    val id = notification.optInt("id")

                    val intent =
                        Intent(this, ScheduledNotificationReceiver::class.java)
                    val flags = PendingIntent.FLAG_NO_CREATE or (
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_IMMUTABLE
                        } else {
                            0
                        }
                    )
                    val pendingIntent =
                        PendingIntent.getBroadcast(this, id, intent, flags)
                    if (pendingIntent != null) {
                        alarmManager.cancel(pendingIntent)
                        pendingIntent.cancel()
                    }
                    notificationManager.cancel(id)
                }
            }
        } catch (error: org.json.JSONException) {
            Log.w("BillTracker", "La caché de recordatorios estaba dañada", error)
            notificationManager.cancelAll()
        } finally {
            val cleared = preferences.edit()
                .putString(SCHEDULED_NOTIFICATIONS, "[]")
                .commit()
            if (!cleared) {
                throw IllegalStateException("No se pudo limpiar la caché de recordatorios.")
            }
        }
    }

    companion object {
        private const val NOTIFICATION_CHANNEL = "billtracker/notifications"
        private const val SCHEDULED_NOTIFICATIONS = "scheduled_notifications"
    }
}
