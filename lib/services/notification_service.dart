import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/ctdp_state.dart';

class NotificationService {
  static const int reservationReminderId = 1001;
  static const int fluidCloudNotificationId = 1002;

  // 使用全新 V5 最高等级静音渠道，彻底破除 ColorOS 旧渠道缓存
  static const String fluidCloudChannelId = 'ctdp_fluid_cloud_capsule_v5';
  static const String reminderChannelId = 'ctdp_reminder_channel_v3';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  void Function(String taskId)? onNotificationSelected;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
    } catch (e) {
      debugPrint('Timezone init warning: $e');
    }

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

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // 清理旧版历史低权限渠道
      await android?.deleteNotificationChannel(channelId: 'ctdp_status_channel_v3');
      await android?.deleteNotificationChannel(channelId: 'ctdp_status_channel_v4');
      await android?.deleteNotificationChannel(channelId: 'ctdp_fluid_cloud_capsule_v1');
      await android?.deleteNotificationChannel(channelId: 'ctdp_fluid_cloud_silent_v2');

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
  // 1. OPPO 流体云胶囊：预约倒计时态
  // ============================================================
  Future<void> showReservationCapsule({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final targetTimeStr =
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';

    final androidDetails = AndroidNotificationDetails(
      fluidCloudChannelId,
      'CTDP 实时流体云胶囊',
      channelDescription: '适配 OPPO ColorOS 状态栏胶囊与锁屏实时活动',
      importance: Importance.max, // 关键：ColorOS 流体云胶囊必须要求 MAX/HIGH 级别
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      sound: null,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: deadline.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      category: AndroidNotificationCategory.alarm,
      subText: '预约中', // 胶囊状态栏紧凑文本
      ticker: '预约中',
      color: const Color(0xFF1976D2),
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id: fluidCloudNotificationId,
      title: '预约中: $taskTitle',
      body: '将于 $targetTimeStr 自动进入专注',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  // ============================================================
  // 2. OPPO 流体云胶囊：执行态（倒计时 / 正计时）
  // ============================================================
  Future<void> showFocusSessionCapsule({
    required String taskId,
    required String taskTitle,
    required TaskTimerMode timerMode,
    required DateTime startedAt,
    required int durationSeconds,
    required int totalPausedSeconds,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final isCountdown = timerMode == TaskTimerMode.countDown;
    int whenEpoch;

    if (isCountdown) {
      // 倒计时截止点 = 开始时间 + 计划时长 + 累计暂停补偿
      whenEpoch = startedAt
          .add(Duration(seconds: durationSeconds + totalPausedSeconds))
          .millisecondsSinceEpoch;
    } else {
      // 正计时基准点
      whenEpoch = startedAt
          .add(Duration(seconds: totalPausedSeconds))
          .millisecondsSinceEpoch;
    }

    final androidDetails = AndroidNotificationDetails(
      fluidCloudChannelId,
      'CTDP 实时流体云胶囊',
      channelDescription: '适配 OPPO ColorOS 状态栏胶囊与锁屏实时活动',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      sound: null,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: whenEpoch,
      usesChronometer: true,
      chronometerCountDown: isCountdown,
      category: AndroidNotificationCategory.stopwatch,
      subText: isCountdown ? '专注中' : '正计时',
      ticker: isCountdown ? '专注中' : '正计时',
      color: const Color(0xFF1976D2),
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id: fluidCloudNotificationId,
      title: '专注中: $taskTitle',
      body: isCountdown ? '保持专注，决不玷污神圣座位' : '正计时进行中',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  // ============================================================
  // 3. OPPO 流体云胶囊：暂停态（停止 Chronometer，胶囊显示“已暂停”）
  // ============================================================
  Future<void> showPausedCapsule({
    required String taskId,
    required String taskTitle,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final androidDetails = const AndroidNotificationDetails(
      fluidCloudChannelId,
      'CTDP 实时流体云胶囊',
      channelDescription: '适配 OPPO ColorOS 状态栏胶囊与锁屏实时活动',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      sound: null,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      usesChronometer: false, // 暂停时必须关闭计时跳动
      category: AndroidNotificationCategory.stopwatch,
      subText: '已暂停', // ColorOS 胶囊右侧文本槽（B*）强制映射此内容
      ticker: '已暂停',
      color: Color(0xFFEF6C00), // 暂停警示橙
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id: fluidCloudNotificationId,
      title: '已暂停: $taskTitle',
      body: '专注已暂停 · 点击返回继续',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  // ============================================================
  // 4. OPPO 流体云胶囊：超时态（正向递增显示超时时长）
  // ============================================================
  Future<void> showOvertimeCapsule({
    required String taskId,
    required String taskTitle,
    required DateTime plannedEndTime,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      fluidCloudChannelId,
      'CTDP 实时流体云胶囊',
      channelDescription: '适配 OPPO ColorOS 状态栏胶囊与锁屏实时活动',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      sound: null,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: plannedEndTime.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: false, // 超时后作为正计时递增
      category: AndroidNotificationCategory.stopwatch,
      subText: '已超时',
      ticker: '已超时',
      color: const Color(0xFFC62828), // 警戒红
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id: fluidCloudNotificationId,
      title: '⚠️ 已超时: $taskTitle',
      body: '专注时长已达成，正在记录超时投入',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  Future<void> cancelFluidCloudCapsule() async {
    if (!_initialized) return;
    await _plugin.cancel(id: fluidCloudNotificationId);
  }

  // ============================================================
  // 定时到期系统强提醒
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
        reminderChannelId,
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