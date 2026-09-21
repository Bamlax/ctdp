import 'package:flutter/material.dart';

import '../app/app.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';

class TaskEditScreen extends StatefulWidget {
  final CtdpController controller;
  final String? taskId;
  final String? initialFolderId;

  const TaskEditScreen({
    super.key,
    required this.controller,
    this.taskId,
    this.initialFolderId,
  });

  bool get isEditing => taskId != null;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _appointmentController;
  late final TextEditingController _tagInputController;
  late final TextEditingController _notesController;

  String? _selectedFolder;
  late TaskTimerMode _timerMode;
  late String _unitType;
  final List<String> _tags = [];

  CtdpTask? get task => widget.taskId == null
      ? null
      : widget.controller.taskById(widget.taskId!);

  @override
  void initState() {
    super.initState();
    final currentTask = task;
    final settings = widget.controller.settings;

    _titleController = TextEditingController(text: currentTask?.title ?? '');
    _durationController = TextEditingController(
      text: currentTask == null
          ? '${settings.defaultDurationMinutes}'
          : currentTask.durationSeconds > 0
              ? '${currentTask.durationSeconds ~/ 60}'
              : '${settings.defaultDurationMinutes}',
    );
    _appointmentController = TextEditingController(
      text: '${currentTask?.appointmentMinutes ?? settings.defaultAppointmentMinutes}',
    );
    _tagInputController = TextEditingController();
    _notesController = TextEditingController(text: currentTask?.notes ?? '');

    _timerMode = currentTask?.timerMode ?? TaskTimerMode.countDown;
    _unitType = currentTask?.unitType ??
        (settings.unitTypes.isNotEmpty ? settings.unitTypes.first : '综合');

    if (currentTask != null) {
      _tags.addAll(currentTask.tags);
    }

    final folders = widget.controller.getFolderOptions();
    if (currentTask?.folderId != null) {
      _selectedFolder = currentTask!.folderId;
    } else if (widget.initialFolderId != null &&
        widget.controller.folderById(widget.initialFolderId!) != null) {
      _selectedFolder = widget.initialFolderId;
    } else if (folders.isNotEmpty) {
      _selectedFolder = folders.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _appointmentController.dispose();
    _tagInputController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;
    if (!_tags.contains(text)) {
      setState(() {
        _tags.add(text);
      });
    }
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _showAddUnitTypeDialog() async {
    final textCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义任务类型'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例如：实验、阅读、复盘',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final text = textCtrl.text.trim();
                    if (text.isNotEmpty) Navigator.of(ctx).pop(text);
                  },
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await widget.controller.addUnitType(result);
      if (!mounted) return;
      setState(() => _unitType = result);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
    final appointment = int.tryParse(_appointmentController.text.trim()) ?? 0;

    if (title.isEmpty) {
      _showError('请输入任务名称。');
      return;
    }
    if (_selectedFolder == null ||
        widget.controller.folderById(_selectedFolder!) == null) {
      _showError('任务必须选择归属文件夹。');
      return;
    }
    if (_timerMode == TaskTimerMode.countDown && duration <= 0) {
      _showError('倒计时必须大于 0 分钟。');
      return;
    }
    if (appointment < 0) {
      _showError('预约时间不能小于 0。');
      return;
    }

    try {
      if (widget.isEditing) {
        await widget.controller.updateTask(
          taskId: widget.taskId!,
          title: title,
          folderId: _selectedFolder,
          timerMode: _timerMode,
          unitType: _unitType,
          durationMinutes: _timerMode == TaskTimerMode.countDown ? duration : 0,
          appointmentMinutes: appointment,
          tags: _tags,
          notes: _notesController.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        final newId = await widget.controller.createTask(
          title: title,
          folderId: _selectedFolder,
          timerMode: _timerMode,
          unitType: _unitType,
          durationMinutes: _timerMode == TaskTimerMode.countDown ? duration : 0,
          appointmentMinutes: appointment,
          tags: _tags,
          notes: _notesController.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop(newId);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CtdpColors.danger),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.controller.deleteTask(widget.taskId!);
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = widget.controller.getFolderOptions();
    final unitTypes = widget.controller.settings.unitTypes;

    // 安全防御：确保选中的文件夹必定有效存在于下拉项中，防止底层断言报错
    final effectiveFolder = folders.any((f) => f.id == _selectedFolder)
        ? _selectedFolder
        : (folders.isNotEmpty ? folders.first.id : null);

    if (!widget.isEditing && folders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('新建待办')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              '当前没有任何文件夹，任务不允许独立于文件夹存在。\n请先在「任务树」中新建一个文件夹。',
              textAlign: TextAlign.center,
              style: TextStyle(color: CtdpColors.textSecondary, height: 1.5),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑任务' : '新建待办'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: '删除任务',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            TextField(
              controller: _titleController,
              autofocus: !widget.isEditing,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '任务名称',
                hintText: '例如：高数课后习题',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              '任务类型（无色中性设计）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...unitTypes.map((type) {
                  final isSelected = _unitType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) setState(() => _unitType = type);
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('添加类型'),
                  onPressed: _showAddUnitTypeDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: effectiveFolder,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '所属文件夹（必选）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: folders.map((folder) {
                return DropdownMenuItem(
                  value: folder.id,
                  child: Text(folder.label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedFolder = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TaskTimerMode>(
                segments: const [
                  ButtonSegment<TaskTimerMode>(
                    value: TaskTimerMode.countDown,
                    label: Text('倒计时'),
                    icon: Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment<TaskTimerMode>(
                    value: TaskTimerMode.countUp,
                    label: Text('正计时'),
                    icon: Icon(Icons.timer_10_outlined),
                  ),
                ],
                selected: {_timerMode},
                onSelectionChanged: (selection) {
                  setState(() => _timerMode = selection.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_timerMode == TaskTimerMode.countDown)
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '任务时长',
                  suffixText: '分钟',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CtdpColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '正计时模式，完成时记录实际消耗时间。',
                  style: TextStyle(fontSize: 13, color: CtdpColors.textSecondary),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _appointmentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '预约倒计时',
                suffixText: '分钟',
                hintText: '0 为不设预约',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // 标签输入框：将添加按钮内嵌为 suffixIcon，从根源上杜绝 Row 布局引发的无限宽崩溃
            TextField(
              controller: _tagInputController,
              decoration: InputDecoration(
                labelText: '添加标签',
                hintText: '输入标签名称后回车或点击右侧按钮添加',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: CtdpColors.primary),
                  tooltip: '添加标签',
                  onPressed: _addTag,
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // 备注说明输入框
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注说明',
                hintText: '记录任务详情、核心要点或注意事项...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),

            // 确定与取消：左取消、右确定，均带外框保持原汁原味
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.isEditing ? '保存修改' : '确认创建'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}