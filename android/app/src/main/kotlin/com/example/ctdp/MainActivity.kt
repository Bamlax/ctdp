package com.example.ctdp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LIVE_UPDATES_CHANNEL = "com.example.ctdp/live_updates"

    companion object {
        private const val NOTIFICATION_ID = 2026
        // 升级渠道 ID，清除系统对旧渠道的横幅展开缓存
        private const val CHANNEL_ID = "ctdp_live_updates_v2"
        private const val CHANNEL_NAME = "CTDP 实时更新通知"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_UPDATES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showLiveUpdate" -> {
                    val title = call.argument<String>("title") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val shortText = call.argument<String>("shortText")
                    val whenTime = call.argument<Long>("whenTime") ?: 0L
                    val useChronometer = call.argument<Boolean>("useChronometer") ?: false
                    val isCountdown = call.argument<Boolean>("isCountdown") ?: false
                    val category = call.argument<String>("category") ?: "stopwatch"

                    postLiveUpdateNotification(
                        title = title,
                        text = text,
                        shortText = shortText,
                        whenTime = whenTime,
                        useChronometer = useChronometer,
                        isCountdown = isCountdown,
                        category = category
                    )
                    result.success(true)
                }
                "dismissLiveUpdate" -> {
                    dismissLiveUpdateNotification()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 删除旧版会触发横幅弹窗展开的高优先级渠道
            manager.deleteNotificationChannel("ctdp_live_updates_channel")

            // 规范要求：不得为 IMPORTANCE_MIN。使用 IMPORTANCE_DEFAULT 满足实时更新，同时彻底杜绝自动弹横幅展开
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "展示专注倒计时与锁屏/状态栏实时活动"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun postLiveUpdateNotification(
        title: String,
        text: String,
        shortText: String?,
        whenTime: Long,
        useChronometer: Boolean,
        isCountdown: Boolean,
        category: String
    ) {
        ensureNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                applicationContext,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(text)
            .setBigContentTitle(title)

        val builder = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(bigTextStyle)
            .setOngoing(true)
            .setGroupSummary(false)
            .setColorized(false)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            // 关键点：设置为静默 + DEFAULT 优先级，杜绝屏幕上方弹出浮动横幅大卡片
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(
                if (category == "alarm") NotificationCompat.CATEGORY_ALARM
                else NotificationCompat.CATEGORY_STOPWATCH
            )

        pendingIntent?.let { builder.setContentIntent(it) }

        if (useChronometer) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(isCountdown)
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
        } else {
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
        }

        // 注入实时更新标识与状态条状标签文本（限制 7 字符以内）
        val extras = Bundle().apply {
            putBoolean("android.requestPromotedOngoing", true)
            if (!shortText.isNullOrEmpty()) {
                putCharSequence("android.shortCriticalText", shortText)
            }
        }
        builder.addExtras(extras)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun dismissLiveUpdateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}