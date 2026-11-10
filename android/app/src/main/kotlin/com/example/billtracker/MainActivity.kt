package com.example.billtracker

import android.app.AlarmManager
import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private var backupSaveResult: MethodChannel.Result? = null
    private var backupBytes: ByteArray? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKUP_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveBackup") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (backupSaveResult != null) {
                result.error("backup_save_in_progress", "Ya hay un guardado en curso.", null)
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")
            if (fileName.isNullOrBlank() || bytes == null) {
                result.error("invalid_backup", "El archivo de backup no es válido.", null)
                return@setMethodCallHandler
            }

            backupBytes = bytes
            backupSaveResult = result
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/zip"
                    putExtra(Intent.EXTRA_TITLE, fileName)
                }
                startActivityForResult(intent, BACKUP_SAVE_REQUEST)
            } catch (error: Exception) {
                backupBytes = null
                backupSaveResult = null
                result.error("backup_save_failed", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BACKUP_SAVE_REQUEST) return

        val result = backupSaveResult ?: return
        val bytes = backupBytes
        backupSaveResult = null
        backupBytes = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri: Uri? = data?.data
        if (uri == null || bytes == null) {
            result.error("backup_save_failed", "No se recibió el destino del archivo.", null)
            return
        }

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("No se pudo abrir el archivo de destino.")
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("backup_save_failed", error.message, null)
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
        private const val BACKUP_CHANNEL = "billtracker/backup"
        private const val BACKUP_SAVE_REQUEST = 4207
        private const val SCHEDULED_NOTIFICATIONS = "scheduled_notifications"
    }
}
