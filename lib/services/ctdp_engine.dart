import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ctdp_state.dart';
import 'notification_service.dart';

class CtdpController extends ChangeNotifier {
  CtdpController({
    StorageService? storage,
    NotificationService? notifications,
  })  : _storage = storage ?? StorageService(),
        _notifications = notifications ?? NotificationService();

  final StorageService _storage;
  final NotificationService _notifications;

  NotificationService get notifications => _notifications;

  CtdpState _state = CtdpState.initial();
  bool _initialized = false;

  bool get initialized => _initialized;
  CtdpState get state => _state;
  CtdpSettings get settings => _state.settings;
  List<CtdpFolder> get folders => _state.folders;
  List<CtdpTask> get tasks => _state.tasks;
  List<CtdpFailureRecord> get failures => _state.failures;
  CtdpSession? get activeSession => _state.activeSession;
  CtdpReservation? get activeReservation => _state.activeReservation;
  bool get hasActiveSession => activeSession != null;
  bool get hasActiveReservation => activeReservation != null;

  List<CtdpTask> get completedTasks {
    return tasks.where((t) => t.isCompleted).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }

  int get activeStreakLength {
    final ordered = getGlobalOrderedTasks();
    int count = 0;
    for (final t in ordered) {
      if (t.isCompleted) {
        if (t.isChainEnd) {
          count = 0;
        } else {
          count++;
        }
      } else if (t.isFailed) {
        count = 0;
      }
    }
    return count;
  }

  int get todayFocusSeconds {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    int total = 0;
    for (final task in completedTasks) {
      if (task.completedAt != null && task.completedAt!.isAfter(todayStart)) {
        total += task.durationSeconds + task.overtimeSeconds;
      }
    }
    return total;
  }

  int get weekFocusSeconds {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    int total = 0;
    for (final task in completedTasks) {
      if (task.completedAt != null && task.completedAt!.isAfter(weekStart)) {
        total += task.durationSeconds + task.overtimeSeconds;
      }
    }
    return total;
  }

  CtdpTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  CtdpFolder? folderById(String id) {
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  List<CtdpTask> getGlobalOrderedTasks() {
    final ordered = <CtdpTask>[];

    void traverseFolder(String? parentId) {
      final subFolders = folders
          .where((f) => f.parentId == parentId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final folder in subFolders) {
        final folderTasks = tasksInFolder(folder.id);
        ordered.addAll(folderTasks);
        traverseFolder(folder.id);
      }
    }

    traverseFolder(null);

    final existingIds = ordered.map((e) => e.id).toSet();
    for (final t in tasks) {
      if (!existingIds.contains(t.id)) {
        ordered.add(t);
      }
    }

    return ordered;
  }

  Map<String, int> getGlobalTaskNumbers() {
    final orderedTasks = getGlobalOrderedTasks();
    final Map<String, int> result = {};

    int runningCount = 1;

    for (final task in orderedTasks) {
      if (task.isCompleted) {
        final num = task.completedChainNumber ?? runningCount;
        result[task.id] = num;
        if (task.isChainEnd) {
          runningCount = 1;
        } else {
          runningCount = num + 1;
        }
      } else if (task.isFailed) {
        final num = task.completedChainNumber ?? runningCount;
        result[task.id] = num;
        runningCount = 1;
      } else {
        result[task.id] = runningCount;
        runningCount++;
      }
    }
    return result;
  }

  int getTaskNumber(CtdpTask task) {
    final numbers = getGlobalTaskNumbers();
    return numbers[task.id] ?? 1;
  }

  bool isLastCompletedTaskOfChain(CtdpTask task) {
    if (!task.isCompleted || task.isChainEnd) return false;
    final ordered = getGlobalOrderedTasks();
    final idx = ordered.indexWhere((t) => t.id == task.id);
    if (idx == -1) return false;

    for (int i = idx + 1; i < ordered.length; i++) {
      final next = ordered[i];
      if (next.isCompleted) return false;
      if (next.isFailed) break;
    }
    return true;
  }

  Future<void> concludeChain(String taskId) async {
    _state = _state.copyWith(
      tasks: tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(isChainEnd: true);
      }).toList(),
    );
    await _persist();
  }

  CtdpTask? getFirstPendingTask() {
    final ordered = getGlobalOrderedTasks();
    for (final t in ordered) {
      if (t.isPending) return t;
    }
    return null;
  }

  Future<String?> startQuickReservationForFirstTask() async {
    if (hasActiveSession) {
      throw StateError('已有任务正在执行中。');
    }
    if (hasActiveReservation) {
      throw StateError('已有预约正在进行中。');
    }

    final targetTask = getFirstPendingTask();
    if (targetTask == null) {
      throw StateError('当前没有待办任务，请先创建待办。');
    }

    final delay = targetTask.appointmentMinutes > 0
        ? targetTask.appointmentMinutes
        : (settings.defaultAppointmentMinutes > 0 ? settings.defaultAppointmentMinutes : 15);

    await createReservation(
      taskId: targetTask.id,
      delayMinutes: delay,
    );

    return targetTask.title;
  }

  // ============================================================
  // 核心修复：任务树中跨文件夹任意移动待办任务
  // 同步立即刷新状态避免卡顿闪烁，并保证未完成任务不侵入历史区间
  // ============================================================

  Future<void> moveTaskInTree({
    required String taskId,
    required String targetFolderId,
    required int targetIndexInFolder,
  }) async {
    final task = taskById(taskId);
    if (task == null || !task.isPending) return;

    final folderTasks = tasks.where((t) => t.folderId == targetFolderId && t.id != taskId).toList();

    // 严密安全防线：未完成任务绝不允许排入已完成或失败节点之前
    int minPendingIndex = 0;
    while (minPendingIndex < folderTasks.length && !folderTasks[minPendingIndex].isPending) {
      minPendingIndex++;
    }

    int finalIndex = targetIndexInFolder;
    if (finalIndex < minPendingIndex) {
      finalIndex = minPendingIndex;
    }
    if (finalIndex > folderTasks.length) {
      finalIndex = folderTasks.length;
    }

    final updatedTask = task.copyWith(folderId: targetFolderId);
    folderTasks.insert(finalIndex, updatedTask);

    final updatedTasksList = <CtdpTask>[];
    for (final f in folders) {
      if (f.id == targetFolderId) {
        updatedTasksList.addAll(folderTasks);
      } else {
        updatedTasksList.addAll(tasks.where((t) => t.folderId == f.id && t.id != taskId));
      }
    }
    updatedTasksList.addAll(tasks.where((t) => t.folderId == null && t.id != taskId));

    // 同步立即更新内存与通知 UI，消除闪烁等待
    _state = _state.copyWith(tasks: updatedTasksList);
    notifyListeners();
    await _storage.saveState(_state);
  }

  int folderHeight(String folderId) {
    final children = folders.where((f) => f.parentId == folderId).toList();
    if (children.isEmpty) return 0;
    int maxChild = 0;
    for (final child in children) {
      final h = folderHeight(child.id);
      if (h > maxChild) maxChild = h;
    }
    return maxChild + 1;
  }

  String folderPrefix(String folderId) {
    final folder = folderById(folderId);
    if (folder == null) return '##1';

    final h = folderHeight(folderId);
    final hashes = List.filled(h + 2, '#').join();

    final siblings = folders.where((f) => f.parentId == folder.parentId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final index = siblings.indexWhere((f) => f.id == folderId);
    final number = index >= 0 ? index + 1 : 1;

    return '$hashes$number';
  }

  List<CtdpFolderOption> getFolderOptions() {
    final result = <CtdpFolderOption>[];

    void walk(String? parentId) {
      final children = folders
          .where((folder) => folder.parentId == parentId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final folder in children) {
        result.add(
          CtdpFolderOption(
            id: folder.id,
            label: '${folderPrefix(folder.id)} ${folder.name}',
          ),
        );
        walk(folder.id);
      }
    }

    walk(null);
    return result;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _notifications.initialize();
    _state = await _storage.loadState();
    _initialized = true;
    await syncRuntime(notify: false);
    notifyListeners();
  }

  // 关键修复：同步优先通知 UI，后台异步持久化，杜绝重绘等待闪烁
  Future<void> _persist() async {
    notifyListeners();
    await _storage.saveState(_state);
  }

  Future<bool> requestNotificationPermission() {
    return _notifications.requestPermission();
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> updateSettings(CtdpSettings newSettings) async {
    _state = _state.copyWith(settings: newSettings);
    await _persist();
  }

  Future<void> addUnitType(String type) async {
    final clean = type.trim();
    if (clean.isEmpty || settings.unitTypes.contains(clean)) return;
    final updated = [...settings.unitTypes, clean];
    await updateSettings(settings.copyWith(unitTypes: updated));
  }

  Future<void> removeUnitType(String type) async {
    if (settings.unitTypes.length <= 1) {
      throw StateError('至少需保留一个任务类型。');
    }
    final updated = settings.unitTypes.where((t) => t != type).toList();
    await updateSettings(settings.copyWith(unitTypes: updated));
  }

  Future<String?> createFolder({
    required String name,
    String? parentId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;
    if (parentId != null && folderById(parentId) == null) return null;

    final folder = CtdpFolder(
      id: _newId('folder'),
      name: cleanName,
      parentId: parentId,
      createdAt: DateTime.now(),
    );

    _state = _state.copyWith(folders: [...folders, folder]);
    await _persist();
    return folder.id;
  }

  Future<String?> createParentFolder({
    required String targetFolderId,
    required String name,
  }) async {
    final target = folderById(targetFolderId);
    if (target == null) return null;

    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;

    final newParentFolder = CtdpFolder(
      id: _newId('folder'),
      name: cleanName,
      parentId: target.parentId,
      createdAt: DateTime.now(),
    );

    final updatedFolders = folders.map((item) {
      if (item.id == targetFolderId) {
        return item.copyWith(parentId: newParentFolder.id);
      }
      return item;
    }).toList();

    _state = _state.copyWith(folders: [...updatedFolders, newParentFolder]);
    await _persist();
    return newParentFolder.id;
  }

  Future<void> renameFolder({
    required String folderId,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('文件夹名称不能为空。');
    if (folderById(folderId) == null) throw StateError('文件夹不存在。');

    _state = _state.copyWith(
      folders: folders
          .map((item) =>
              item.id == folderId ? item.copyWith(name: cleanName) : item)
          .toList(),
    );
    await _persist();
  }

  List<String> _collectFolderTreeIds(String rootFolderId) {
    final result = <String>{rootFolderId};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final folder in folders) {
        final parentId = folder.parentId;
        if (parentId == null) continue;
        if (result.contains(parentId) && !result.contains(folder.id)) {
          result.add(folder.id);
          changed = true;
        }
      }
    }
    return result.toList();
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderById(folderId) == null) return;
    final folderIds = _collectFolderTreeIds(folderId);
    final folderIdSet = folderIds.toSet();

    final affectedTasks = tasks.where((task) {
      final taskFolderId = task.folderId;
      return taskFolderId != null && folderIdSet.contains(taskFolderId);
    }).toList();

    for (final task in affectedTasks) {
      if (activeSession?.taskId == task.id) {
        throw StateError('该文件夹中有正在执行的任务，请先处理该任务后再删除。');
      }
      if (activeReservation?.taskId == task.id) {
        throw StateError('该文件夹中有正在预约的任务，请先取消预约后再删除。');
      }
    }

    _state = _state.copyWith(
      folders: folders.where((item) => !folderIdSet.contains(item.id)).toList(),
      tasks: tasks.where((task) {
        final taskFolderId = task.folderId;
        return taskFolderId == null || !folderIdSet.contains(taskFolderId);
      }).toList(),
    );
    await _persist();
  }

  List<CtdpFolder> childrenOf(String? parentId) {
    return folders
        .where((folder) => folder.parentId == parentId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<CtdpTask> tasksInFolder(String? folderId) {
    return tasks.where((task) => task.folderId == folderId).toList();
  }

  Future<String?> createTask({
    required String title,
    required String? folderId,
    required TaskTimerMode timerMode,
    String unitType = '学习',
    required int durationMinutes,
    required int appointmentMinutes,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return null;
    if (folderId == null || folderById(folderId) == null) return null;
    if (appointmentMinutes < 0) return null;
    if (timerMode == TaskTimerMode.countDown && durationMinutes <= 0) {
      return null;
    }

    final task = CtdpTask(
      id: _newId('task'),
      title: cleanTitle,
      folderId: folderId,
      timerMode: timerMode,
      unitType: unitType,
      durationSeconds:
          timerMode == TaskTimerMode.countDown ? durationMinutes * 60 : 0,
      appointmentMinutes: appointmentMinutes,
      completedChainNumber: null,
      overtimeSeconds: 0,
      isChainEnd: false,
      createdAt: DateTime.now(),
      completedAt: null,
    );

    _state = _state.copyWith(tasks: [...tasks, task]);
    await _persist();
    return task.id;
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    required String? folderId,
    required TaskTimerMode timerMode,
    required String unitType,
    required int durationMinutes,
    required int appointmentMinutes,
  }) async {
    final task = taskById(taskId);
    if (task == null) throw StateError('任务不存在。');
    if (activeSession?.taskId == taskId) throw StateError('任务正在执行时不能编辑。');
    if (activeReservation?.taskId == taskId) throw StateError('任务正在预约时不能编辑。');

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('任务名称不能为空。');
    if (folderId == null || folderById(folderId) == null) {
      throw ArgumentError('任务必须归属于具体文件夹。');
    }
    if (appointmentMinutes < 0) throw ArgumentError('预约时间不能小于 0。');
    if (timerMode == TaskTimerMode.countDown && durationMinutes <= 0) {
      throw ArgumentError('倒计时必须大于 0 分钟。');
    }

    _state = _state.copyWith(
      tasks: tasks.map((item) {
        if (item.id != taskId) return item;
        return item.copyWith(
          title: cleanTitle,
          folderId: folderId,
          timerMode: timerMode,
          unitType: unitType,
          durationSeconds: timerMode == TaskTimerMode.countDown
              ? durationMinutes * 60
              : 0,
          appointmentMinutes: appointmentMinutes,
        );
      }).toList(),
    );
    await _persist();
  }

  Future<void> deleteTask(String taskId) async {
    final task = taskById(taskId);
    if (task == null) return;

    if (activeSession?.taskId == taskId) {
      throw StateError('任务正在执行中，请先处理该任务后再删除。');
    }

    if (activeReservation?.taskId == taskId) {
      await _notifications.cancelReservationReminder();
      await _notifications.cancelActiveStatusNotification();
      _state = _state.copyWith(clearActiveReservation: true);
    }

    _state = _state.copyWith(
      tasks: tasks.where((item) => item.id != taskId).toList(),
    );
    await _persist();
  }

  Future<void> resetTaskCompletion(String taskId) async {
    _state = _state.copyWith(
      tasks: tasks.map((item) {
        if (item.id == taskId) {
          return item.copyWith(
            clearCompletedAt: true,
            clearFailedAt: true,
            clearCompletedChainNumber: true,
            overtimeSeconds: 0,
            isChainEnd: false,
          );
        }
        return item;
      }).toList(),
    );
    await _persist();
  }

  Future<void> clearAllHistory() async {
    _state = _state.copyWith(
      tasks: tasks.map((item) {
        return item.copyWith(
          clearCompletedAt: true,
          clearFailedAt: true,
          clearCompletedChainNumber: true,
          overtimeSeconds: 0,
          isChainEnd: false,
        );
      }).toList(),
      failures: const [],
    );
    await _persist();
  }

  // ============================================================
  // 运行与控制
  // ============================================================

  Future<void> startTask(String taskId, {bool bypassReservation = false}) async {
    if (hasActiveSession) {
      if (activeSession!.taskId == taskId) return;
      throw StateError('当前已有任务正在执行，请先处理当前任务。');
    }
    if (hasActiveReservation && !bypassReservation) {
      if (activeReservation!.taskId == taskId) return;
      throw StateError('当前已有任务正在预约，请先取消预约。');
    }

    final task = taskById(taskId);
    if (task == null) throw StateError('找不到该任务。');

    if (task.isCompleted || task.isFailed) {
      _state = _state.copyWith(
        tasks: tasks.map((item) {
          return item.id == taskId
              ? item.copyWith(
                  clearCompletedAt: true,
                  clearFailedAt: true,
                  clearCompletedChainNumber: true,
                  overtimeSeconds: 0,
                  isChainEnd: false,
                )
              : item;
        }).toList(),
      );
      await _persist();
    }

    if (task.appointmentMinutes > 0 && !bypassReservation) {
      await createReservation(
        taskId: taskId,
        delayMinutes: task.appointmentMinutes,
      );
      return;
    }

    if (hasActiveReservation && bypassReservation) {
      await _notifications.cancelReservationReminder();
      _state = _state.copyWith(clearActiveReservation: true);
    }

    await _startSession(task);
  }

  Future<void> _startSession(CtdpTask task, {DateTime? startedAt}) async {
    if (hasActiveSession) return;

    final start = startedAt ?? DateTime.now();

    final session = CtdpSession(
      taskId: task.id,
      startedAt: start,
      timerMode: task.timerMode,
      durationSeconds: task.durationSeconds,
    );

    _state = _state.copyWith(activeSession: session);
    await _persist();

    await _notifications.requestPermission();

    final taskNumber = getTaskNumber(task);

    try {
      await _notifications.showActiveSessionNotification(
        taskId: task.id,
        taskTitle: '#$taskNumber ${task.title}',
        timerMode: task.timerMode,
        startedAt: start,
        durationSeconds: task.durationSeconds,
      );
    } catch (e) {
      debugPrint('Error showing session notification: $e');
    }
  }

  Future<void> completeTask(String taskId) async {
    final session = activeSession;
    if (session == null || session.taskId != taskId) return;

    final task = taskById(taskId);
    final isCountDown = session.timerMode == TaskTimerMode.countDown;

    int recordedDuration = session.durationSeconds;
    int overtime = 0;

    if (isCountDown) {
      final elapsed = session.elapsedSeconds();
      recordedDuration = session.durationSeconds;
      if (elapsed > session.durationSeconds) {
        overtime = elapsed - session.durationSeconds;
      }
    } else {
      recordedDuration = session.elapsedSeconds();
      overtime = 0;
    }

    final currentNum = task != null ? getTaskNumber(task) : 1;

    _state = _state.copyWith(
      tasks: tasks.map((item) {
        if (item.id != taskId) return item;
        return item.copyWith(
          completedAt: DateTime.now(),
          durationSeconds: recordedDuration,
          overtimeSeconds: overtime,
          completedChainNumber: currentNum,
          clearFailedAt: true,
        );
      }).toList(),
      clearActiveSession: true,
    );

    await _notifications.cancelActiveStatusNotification();
    await _persist();
  }

  Future<void> failTask(String taskId, String reason) async {
    final task = taskById(taskId);
    if (task == null) return;

    final cleanReason = reason.trim().isEmpty ? '未填写原因' : reason.trim();
    final taskNum = getTaskNumber(task);

    final failure = CtdpFailureRecord(
      id: _newId('fail'),
      taskId: taskId,
      taskTitle: task.title,
      streakBeforeReset: taskNum,
      reason: cleanReason,
      failedAt: DateTime.now(),
    );

    _state = _state.copyWith(
      tasks: tasks.map((item) {
        if (item.id != taskId) return item;
        return item.copyWith(
          failedAt: DateTime.now(),
          failureReason: cleanReason,
          completedChainNumber: taskNum,
          clearCompletedAt: true,
        );
      }).toList(),
      failures: [failure, ...failures],
      clearActiveSession: true,
      clearActiveReservation: true,
    );

    await _notifications.cancelActiveStatusNotification();
    await _notifications.cancelReservationReminder();
    await _persist();
  }

  Future<void> createReservation({
    required String taskId,
    required int delayMinutes,
  }) async {
    if (delayMinutes <= 0) {
      final task = taskById(taskId);
      if (task != null) await _startSession(task);
      return;
    }

    if (hasActiveSession) throw StateError('当前已有任务正在执行。');
    if (hasActiveReservation) throw StateError('当前已有任务正在预约。');

    final task = taskById(taskId);
    if (task == null) throw StateError('任务不存在。');

    await _notifications.requestPermission();
    final createdAt = DateTime.now();
    final deadlineAt = createdAt.add(Duration(minutes: delayMinutes));

    final reservation = CtdpReservation(
      taskId: taskId,
      createdAt: createdAt,
      deadlineAt: deadlineAt,
    );

    _state = _state.copyWith(activeReservation: reservation);
    await _persist();

    final taskNumber = getTaskNumber(task);

    try {
      await _notifications.scheduleReservation(
        deadline: deadlineAt,
        taskName: '#$taskNumber ${task.title}',
        taskId: taskId,
      );

      await _notifications.showActiveReservationNotification(
        taskId: taskId,
        taskTitle: '#$taskNumber ${task.title}',
        deadline: deadlineAt,
      );
    } catch (e) {
      debugPrint('Error showing reservation notification: $e');
    }
  }

  Future<void> cancelReservation() async {
    await _notifications.cancelReservationReminder();
    await _notifications.cancelActiveStatusNotification();
    _state = _state.copyWith(clearActiveReservation: true);
    await _persist();
  }

  Future<void> syncRuntime({bool notify = true}) async {
    final reservation = activeReservation;
    if (reservation == null) return;
    if (!reservation.isExpired()) return;

    final task = taskById(reservation.taskId);
    await _notifications.cancelReservationReminder();

    if (task == null) {
      await _notifications.cancelActiveStatusNotification();
      _state = _state.copyWith(clearActiveReservation: true);
      if (notify) {
        await _persist();
      } else {
        await _storage.saveState(_state);
      }
      return;
    }

    final session = CtdpSession(
      taskId: task.id,
      startedAt: reservation.deadlineAt,
      timerMode: task.timerMode,
      durationSeconds: task.durationSeconds,
    );

    _state = _state.copyWith(
      clearActiveReservation: true,
      activeSession: session,
    );

    final taskNumber = getTaskNumber(task);

    try {
      await _notifications.showActiveSessionNotification(
        taskId: task.id,
        taskTitle: '#$taskNumber ${task.title}',
        timerMode: task.timerMode,
        startedAt: reservation.deadlineAt,
        durationSeconds: task.durationSeconds,
      );
    } catch (e) {
      debugPrint('Error syncing notification: $e');
    }

    if (notify) {
      await _persist();
    } else {
      await _storage.saveState(_state);
    }
  }
}

class StorageService {
  static const _stateKey = 'ctdp_state_v2';

  Future<CtdpState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);

    if (raw == null || raw.isEmpty) {
      return CtdpState.initial();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return CtdpState.initial();
      return CtdpState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return CtdpState.initial();
    }
  }

  Future<void> saveState(CtdpState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }
}