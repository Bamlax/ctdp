import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/version_history.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';
import 'version_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  final CtdpController controller;

  const SettingsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CtdpController get controller => widget.controller;

  Future<void> _showClearAllConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('重置所有历史数据'),
        content: const Text(
          '确定要清空全部已完成任务和复盘记录吗？当前正在进行的任务不受影响。此操作不可撤销。',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CtdpColors.danger,
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('确认清空'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.clearAllHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空全部历史记录。')),
      );
    }
  }

  Future<void> _showAddTypeDialog() async {
    final textCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('新增任务类型'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入分类名称 (如：写作、健身)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && textCtrl.text.trim().isNotEmpty) {
      await controller.addUnitType(textCtrl.text.trim());
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final currentVersion = ctdpVersionHistory.first.version;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // 偏好与默认时长设置
            const Text(
              '默认设定',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CtdpColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('默认倒计时时长'),
                    subtitle: Text('${settings.defaultDurationMinutes} 分钟'),
                    trailing: DropdownButton<int>(
                      value: settings.defaultDurationMinutes,
                      underline: const SizedBox.shrink(),
                      items: [15, 25, 30, 45, 60, 90, 120]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateSettings(settings.copyWith(defaultDurationMinutes: val));
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    title: const Text('默认预约缓冲时长'),
                    subtitle: Text('${settings.defaultAppointmentMinutes} 分钟'),
                    trailing: DropdownButton<int>(
                      value: settings.defaultAppointmentMinutes,
                      underline: const SizedBox.shrink(),
                      items: [0, 5, 10, 15, 20, 30]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateSettings(settings.copyWith(defaultAppointmentMinutes: val));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 任务类型管理
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '任务类型',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CtdpColors.textSecondary),
                ),
                TextButton.icon(
                  onPressed: _showAddTypeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加类型'),
                ),
              ],
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: settings.unitTypes.map((type) {
                    return Chip(
                      label: Text(type),
                      onDeleted: settings.unitTypes.length > 1
                          ? () => controller.removeUnitType(type)
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 关于与系统入口
            const Text(
              '关于与系统',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CtdpColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // 新增：版本历史入口
                  ListTile(
                    leading: const Icon(Icons.history_toggle_off_outlined, color: CtdpColors.primary),
                    title: const Text('版本历史'),
                    subtitle: Text('当前版本 $currentVersion · 查看更新日志'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VersionHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: CtdpColors.danger),
                    title: const Text('清空历史记录', style: TextStyle(color: CtdpColors.danger)),
                    subtitle: const Text('重置所有已完成及复盘数据'),
                    onTap: _showClearAllConfirmDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}