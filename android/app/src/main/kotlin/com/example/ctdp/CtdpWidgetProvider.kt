package com.example.ctdp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CtdpWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.ctdp_widget).apply {
                // 使用 LaunchIntent 调起 Activity，彻底解决安卓模拟器与系统后台广播崩溃/停止运行的问题
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ctdp://quick_reservation")
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                setOnClickPendingIntent(R.id.widget_button_label, pendingIntent)
                setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}