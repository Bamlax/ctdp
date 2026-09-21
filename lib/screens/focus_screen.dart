import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';
import 'task_edit_screen.dart';

class FocusScreen extends StatefulWidget {
  final CtdpController controller;
  final String taskId;

  const FocusScreen({
    super.key,
    required this.controller,
    required this.taskId,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  Timer? _timer;
  bool _hasAlertedFinished = false;

  CtdpController get controller => widget.controller;
  CtdpTask? get task => controller.taskById(widget.taskId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  void _triggerFeedback() {
    if (controller.settings.enableVibration) {
      HapticFeedback.heavyImpact();
    }
    if (controller.settings.enableSound) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _refresh() async {
    await controller.syncRuntime();
    if (!mounted) return;

    final session = controller.activeSession;
    if (session != null &&
        session.taskId == widget.taskId &&
        session.isFinished &&
        !_hasAlertedFinished) {
      _hasAlertedFinished = true;
      _triggerFeedback();
    }

    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _startTask({bool bypassReservation = false}) async {
    try {
      _hasAlertedFinished = false;
      await controller.startTask(widget.taskId, bypassReservation: bypassReservation);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _completeTask() async {
    final currentTask = task;
    if (currentTask == null) return;

    final currentNum = controller.getTaskNumber(currentTask);

    _triggerFeedback();
    await controller.completeTask(currentTask.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('第 #$currentNum 次专注完成！已落块记录。')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _showFailDialog() async {
    final textCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记为未完成 (重置链条)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '根据 CTDP 协议，中断任务将导致后续任务重置回 #1。请输入未完成原因备注：',
              style: TextStyle(fontSize: 13, height: 1.4, color: CtdpColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '例如：突发情况打断、状态不佳...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CtdpColors.danger),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('确认中断'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await controller.failTask(widget.taskId, textCtrl.text);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已中断。后续任务将重置从 #1 重新开始。')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = task;
    if (currentTask == null) {
      return const Scaffold(body: Center(child: Text('任务不存在')));
    }

    final session = controller.activeSession;
    final reservation = controller.activeReservation;
    final activeTaskSession = session?.taskId == currentTask.id ? session : null;
    final activeTaskReservation = reservation?.taskId == currentTask.id ? reservation : null;

    final taskNum = controller.getTaskNumber(currentTask);

    return Scaffold(
      appBar: AppBar(
        title: Text('#$taskNum ${currentTask.title}'),
        actions: [
          IconButton(
            tooltip: '编辑任务',
            onPressed: (activeTaskSession != null || activeTaskReservation != null)
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskEditScreen(
                          controller: controller,
                          taskId: currentTask.id,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {});
                  },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currentTask.unitType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CtdpColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '当前链节: #$taskNum',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CtdpColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '#$taskNum ${currentTask.title}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
            if (activeTaskReservation != null)
              _buildReservation(activeTaskReservation)
            else if (activeTaskSession != null)
              _buildTimer(activeTaskSession)
            else
              _buildIdle(currentTask),
            const SizedBox(height: 24),
            _buildInfoCard(currentTask, taskNum),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(CtdpTask currentTask) {
    final disabledByOther =
        (controller.hasActiveSession && controller.activeSession?.taskId != currentTask.id) ||
        (controller.hasActiveReservation && controller.activeReservation?.taskId != currentTask.id);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
          decoration: BoxDecoration(
            color: CtdpColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                currentTask.timerMode == TaskTimerMode.countDown
                    ? Icons.timer_outlined
                    : Icons.timer_10_outlined,
                size: 48,
                color: CtdpColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                currentTask.timerMode == TaskTimerMode.countDown
                    ? '${currentTask.durationSeconds ~/ 60} 分钟倒计时'
                    : '正计时',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (currentTask.appointmentMinutes > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '预约准备 ${currentTask.appointmentMinutes} 分钟',
                  style: const TextStyle(color: CtdpColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: disabledByOther ? null : () => _startTask(),
            icon: const Icon(Icons.play_arrow),
            label: Text(currentTask.isCompleted ? '再次启动此任务' : '进入神圣座位 (开始任务)'),
          ),
        ),
        if (disabledByOther) ...[
          const SizedBox(height: 12),
          const Text(
            '当前已有其他任务正在执行或预约。',
            textAlign: TextAlign.center,
            style: TextStyle(color: CtdpColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildReservation(CtdpReservation reservation) {
    final remaining = reservation.remainingSeconds();

    return Column(
      children: [
        const Text(
          '辅助链预约倒计时',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CtdpColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: CtdpColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                _formatDuration(remaining),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: CtdpColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text('预约缓冲结束后将自动进入专注任务。'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _showFailDialog,
                child: const Text('放弃预约 (重置)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _startTask(bypassReservation: true),
                child: const Text('立即开始'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimer(CtdpSession session) {
    final isCountDown = session.timerMode == TaskTimerMode.countDown;
    final seconds = isCountDown ? session.remainingSeconds() : session.elapsedSeconds();
    final finished = isCountDown && session.isFinished;
    final overtime = isCountDown ? session.overtimeSeconds() : 0;

    return Column(
      children: [
        Text(
          isCountDown ? '神圣座位倒计时' : '正计时专注中',
          style: const TextStyle(fontWeight: FontWeight.w700, color: CtdpColors.primary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: CtdpColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                _formatDuration(finished ? overtime : seconds),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: finished ? CtdpColors.success : CtdpColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                finished
                    ? (overtime > 0 ? '已超时 ${_formatDuration(overtime)} (继续专注中)' : '专注时间已达成！')
                    : '保持专注，决不玷污神圣座位',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _showFailDialog,
                child: const Text('未完成 (重置链)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _completeTask,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('完成任务'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(CtdpTask currentTask, int taskNum) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '任务属性',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text('类型：${currentTask.unitType}'),
            Text(currentTask.timerMode == TaskTimerMode.countDown
                ? '模式：倒计时 (${currentTask.durationSeconds ~/ 60} 分钟)'
                : '模式：正计时'),
            Text('预约设定：${currentTask.appointmentMinutes} 分钟'),
            Text(currentTask.isCompleted
                ? '已落块编号：#$taskNum'
                : '当前目标编号：#$taskNum (未完成将重回 #1)'),
            if (currentTask.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('标签：'),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      children: currentTask.tags
                          .map((t) => Text('#$t', style: const TextStyle(color: CtdpColors.primary, fontWeight: FontWeight.w600)))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
            if (currentTask.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('备注：${currentTask.notes}'),
            ],
          ],
        ),
      ),
    );
  }
}