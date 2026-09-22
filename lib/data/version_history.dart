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
    version: '0.3.1',
    releaseDate: '2026-09-23',
    changes: [
      '优化：流体云的弹出功能',
    ],
  ),
  VersionRecord(
  version: '0.3.0',
  releaseDate: '2026-09-22',
  changes: [
    '新增：应用图标',
    '新增：流体云功能',
    '新增：暂停功能基础设定',
    '新增：默认正计时功能',
    '优化：减少任务树缩进，层级展示更紧凑',
    '优化：移除详情页中的正计时提示',
    '优化：关闭启动 / 结束铃声',
    '修复：已完成任务不能再次启动，并在完成后刷新主页状态',
    '修复：默认设定不可修改的问题',
    '修复：任务类型删除后未立即刷新，需要再次新增才刷新的问题',
    '修复：正计时 10 秒相关异常',
    '修复：完成任务后需要返回两次的问题',
    '修复：任务不存在时界面展示异常的问题',
  ],
),
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