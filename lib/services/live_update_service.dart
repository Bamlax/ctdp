import 'package:flutter/services.dart';
import '../models/ctdp_state.dart';

class LiveUpdateService {
  static const MethodChannel _channel = MethodChannel('com.example.ctdp/live_updates');

  /// 1. 预约态：状态栏胶囊显示倒计时，标签短文本传达“预约中”
  static Future<void> showReservation({
    required String taskTitle,
    required DateTime deadline,
    required int taskNum,
  }) async {
    final targetTimeStr =
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';

    try {
      await _channel.invokeMethod('showLiveUpdate', {
        'title': '预约中: #$taskNum $taskTitle',
        'text': '将于 $targetTimeStr 自动进入专注',
        'shortText': '预约中', // 3 字符，符合胶囊 <= 7 字符规范
        'whenTime': deadline.millisecondsSinceEpoch,
        'useChronometer': true,
        'isCountdown': true,
        'category': 'alarm',
      });
    } catch (_) {}
  }

  /// 2. 专注执行态：胶囊芯片自动跳字
  static Future<void> showFocusing({
    required String taskTitle,
    required TaskTimerMode timerMode,
    required DateTime startedAt,
    required int durationSeconds,
    required int totalPausedSeconds,
    required int taskNum,
  }) async {
    final isCountdown = timerMode == TaskTimerMode.countDown;
    int whenEpoch;

    if (isCountdown) {
      whenEpoch = startedAt
          .add(Duration(seconds: durationSeconds + totalPausedSeconds))
          .millisecondsSinceEpoch;
    } else {
      whenEpoch = startedAt
          .add(Duration(seconds: totalPausedSeconds))
          .millisecondsSinceEpoch;
    }

    try {
      await _channel.invokeMethod('showLiveUpdate', {
        'title': '#$taskNum $taskTitle',
        'text': isCountdown ? '保持专注，决不玷污神圣座位' : '正计时进行中',
        'shortText': isCountdown ? '专注' : '正计时', // 2~3 字符
        'whenTime': whenEpoch,
        'useChronometer': true,
        'isCountdown': isCountdown,
        'category': 'stopwatch',
      });
    } catch (_) {}
  }

  /// 3. 暂停态：停止计时跳字，状态栏胶囊直接稳定呈现“已暂停”
  static Future<void> showPaused({
    required String taskTitle,
    required int taskNum,
  }) async {
    try {
      await _channel.invokeMethod('showLiveUpdate', {
        'title': '#$taskNum $taskTitle (已暂停)',
        'text': '专注中途暂停 · 点击返回应用继续',
        'shortText': '已暂停', // 3 字符
        'whenTime': 0,
        'useChronometer': false,
        'isCountdown': false,
        'category': 'stopwatch',
      });
    } catch (_) {}
  }

  /// 4. 超时态：计时器转为正向递增，胶囊显示“已超时”
  static Future<void> showOvertime({
    required String taskTitle,
    required DateTime plannedEndTime,
    required int taskNum,
  }) async {
    try {
      await _channel.invokeMethod('showLiveUpdate', {
        'title': '⚠️ 已超时: #$taskNum $taskTitle',
        'text': '专注目标时长已达成，正在记录额外投入',
        'shortText': '已超时', // 3 字符
        'whenTime': plannedEndTime.millisecondsSinceEpoch,
        'useChronometer': true,
        'isCountdown': false,
        'category': 'stopwatch',
      });
    } catch (_) {}
  }

  /// 销毁清除实时更新
  static Future<void> dismiss() async {
    try {
      await _channel.invokeMethod('dismissLiveUpdate');
    } catch (_) {}
  }
}