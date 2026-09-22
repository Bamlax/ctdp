package com.example.ctdp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class LiveUpdatePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val CHANNEL_NAME = "com.example.ctdp/live_updates"
        private const val NOTIFICATION_ID = 2026
        private const val CHANNEL_ID = "ctdp_live_updates_channel"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        createNotificationChannel()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "showLiveUpdate" -> {
                val title = call.argument<String>("title") ?: ""
                val text = call.argument<String>("text") ?: ""
                val shortText = call.argument<String>("shortText") // 状态条状标签文本（如：已暂停/已超时）
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
                dismissNotification()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 实时更新通知渠道不得具有 IMPORTANCE_MIN
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CTDP 实时更新",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "展示专注倒计时与实时活动状态"
                setShowBadge(true)
                setSound(null, null)
                enableVibration(false)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
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
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 规范：必须为标准样式 BigTextStyle
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(text)
            .setBigContentTitle(title)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setStyle(bigTextStyle)
            .setOngoing(true)                     // 规范：必须为 ongoing
            .setGroupSummary(false)               // 规范：不得是群组摘要
            .setColorized(false)                  // 规范：严禁设置 setColorized(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(
                if (category == "alarm") NotificationCompat.CATEGORY_ALARM
                else NotificationCompat.CATEGORY_STOPWATCH
            )

        // 规范：计时器模式配置
        if (useChronometer) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(isCountdown)
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
        } else {
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
        }

        // 规范：申请推广宣传（Promoted Ongoing）与设置状态条状标签（Short Critical Text）
        val extras = Bundle().apply {
            // 请求宣传提升（适配 Android 15/16 及各厂商实时活动/流体云）
            putBoolean("android.requestPromotedOngoing", true)
            // 状态胶囊文本（限制在 7 个字符以内）
            if (!shortText.isNullOrEmpty()) {
                putCharSequence("android.shortCriticalText", shortText)
            }
        }
        builder.addExtras(extras)

        // 兼容 Android 16 API 反射调用官方方法
        try {
            val reqMethod = builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
            reqMethod.invoke(builder, true)
        } catch (_: Exception) {}

        if (!shortText.isNullOrEmpty()) {
            try {
                val shortMethod = builder.javaClass.getMethod("setShortCriticalText", CharSequence::class.java)
                shortMethod.invoke(builder, shortText)
            } catch (_: Exception) {}
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun dismissNotification() {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}