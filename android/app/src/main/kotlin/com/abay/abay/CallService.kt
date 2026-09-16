package com.abay.abay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Foreground service that keeps SIP alive in background and shows
 * incoming / ongoing call notifications (Zoiper-style).
 */
class CallService : Service() {

    companion object {
        const val CHANNEL_ID = "abay_calls"
        const val CHANNEL_REG_ID = "abay_status"
        const val NOTIF_REGISTERED = 1001
        const val NOTIF_INCOMING = 1002
        const val NOTIF_ONGOING = 1003

        const val ACTION_START = "com.abay.abay.START"
        const val ACTION_STOP = "com.abay.abay.STOP"
        const val ACTION_STATUS = "com.abay.abay.STATUS"
        const val ACTION_INCOMING = "com.abay.abay.INCOMING"
        const val ACTION_ONGOING = "com.abay.abay.ONGOING"
        const val ACTION_CLEAR = "com.abay.abay.CLEAR"
        const val ACTION_ANSWER = "com.abay.abay.ANSWER"
        const val ACTION_REJECT = "com.abay.abay.REJECT"

        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        fun start(ctx: Context) {
            val i = Intent(ctx, CallService::class.java).setAction(ACTION_START)
            ContextCompat.startForegroundService(ctx, i)
        }

        fun stop(ctx: Context) {
            val i = Intent(ctx, CallService::class.java).setAction(ACTION_STOP)
            ctx.startService(i)
        }

        fun notifyRegistered(ctx: Context, title: String, text: String) {
            val i = Intent(ctx, CallService::class.java)
                .setAction(ACTION_STATUS)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            ctx.startService(i)
        }

        fun notifyIncoming(ctx: Context, title: String, text: String) {
            val i = Intent(ctx, CallService::class.java)
                .setAction(ACTION_INCOMING)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            ContextCompat.startForegroundService(ctx, i)
        }

        fun notifyOngoing(ctx: Context, title: String, text: String) {
            val i = Intent(ctx, CallService::class.java)
                .setAction(ACTION_ONGOING)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            ContextCompat.startForegroundService(ctx, i)
        }

        fun clearCallNotifications(ctx: Context) {
            val i = Intent(ctx, CallService::class.java).setAction(ACTION_CLEAR)
            ctx.startService(i)
        }
    }

    private var running = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming and ongoing SIP calls"
                enableVibration(true)
                setSound(null, null)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_REG_ID,
                "Registration",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Softphone registration status"
            }
        )
    }

    private fun openAppIntent(flags: Int = 0): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        } ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE or flags
        )
    }

    private fun actionIntent(action: String, req: Int): PendingIntent {
        val i = Intent(this, CallService::class.java).setAction(action)
        return PendingIntent.getService(
            this,
            req,
            i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun baseNotification(
        title: String,
        text: String,
        channelId: String = CHANNEL_ID
    ): NotificationCompat.Builder {
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openAppIntent())
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, null -> {
                if (!running) {
                    val n = baseNotification(
                        "Abay softphone",
                        "SIP service running",
                        CHANNEL_REG_ID
                    )
                        .setOngoing(true)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .build()
                    startForeground(NOTIF_REGISTERED, n)
                    running = true
                }
            }
            ACTION_STATUS -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Abay"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
                val n = baseNotification(title, text, CHANNEL_REG_ID)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .build()
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIF_REGISTERED, n)
                if (!running) {
                    startForeground(NOTIF_REGISTERED, n)
                    running = true
                }
            }
            ACTION_INCOMING -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Incoming call"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
                val builder = baseNotification(title, text)
                    .setAutoCancel(false)
                    .setOngoing(true)
                    .setFullScreenIntent(openAppIntent(), true)
                    .addAction(
                        android.R.drawable.sym_action_call,
                        "Answer",
                        actionIntent(ACTION_ANSWER, 11)
                    )
                    .addAction(
                        android.R.drawable.sym_call_missed,
                        "Decline",
                        actionIntent(ACTION_REJECT, 12)
                    )
                val n = builder.build()
                if (!running) {
                    startForeground(NOTIF_INCOMING, n)
                    running = true
                } else {
                    val nm = getSystemService(NotificationManager::class.java)
                    nm.notify(NOTIF_INCOMING, n)
                }
            }
            ACTION_ONGOING -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "On call"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
                val n = baseNotification(title, text)
                    .setOngoing(true)
                    .build()
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIF_ONGOING, n)
                if (!running) {
                    startForeground(NOTIF_ONGOING, n)
                    running = true
                }
            }
            ACTION_CLEAR -> {
                val nm = getSystemService(NotificationManager::class.java)
                nm.cancel(NOTIF_INCOMING)
                nm.cancel(NOTIF_ONGOING)
            }
            ACTION_ANSWER -> {
                CallServiceBridge.onAnswer?.invoke()
            }
            ACTION_REJECT -> {
                CallServiceBridge.onReject?.invoke()
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }
}

/** Set from Dart via plugin channel so service actions reach SipService. */
object CallServiceBridge {
    @JvmStatic var onAnswer: (() -> Unit)? = null
    @JvmStatic var onReject: (() -> Unit)? = null
}
