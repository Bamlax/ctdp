package com.example.ctdp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
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
        private const val CHANNEL_ID = "ctdp_live_updates_channel"
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
            // 规范要求：通知渠道不得具有 IMPORTANCE_MIN，设为 HIGH 以触发状态栏芯片
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "展示专注倒计时与锁屏/状态栏实时更新活动"
                setShowBadge(true)
                setSound(null, null)
                enableVibration(false)
            }
            val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * 遵循谷歌官方实时更新（Promoted Ongoing / Live Updates）规范构建通知
     */
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

        // 规范：大卡片必须为标准样式 BigTextStyle
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(text)
            .setBigContentTitle(title)

        val builder = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(bigTextStyle)
            .setOngoing(true)                      // 规范：必须为 ongoing
            .setGroupSummary(false)                // 规范：不得是群组摘要
            .setColorized(false)                   // 规范：严格禁止 setColorized(true)，否则丧失胶囊资格
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(
                if (category == "alarm") NotificationCompat.CATEGORY_ALARM
                else NotificationCompat.CATEGORY_STOPWATCH
            )

        pendingIntent?.let { builder.setContentIntent(it) }

        // 规范：计时器模式与时间戳配置
        if (useChronometer) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(isCountdown)
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
        } else {
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
        }

        // 规范：申请推广宣传并注入状态条状标签文本（限制 7 字符内）
        val extras = Bundle().apply {
            putBoolean("android.requestPromotedOngoing", true)
            if (!shortText.isNullOrEmpty()) {
                putCharSequence("android.shortCriticalText", shortText)
            }
        }
        builder.addExtras(extras)

        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun dismissLiveUpdateNotification() {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}