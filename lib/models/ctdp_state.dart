enum TaskTimerMode {
  countUp,
  countDown,
}

TaskTimerMode taskTimerModeFromJson(String? value, [TaskTimerMode fallback = TaskTimerMode.countDown]) {
  if (value == null) return fallback;
  return value == 'countUp' ? TaskTimerMode.countUp : TaskTimerMode.countDown;
}

class CtdpFolderOption {
  final String id;
  final String label;

  const CtdpFolderOption({
    required this.id,
    required this.label,
  });
}

/// 链条中断复盘记录
class CtdpFailureRecord {
  final String id;
  final String taskId;
  final String taskTitle;
  final int streakBeforeReset;
  final String reason;
  final DateTime failedAt;

  const CtdpFailureRecord({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.streakBeforeReset,
    required this.reason,
    required this.failedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'streakBeforeReset': streakBeforeReset,
      'reason': reason,
      'failedAt': failedAt.toIso8601String(),
    };
  }

  factory CtdpFailureRecord.fromJson(Map<String, dynamic> json) {
    return CtdpFailureRecord(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      taskTitle: json['taskTitle'] as String,
      streakBeforeReset: (json['streakBeforeReset'] as int?) ?? 0,
      reason: json['reason'] as String? ?? '未填写原因',
      failedAt: DateTime.parse(json['failedAt'] as String),
    );
  }
}

/// 全局偏好设置模型
class CtdpSettings {
  final int defaultDurationMinutes;
  final int defaultAppointmentMinutes;
  final TaskTimerMode defaultTimerMode; // 新增：默认计时模式（正计时/倒计时）
  final bool enableVibration;
  final bool enableSound;
  final List<String> unitTypes;

  const CtdpSettings({
    required this.defaultDurationMinutes,
    required this.defaultAppointmentMinutes,
    this.defaultTimerMode = TaskTimerMode.countDown,
    required this.enableVibration,
    required this.enableSound,
    required this.unitTypes,
  });

  factory CtdpSettings.defaults() {
    return const CtdpSettings(
      defaultDurationMinutes: 60,
      defaultAppointmentMinutes: 15,
      defaultTimerMode: TaskTimerMode.countDown,
      enableVibration: true,
      enableSound: true,
      unitTypes: ['学习', '工作', '阅读', '运动', '日常'],
    );
  }

  CtdpSettings copyWith({
    int? defaultDurationMinutes,
    int? defaultAppointmentMinutes,
    TaskTimerMode? defaultTimerMode,
    bool? enableVibration,
    bool? enableSound,
    List<String>? unitTypes,
  }) {
    return CtdpSettings(
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      defaultAppointmentMinutes:
          defaultAppointmentMinutes ?? this.defaultAppointmentMinutes,
      defaultTimerMode: defaultTimerMode ?? this.defaultTimerMode,
      enableVibration: enableVibration ?? this.enableVibration,
      enableSound: enableSound ?? this.enableSound,
      unitTypes: unitTypes ?? this.unitTypes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultDurationMinutes': defaultDurationMinutes,
      'defaultAppointmentMinutes': defaultAppointmentMinutes,
      'defaultTimerMode': defaultTimerMode.name,
      'enableVibration': enableVibration,
      'enableSound': enableSound,
      'unitTypes': unitTypes,
    };
  }

  factory CtdpSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CtdpSettings.defaults();
    final rawTypes = json['unitTypes'] as List<dynamic>?;

    return CtdpSettings(
      defaultDurationMinutes: json['defaultDurationMinutes'] as int? ?? 60,
      defaultAppointmentMinutes:
          json['defaultAppointmentMinutes'] as int? ?? 15,
      defaultTimerMode: taskTimerModeFromJson(
        json['defaultTimerMode'] as String?,
        TaskTimerMode.countDown,
      ),
      enableVibration: json['enableVibration'] as bool? ?? true,
      enableSound: json['enableSound'] as bool? ?? true,
      unitTypes: rawTypes != null
          ? rawTypes.map((e) => e.toString()).toList()
          : const ['学习', '工作', '阅读', '运动', '日常'],
    );
  }
}

class CtdpFolder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;

  const CtdpFolder({
    required this.id,
    required this.name,
    required this.parentId,
    required this.createdAt,
  });

  CtdpFolder copyWith({
    String? name,
    String? parentId,
  }) {
    return CtdpFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CtdpFolder.fromJson(Map<String, dynamic> json) {
    return CtdpFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CtdpTask {
  final String id;
  final String title;
  final String? folderId;
  final TaskTimerMode timerMode;
  final String unitType;
  final int durationSeconds;
  final int appointmentMinutes;
  final int? completedChainNumber;
  final int overtimeSeconds; // 倒计时超时时长（秒）
  final bool isChainEnd;      // 是否主动完结该链
  final List<String> tags;    // 标签列表
  final String notes;         // 备注文本
  final bool allowPause;      // 是否允许暂停
  final int maxPauseMinutes;  // 允许最大暂停时长（0 表示不限）
  final DateTime? failedAt;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;

  String get note => notes;

  const CtdpTask({
    required this.id,
    required this.title,
    required this.folderId,
    required this.timerMode,
    this.unitType = '学习',
    required this.durationSeconds,
    required this.appointmentMinutes,
    this.completedChainNumber,
    this.overtimeSeconds = 0,
    this.isChainEnd = false,
    this.tags = const [],
    this.notes = '',
    this.allowPause = false,
    this.maxPauseMinutes = 0,
    this.failedAt,
    this.failureReason,
    required this.createdAt,
    required this.completedAt,
  });

  bool get isCompleted => completedAt != null;
  bool get isFailed => failedAt != null;
  bool get isPending => !isCompleted && !isFailed;

  CtdpTask copyWith({
    String? title,
    String? folderId,
    TaskTimerMode? timerMode,
    String? unitType,
    int? durationSeconds,
    int? appointmentMinutes,
    int? completedChainNumber,
    int? overtimeSeconds,
    bool? isChainEnd,
    List<String>? tags,
    String? notes,
    bool? allowPause,
    int? maxPauseMinutes,
    DateTime? failedAt,
    String? failureReason,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool clearFailedAt = false,
    bool clearCompletedChainNumber = false,
  }) {
    return CtdpTask(
      id: id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      timerMode: timerMode ?? this.timerMode,
      unitType: unitType ?? this.unitType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      appointmentMinutes: appointmentMinutes ?? this.appointmentMinutes,
      completedChainNumber: clearCompletedChainNumber
          ? null
          : completedChainNumber ?? this.completedChainNumber,
      overtimeSeconds: overtimeSeconds ?? this.overtimeSeconds,
      isChainEnd: isChainEnd ?? this.isChainEnd,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      allowPause: allowPause ?? this.allowPause,
      maxPauseMinutes: maxPauseMinutes ?? this.maxPauseMinutes,
      failedAt: clearFailedAt ? null : failedAt ?? this.failedAt,
      failureReason: clearFailedAt ? null : failureReason ?? this.failureReason,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'folderId': folderId,
      'timerMode': timerMode.name,
      'unitType': unitType,
      'durationSeconds': durationSeconds,
      'appointmentMinutes': appointmentMinutes,
      'completedChainNumber': completedChainNumber,
      'overtimeSeconds': overtimeSeconds,
      'isChainEnd': isChainEnd,
      'tags': tags,
      'notes': notes,
      'allowPause': allowPause,
      'maxPauseMinutes': maxPauseMinutes,
      'failedAt': failedAt?.toIso8601String(),
      'failureReason': failureReason,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  static String _parseUnitType(dynamic val) {
    if (val == null) return '学习';
    final str = val.toString();
    if (str == 'assault' || str == '突击') return '学习';
    if (str == 'recon' || str == '侦查') return '阅读';
    if (str == 'engineer' || str == '工程') return '运动';
    if (str == 'command' || str == '指挥') return '工作';
    if (str == 'general' || str == '综合') return '日常';
    return str.isNotEmpty ? str : '学习';
  }

  factory CtdpTask.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>?;

    return CtdpTask(
      id: json['id'] as String,
      title: json['title'] as String,
      folderId: json['folderId'] as String?,
      timerMode: taskTimerModeFromJson(json['timerMode'] as String?, TaskTimerMode.countDown),
      unitType: _parseUnitType(json['unitType']),
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      appointmentMinutes: (json['appointmentMinutes'] as int?) ?? 0,
      completedChainNumber: json['completedChainNumber'] as int?,
      overtimeSeconds: (json['overtimeSeconds'] as int?) ?? 0,
      isChainEnd: (json['isChainEnd'] as bool?) ?? false,
      tags: rawTags != null ? rawTags.map((e) => e.toString()).toList() : const [],
      notes: (json['notes'] as String?) ?? '',
      allowPause: (json['allowPause'] as bool?) ?? false,
      maxPauseMinutes: (json['maxPauseMinutes'] as int?) ?? 0,
      failedAt: json['failedAt'] == null ? null : DateTime.parse(json['failedAt'] as String),
      failureReason: json['failureReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}

class CtdpSession {
  final String taskId;
  final DateTime startedAt;
  final TaskTimerMode timerMode;
  final int durationSeconds;
  final bool isPaused;
  final DateTime? pausedAt;
  final int totalPausedSeconds;

  const CtdpSession({
    required this.taskId,
    required this.startedAt,
    required this.timerMode,
    required this.durationSeconds,
    this.isPaused = false,
    this.pausedAt,
    this.totalPausedSeconds = 0,
  });

  CtdpSession copyWith({
    String? taskId,
    DateTime? startedAt,
    TaskTimerMode? timerMode,
    int? durationSeconds,
    bool? isPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? totalPausedSeconds,
  }) {
    return CtdpSession(
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      timerMode: timerMode ?? this.timerMode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
    );
  }

  int elapsedSeconds([DateTime? now]) {
    final current = now ?? DateTime.now();
    final refTime = (isPaused && pausedAt != null) ? pausedAt! : current;
    final raw = refTime.difference(startedAt).inSeconds - totalPausedSeconds;
    return raw < 0 ? 0 : raw;
  }

  int remainingSeconds([DateTime? now]) {
    if (timerMode == TaskTimerMode.countUp) return 0;
    final remaining = durationSeconds - elapsedSeconds(now);
    return remaining < 0 ? 0 : remaining;
  }

  int overtimeSeconds([DateTime? now]) {
    if (timerMode != TaskTimerMode.countDown) return 0;
    final elapsed = elapsedSeconds(now);
    return elapsed > durationSeconds ? elapsed - durationSeconds : 0;
  }

  int currentPauseSeconds([DateTime? now]) {
    if (!isPaused || pausedAt == null) return 0;
    final current = now ?? DateTime.now();
    final diff = current.difference(pausedAt!).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool isPauseExceeded(int maxMinutes, [DateTime? now]) {
    if (maxMinutes <= 0 || !isPaused || pausedAt == null) return false;
    return currentPauseSeconds(now) >= maxMinutes * 60;
  }

  bool get isFinished {
    if (timerMode == TaskTimerMode.countUp) return false;
    return elapsedSeconds() >= durationSeconds;
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'startedAt': startedAt.toIso8601String(),
      'timerMode': timerMode.name,
      'durationSeconds': durationSeconds,
      'isPaused': isPaused,
      'pausedAt': pausedAt?.toIso8601String(),
      'totalPausedSeconds': totalPausedSeconds,
    };
  }

  factory CtdpSession.fromJson(Map<String, dynamic> json) {
    return CtdpSession(
      taskId: json['taskId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      timerMode: taskTimerModeFromJson(json['timerMode'] as String?, TaskTimerMode.countDown),
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      isPaused: (json['isPaused'] as bool?) ?? false,
      pausedAt: json['pausedAt'] == null ? null : DateTime.parse(json['pausedAt'] as String),
      totalPausedSeconds: (json['totalPausedSeconds'] as int?) ?? 0,
    );
  }
}

class CtdpReservation {
  final String taskId;
  final DateTime createdAt;
  final DateTime deadlineAt;

  const CtdpReservation({
    required this.taskId,
    required this.createdAt,
    required this.deadlineAt,
  });

  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return !current.isBefore(deadlineAt);
  }

  int remainingSeconds([DateTime? now]) {
    final current = now ?? DateTime.now();
    final seconds = deadlineAt.difference(current).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'createdAt': createdAt.toIso8601String(),
      'deadlineAt': deadlineAt.toIso8601String(),
    };
  }

  factory CtdpReservation.fromJson(Map<String, dynamic> json) {
    return CtdpReservation(
      taskId: json['taskId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deadlineAt: DateTime.parse(json['deadlineAt'] as String),
    );
  }
}

class CtdpState {
  final List<CtdpFolder> folders;
  final List<CtdpTask> tasks;
  final List<CtdpFailureRecord> failures;
  final CtdpSettings settings;
  final CtdpSession? activeSession;
  final CtdpReservation? activeReservation;

  const CtdpState({
    required this.folders,
    required this.tasks,
    required this.failures,
    required this.settings,
    required this.activeSession,
    required this.activeReservation,
  });

  factory CtdpState.initial() {
    return CtdpState(
      folders: const [],
      tasks: const [],
      failures: const [],
      settings: CtdpSettings.defaults(),
      activeSession: null,
      activeReservation: null,
    );
  }

  CtdpState copyWith({
    List<CtdpFolder>? folders,
    List<CtdpTask>? tasks,
    List<CtdpFailureRecord>? failures,
    CtdpSettings? settings,
    CtdpSession? activeSession,
    bool clearActiveSession = false,
    CtdpReservation? activeReservation,
    bool clearActiveReservation = false,
  }) {
    return CtdpState(
      folders: folders ?? this.folders,
      tasks: tasks ?? this.tasks,
      failures: failures ?? this.failures,
      settings: settings ?? this.settings,
      activeSession: clearActiveSession
          ? null
          : activeSession ?? this.activeSession,
      activeReservation: clearActiveReservation
          ? null
          : activeReservation ?? this.activeReservation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 11,
      'folders': folders.map((f) => f.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'failures': failures.map((f) => f.toJson()).toList(),
      'settings': settings.toJson(),
      'activeSession': activeSession?.toJson(),
      'activeReservation': activeReservation?.toJson(),
    };
  }

  factory CtdpState.fromJson(Map<String, dynamic> json) {
    final rawFolders = (json['folders'] as List<dynamic>?) ?? const [];
    final rawTasks = (json['tasks'] as List<dynamic>?) ?? const [];
    final rawFailures = (json['failures'] as List<dynamic>?) ?? const [];
    final rawSession = json['activeSession'];
    final rawReservation = json['activeReservation'];
    final rawSettings = json['settings'] as Map<String, dynamic>?;

    return CtdpState(
      folders: rawFolders
          .map((item) =>
              CtdpFolder.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      tasks: rawTasks
          .map((item) =>
              CtdpTask.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      failures: rawFailures
          .map((item) =>
              CtdpFailureRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      settings: CtdpSettings.fromJson(rawSettings),
      activeSession: rawSession == null
          ? null
          : CtdpSession.fromJson(Map<String, dynamic>.from(rawSession as Map)),
      activeReservation: rawReservation == null
          ? null
          : CtdpReservation.fromJson(
              Map<String, dynamic>.from(rawReservation as Map)),
    );
  }
}