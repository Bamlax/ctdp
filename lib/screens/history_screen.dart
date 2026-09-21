import 'package:flutter/material.dart';

import '../app/app.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';
import 'focus_screen.dart';

class HistoryScreen extends StatefulWidget {
  final CtdpController controller;

  const HistoryScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedTypeFilter;
  int _historyTab = 0; // 0 = 工作量记录, 1 = 中断复盘, 2 = 统计图表

  CtdpController get controller => widget.controller;

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours小时$remainingMinutes分钟' : '$hours 小时';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatCard() {
    final todayStr = _formatDuration(controller.todayFocusSeconds);
    final weekStr = _formatDuration(controller.weekFocusSeconds);
    final totalCount = controller.completedTasks.length;

    return Card(
      color: CtdpColors.primaryLight,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('今日专注', style: TextStyle(fontSize: 12, color: CtdpColors.textSecondary)),
                const SizedBox(height: 4),
                Text(todayStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CtdpColors.primaryDark)),
              ],
            ),
            Container(width: 1, height: 28, color: Colors.blue.shade100),
            Column(
              children: [
                const Text('本周投入', style: TextStyle(fontSize: 12, color: CtdpColors.textSecondary)),
                const SizedBox(height: 4),
                Text(weekStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CtdpColors.primaryDark)),
              ],
            ),
            Container(width: 1, height: 28, color: Colors.blue.shade100),
            Column(
              children: [
                const Text('累计完成', style: TextStyle(fontSize: 12, color: CtdpColors.textSecondary)),
                const SizedBox(height: 4),
                Text('$totalCount 个', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CtdpColors.primaryDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsView() {
    final now = DateTime.now();

    final List<Map<String, dynamic>> last7Days = [];
    int maxMinutes = 60;

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int dailySecs = 0;
      for (final t in controller.completedTasks) {
        if (t.completedAt != null &&
            t.completedAt!.isAfter(dayStart) &&
            t.completedAt!.isBefore(dayEnd)) {
          dailySecs += (t.durationSeconds + t.overtimeSeconds);
        }
      }

      final minutes = dailySecs ~/ 60;
      if (minutes > maxMinutes) maxMinutes = minutes;

      final label = i == 0 ? '今天' : '${targetDate.month}/${targetDate.day}';
      last7Days.add({'label': label, 'minutes': minutes});
    }

    final Map<String, int> typeMinutesMap = {};
    int totalTypeMinutes = 0;
    for (final t in controller.completedTasks) {
      final mins = (t.durationSeconds + t.overtimeSeconds) ~/ 60;
      typeMinutesMap[t.unitType] = (typeMinutesMap[t.unitType] ?? 0) + mins;
      totalTypeMinutes += mins;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '近 7 天专注趋势 (分钟)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: last7Days.map((data) {
                      final minutes = data['minutes'] as int;
                      final label = data['label'] as String;
                      final double ratio = maxMinutes > 0 ? (minutes / maxMinutes) : 0;
                      final barHeight = (ratio * 100).clamp(6.0, 100.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            minutes > 0 ? '$minutes' : '',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: CtdpColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: minutes > 0 ? CtdpColors.primary : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 10, color: CtdpColors.textSecondary),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '分类投入分析',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 14),
                if (totalTypeMinutes == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('暂无分类投入数据', style: TextStyle(color: CtdpColors.textSecondary, fontSize: 13)),
                    ),
                  )
                else
                  ...typeMinutesMap.entries.map((entry) {
                    final percent = (entry.value / totalTypeMinutes);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${entry.value} 分钟 (${(percent * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontSize: 12, color: CtdpColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade100,
                              color: CtdpColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        var completedList = controller.completedTasks;
        if (_selectedTypeFilter != null) {
          completedList = completedList.where((t) => t.unitType == _selectedTypeFilter).toList();
        }

        final types = controller.settings.unitTypes;
        final failures = controller.failures;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildStatCard(),

                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('已完成')),
                        selected: _historyTab == 0,
                        onSelected: (sel) {
                          if (sel) setState(() => _historyTab = 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text('复盘 (${failures.length})')),
                        selected: _historyTab == 1,
                        onSelected: (sel) {
                          if (sel) setState(() => _historyTab = 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('统计图表')),
                        selected: _historyTab == 2,
                        onSelected: (sel) {
                          if (sel) setState(() => _historyTab = 2);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_historyTab == 0) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _selectedTypeFilter == null,
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedTypeFilter = null);
                          },
                        ),
                        const SizedBox(width: 6),
                        ...types.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: _selectedTypeFilter == type,
                              onSelected: (sel) {
                                setState(() {
                                  _selectedTypeFilter = sel ? type : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (completedList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          '没有对应的历史记录',
                          style: TextStyle(color: CtdpColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...completedList.map((task) {
                      final taskNum = controller.getTaskNumber(task);

                      // 历史中展示投入及超时详情
                      String durationDetail = '投入 ${_formatDuration(task.durationSeconds)}';
                      if (task.overtimeSeconds > 0) {
                        durationDetail += ' · 超时 ${_formatDuration(task.overtimeSeconds)}';
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.unitType,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: CtdpColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '#$taskNum ${task.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (task.isChainEnd)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.green.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '已结链',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '完成于 ${_formatDate(task.completedAt!)} · $durationDetail',
                            style: const TextStyle(fontSize: 11, color: CtdpColors.textSecondary),
                          ),
                          trailing: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onSelected: (val) {
                              if (val == 'open') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FocusScreen(
                                      controller: controller,
                                      taskId: task.id,
                                    ),
                                  ),
                                );
                              } else if (val == 'reset') {
                                controller.resetTaskCompletion(task.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'open', child: Text('查看任务')),
                              PopupMenuItem(value: 'reset', child: Text('重新置为未完成')),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FocusScreen(
                                  controller: controller,
                                  taskId: task.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ] else if (_historyTab == 1) ...[
                  if (failures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          '暂无中断记录，保持专注！',
                          style: TextStyle(color: CtdpColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...failures.map((record) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '# ${record.taskTitle}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '断链前: #${record.streakBeforeReset}',
                                    style: const TextStyle(fontSize: 12, color: CtdpColors.danger),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '原因: ${record.reason}',
                                style: const TextStyle(fontSize: 13, color: CtdpColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '中断时间: ${_formatDate(record.failedAt)}',
                                style: const TextStyle(fontSize: 11, color: CtdpColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ] else ...[
                  _buildChartsView(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}