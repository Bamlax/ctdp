import 'package:flutter/material.dart';

import '../app/app.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';
import 'focus_screen.dart';
import 'task_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  final CtdpController controller;

  const HomeScreen({
    super.key,
    required this.controller,
  });

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours小时$remainingMinutes分钟' : '$hours 小时';
  }

  Future<void> _createTask(BuildContext context) async {
    if (controller.folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在「任务树」中创建至少一个文件夹，任务必须归属于文件夹。')),
      );
      return;
    }

    final taskId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          controller: controller,
        ),
      ),
    );

    if (taskId == null || !context.mounted) return;

    final task = controller.taskById(taskId);
    if (task == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('待办「${task.title}」已创建。')),
    );
  }

  Future<void> _openTask(BuildContext context, CtdpTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          controller: controller,
          taskId: task.id,
        ),
      ),
    );
  }

  Widget _buildTopHeroCard(BuildContext context) {
    final streak = controller.activeStreakLength;
    final todayStr = _formatDuration(controller.todayFocusSeconds);
    final weekStr = _formatDuration(controller.weekFocusSeconds);

    final session = controller.activeSession;
    final reservation = controller.activeReservation;
    final activeTaskId = session?.taskId ?? reservation?.taskId;
    final activeTask = activeTaskId != null ? controller.taskById(activeTaskId) : null;
    final isReservation = reservation != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CtdpColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CtdpColors.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CTDP 工作量证明链',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  streak > 0 ? '已连续完成 $streak 环' : '新链准备中',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '#',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '环连续链长',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日专注时间',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        todayStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: Colors.white24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本周累计时间',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (activeTask != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _openTask(context, activeTask),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReservation ? Icons.schedule : Icons.timer,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${isReservation ? "预约中" : "正在专注"}: #${controller.getTaskNumber(activeTask)} ${activeTask.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pendingTasks = controller
            .getGlobalOrderedTasks()
            .where((task) => task.isPending)
            .toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createTask(context),
            tooltip: '新建待办',
            icon: const Icon(Icons.add_task),
            label: const Text('新建待办'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _buildTopHeroCard(context),

                const Text(
                  '待办清单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                if (pendingTasks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Text(
                          '暂无待办任务，点击右下角添加。',
                          style: TextStyle(color: CtdpColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  ...pendingTasks.map((task) {
                    final folder = task.folderId == null
                        ? null
                        : controller.folderById(task.folderId!);
                    final isActive = controller.activeSession?.taskId == task.id;
                    final isReserved = controller.activeReservation?.taskId == task.id;
                    final taskNum = controller.getTaskNumber(task);

                    String statusDesc = '';
                    if (isActive) {
                      statusDesc = '正在执行';
                    } else if (isReserved) {
                      statusDesc = '预约中';
                    } else if (task.timerMode == TaskTimerMode.countDown) {
                      statusDesc = '${task.durationSeconds ~/ 60}分钟倒计时';
                    } else {
                      statusDesc = '正计时';
                    }

                    return Card(
                      key: ValueKey('home_${task.id}'),
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        title: Text(
                          '#$taskNum ${task.title}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isActive ? CtdpColors.primary : CtdpColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          folder == null ? statusDesc : '${folder.name} · $statusDesc',
                          style: const TextStyle(fontSize: 12, color: CtdpColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _openTask(context, task),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}