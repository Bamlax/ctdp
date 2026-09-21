/// 版本更新记录模型
class VersionRecord {
  final String version;
  final String releaseDate;
  final List<String> changes;

  const VersionRecord({
    required this.version,
    required this.releaseDate,
    required this.changes,
  });
}

/// CTDP 版本更新记录
const List<VersionRecord> ctdpVersionHistory = [
    VersionRecord(
    version: '0.2.0',
    releaseDate: '2026-09-21',
    changes: [
      '新增待办的标签和备注功能',
    ],
  ),
  VersionRecord(
    version: '0.1.0',
    releaseDate: '2026-09-21',
    changes: [
      '全局前序连续编号与断链/结链机制',
      '任务树管理与未完成任务跨文件夹长按拖拽移动',
      '专注计时、预约缓冲与超时统计（与完成脱钩）',
      '首页链长看板与历史投入趋势图表',
      'Android 桌面小组件与状态栏动态计时通知',
    ],
  ),
];