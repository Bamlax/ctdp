import 'package:flutter/material.dart';

import '../app/app.dart';
import '../models/ctdp_state.dart';
import '../services/ctdp_engine.dart';
import 'focus_screen.dart';
import 'task_edit_screen.dart';

class TaskTreeScreen extends StatefulWidget {
  final CtdpController controller;
  final ScrollController? scrollController;

  const TaskTreeScreen({
    super.key,
    required this.controller,
    this.scrollController,
  });

  @override
  State<TaskTreeScreen> createState() => _TaskTreeScreenState();
}

class _TaskTreeScreenState extends State<TaskTreeScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _showFolderDialog({
    String? editFolderId,
    String? parentId,
    String? childFolderId,
  }) async {
    final folder = editFolderId != null ? widget.controller.folderById(editFolderId) : null;
    final textController = TextEditingController(text: folder?.name ?? '');

    String title = '新建文件夹';
    if (editFolderId != null) {
      title = '重命名文件夹';
    } else if (childFolderId != null) {
      title = '新建父级文件夹';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
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
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = textController.text.trim();
    if (name.isEmpty) return;

    try {
      if (editFolderId != null) {
        await widget.controller.renameFolder(folderId: editFolderId, name: name);
      } else if (childFolderId != null) {
        await widget.controller.createParentFolder(targetFolderId: childFolderId, name: name);
      } else {
        await widget.controller.createFolder(name: name, parentId: parentId);
      }
      // 新建文件夹后自动滑到最下方
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _createTask({required String folderId}) async {
    final taskId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          controller: widget.controller,
          initialFolderId: folderId,
        ),
      ),
    );

    if (taskId == null || !mounted) return;
    final task = widget.controller.taskById(taskId);
    if (task == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已创建任务「${task.title}」。')),
    );
    // 新建任务后自动滑到最下方
    _scrollToBottom();
  }

  Future<void> _showConcludeChainDialog(CtdpTask task) async {
    final taskNum = widget.controller.getTaskNumber(task);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('完成该链 (主动结链)'),
        content: Text(
          '是否确认结束当前任务链？\n\n'
          '当前链已圆满完成 #$taskNum 环。主动结链为正常达成阶段目标，结束后下一个待办任务将从 #1 重新开始。',
          style: const TextStyle(height: 1.5),
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
                  child: const Text('确认结链'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.concludeChain(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前链已圆满完成（共 #$taskNum 环）！下一个任务将从 #1 开启。')),
      );
    }
  }

  Future<void> _deleteFolder(CtdpFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('确定删除「${folder.name}」吗？子文件夹及任务将全部删除。'),
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

    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteFolder(folder.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除「${folder.name}」。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openTask(CtdpTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          controller: widget.controller,
          taskId: task.id,
        ),
      ),
    );
  }

  Future<void> _editTask(CtdpTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          controller: widget.controller,
          taskId: task.id,
        ),
      ),
    );
  }

  Widget _buildStaticHistoricalTask(CtdpTask task) {
    final isFailed = task.isFailed;
    final taskNum = widget.controller.getTaskNumber(task);
    final canConcludeChain = widget.controller.isLastCompletedTaskOfChain(task);

    String overtimeLabel = '';
    if (task.overtimeSeconds > 0) {
      final mins = task.overtimeSeconds ~/ 60;
      overtimeLabel = mins > 0 ? ' (超时 ${mins}m)' : ' (超时 ${task.overtimeSeconds}s)';
    }

    return Padding(
      key: ValueKey('static_task_${task.id}'),
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 2),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isFailed ? CtdpColors.danger.withValues(alpha: 0.5) : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '#$taskNum ${task.title}$overtimeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isFailed ? FontWeight.w700 : FontWeight.w600,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: isFailed ? CtdpColors.danger : CtdpColors.textSecondary,
                  ),
                ),
              ),
              if (task.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: task.tags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(fontSize: 10, color: CtdpColors.textSecondary),
                      ),
                    );
                  }).toList(),
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
                    '结链',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                  ),
                ),
            ],
          ),
          subtitle: task.notes.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    task.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                )
              : null,
          trailing: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 18,
            onSelected: (value) {
              if (value == 'open') _openTask(task);
              if (value == 'edit') _editTask(task);
              if (value == 'conclude_chain') _showConcludeChainDialog(task);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('打开任务')),
              const PopupMenuItem(value: 'edit', child: Text('编辑任务')),
              if (canConcludeChain) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'conclude_chain',
                  child: Text('完成该链 (结链)', style: TextStyle(color: Colors.green)),
                ),
              ],
            ],
          ),
          onTap: () => _openTask(task),
        ),
      ),
    );
  }

  Widget _buildMovablePendingTask(CtdpTask task, int indexInFolder) {
    final taskNum = widget.controller.getTaskNumber(task);

    final cardContent = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '#$taskNum ${task.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CtdpColors.textPrimary,
                ),
              ),
            ),
            if (task.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: task.tags.take(2).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 10, color: CtdpColors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        subtitle: task.notes.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  task.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              )
            : null,
        trailing: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          iconSize: 18,
          onSelected: (value) {
            if (value == 'open') _openTask(task);
            if (value == 'edit') _editTask(task);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('打开任务')),
            PopupMenuItem(value: 'edit', child: Text('编辑任务')),
          ],
        ),
        onTap: () => _openTask(task),
      ),
    );

    return DragTarget<CtdpTask>(
      key: ValueKey('movable_task_${task.id}'),
      onWillAcceptWithDetails: (details) => details.data.id != task.id,
      onAcceptWithDetails: (details) {
        widget.controller.moveTaskInTree(
          taskId: details.data.id,
          targetFolderId: task.folderId!,
          targetIndexInFolder: indexInFolder,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHovered)
                Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: CtdpColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              LongPressDraggable<CtdpTask>(
                data: task,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 48,
                    child: Opacity(opacity: 0.9, child: cardContent),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.25, child: cardContent),
                child: cardContent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolder(CtdpFolder folder, int depth) {
    final children = widget.controller.childrenOf(folder.id);
    final tasks = widget.controller.tasksInFolder(folder.id);
    final prefix = widget.controller.folderPrefix(folder.id);

    final historicalTasks = tasks.where((t) => !t.isPending).toList();
    final pendingTasks = tasks.where((t) => t.isPending).toList();

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DragTarget<CtdpTask>(
            key: ValueKey('folder_${folder.id}'),
            onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
            onAcceptWithDetails: (details) {
              widget.controller.moveTaskInTree(
                taskId: details.data.id,
                targetFolderId: folder.id,
                targetIndexInFolder: tasks.length,
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: isHovered ? CtdpColors.primaryLight : CtdpColors.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isHovered ? CtdpColors.primary : Colors.grey.shade300,
                    width: isHovered ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  title: Text(
                    '$prefix ${folder.name}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CtdpColors.textPrimary,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (value) {
                      switch (value) {
                        case 'child':
                          _showFolderDialog(parentId: folder.id);
                          break;
                        case 'parent':
                          _showFolderDialog(childFolderId: folder.id);
                          break;
                        case 'task':
                          _createTask(folderId: folder.id);
                          break;
                        case 'edit':
                          _showFolderDialog(editFolderId: folder.id);
                          break;
                        case 'delete':
                          _deleteFolder(folder);
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'child', child: Text('新建子文件夹')),
                      PopupMenuItem(value: 'parent', child: Text('新建父级文件夹')),
                      PopupMenuItem(value: 'task', child: Text('新建所属待办')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'edit', child: Text('重命名')),
                      PopupMenuItem(value: 'delete', child: Text('删除文件夹')),
                    ],
                  ),
                ),
              );
            },
          ),
          ...historicalTasks.map((t) => _buildStaticHistoricalTask(t)),
          ...List.generate(pendingTasks.length, (i) {
            final t = pendingTasks[i];
            final realIndex = historicalTasks.length + i;
            return _buildMovablePendingTask(t, realIndex);
          }),
          ...children.map((child) => _buildFolder(child, depth + 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final rootFolders = widget.controller.childrenOf(null);

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showFolderDialog(),
            tooltip: '新建文件夹',
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('新建文件夹'),
          ),
          body: SafeArea(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                if (rootFolders.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Text(
                          '暂无文件夹，点击右下角创建首个文件夹。',
                          style: TextStyle(color: CtdpColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  ...rootFolders.map((f) => _buildFolder(f, 0)),
              ],
            ),
          ),
        );
      },
    );
  }
}