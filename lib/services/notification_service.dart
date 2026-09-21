import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/ctdp_state.dart';

class NotificationService {
  static const int reservationReminderId = 1001;
  static const int ongoingStatusNotificationId = 1002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  void Function(String taskId)? onNotificationSelected;

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. 初始化时区数据，加入异常降级保证不会阻塞后续逻辑
    try {
      tz.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      } catch (e) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
    } catch (e) {
      debugPrint('Timezone init warning: $e');
    }

    // 2. 正确指定 @mipmap/ic_launcher 图标
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            onNotificationSelected?.call(payload);
          }
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
      _initialized = false;
    }
  }

  Future<String?> getInitialPayload() async {
    if (!_initialized) await initialize();
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? false;
  }

  // ============================================================
  // 常驻通知栏：专注执行进度 (使用原生 Chronometer 自动刷新)
  // ============================================================

  Future<void> showActiveSessionNotification({
    required String taskId,
    required String taskTitle,
    required TaskTimerMode timerMode,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final isCountdown = timerMode == TaskTimerMode.countDown;
    final whenEpoch = isCountdown
        ? startedAt.add(Duration(seconds: durationSeconds)).millisecondsSinceEpoch
        : startedAt.millisecondsSinceEpoch;

    // 此处不能使用 const，因为 whenEpoch 与 isCountdown 为运行时动态计算值
    final androidDetails = AndroidNotificationDetails(
      'ctdp_status_channel_v3',
      'CTDP 专注与预约状态',
      channelDescription: '显示当前正在进行的专注或预约倒计时状态',
      importance: Importance.defaultImportance,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: whenEpoch,
      icon: '@mipmap/ic_launcher',
      usesChronometer: true,
      chronometerCountDown: isCountdown,
    );

    await _plugin.show(
      id: ongoingStatusNotificationId,
      title: '神圣座位专注中: $taskTitle',
      body: isCountdown ? '倒计时专注中，点击返回应用' : '正计时进行中，点击返回应用',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  // ============================================================
  // 常驻通知栏：辅助链预约进度
  // ============================================================

  Future<void> showActiveReservationNotification({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'ctdp_status_channel_v3',
      'CTDP 专注与预约状态',
      channelDescription: '显示当前正在进行的专注或预约倒计时状态',
      importance: Importance.defaultImportance,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: deadline.millisecondsSinceEpoch,
      icon: '@mipmap/ic_launcher',
      usesChronometer: true,
      chronometerCountDown: true,
    );

    await _plugin.show(
      id: ongoingStatusNotificationId,
      title: '预约准备缓冲中: $taskTitle',
      body: '预约倒计时结束后将自动进入专注任务',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  Future<void> cancelActiveStatusNotification() async {
    if (!_initialized) return;
    await _plugin.cancel(id: ongoingStatusNotificationId);
  }

  // ============================================================
  // 定时强提醒通知：预约时间已到
  // ============================================================

  Future<void> scheduleReservation({
    required DateTime deadline,
    required String taskName,
    required String taskId,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    await cancelReservationReminder();

    final scheduledDate = tz.TZDateTime.from(deadline, tz.local);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'ctdp_reminder_channel_v3',
        'CTDP 到期提醒',
        channelDescription: '预约与专注时间到达时的系统提示',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.zonedSchedule(
      id: reservationReminderId,
      title: 'CTDP 预约准备时间已到',
      body: '任务「$taskName」已就绪，已为您自动进入专注。',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexact,
      payload: taskId,
    );
  }

  Future<void> cancelReservationReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(id: reservationReminderId);
  }
}