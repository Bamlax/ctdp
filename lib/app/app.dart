import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../screens/focus_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/task_tree_screen.dart';
import '../services/ctdp_engine.dart';

// ============================================================
// 主题与配色
// ============================================================

class CtdpColors {
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFFE3F2FD);
  static const background = Color(0xFFF7F9FC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF687386);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
}

class CtdpTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CtdpColors.primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CtdpColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: CtdpColors.background,
        foregroundColor: CtdpColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: CtdpColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: CtdpColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CtdpColors.primary,
              );
            }
            return const TextStyle(
              fontSize: 12,
              color: CtdpColors.textSecondary,
            );
          },
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 应用根组件
// ============================================================

class CtdpApp extends StatefulWidget {
  const CtdpApp({super.key});

  @override
  State<CtdpApp> createState() => _CtdpAppState();
}

class _CtdpAppState extends State<CtdpApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final CtdpController _controller;
  StreamSubscription<Uri?>? _widgetSub;

  @override
  void initState() {
    super.initState();
    _controller = CtdpController();
    _initAppAndWidgetListeners();
  }

  Future<void> _initAppAndWidgetListeners() async {
    // 1. 通知点击监听
    _controller.notifications.onNotificationSelected = (taskId) {
      _navigateToTask(taskId);
    };

    await _controller.initialize();

    // 2. 监听应用在后台/前台运行时点击桌面小组件
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);

    // 3. 检查应用完全关闭（冷启动）时点击桌面小组件或通知
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 检查小组件冷启动
      final initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialWidgetUri != null) {
        _handleWidgetUri(initialWidgetUri);
        return;
      }

      // 检查通知栏冷启动
      final initialTaskId = await _controller.notifications.getInitialPayload();
      if (initialTaskId != null) {
        _navigateToTask(initialTaskId);
      }
    });
  }

void _handleWidgetUri(Uri? uri) async {
    if (uri != null && uri.toString().contains('quick_reservation')) {
      try {
        // 1. 获取首个未完成任务
        final firstTask = _controller.getFirstPendingTask();
        if (firstTask == null) {
          final context = _navigatorKey.currentContext;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前没有待办任务，请先创建待办。')),
            );
          }
          return;
        }

        // 2. 启动该任务的预约（若设置了时延则进入预约倒计时，若为0则直接进入正/倒计时）
        await _controller.startTask(firstTask.id);

        // 3. 立即自动跳转并显示倒计时/预约计时界面
        _navigateToTask(firstTask.id);
      } catch (e) {
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
  }

  void _navigateToTask(String taskId) {
    if (_controller.taskById(taskId) == null) return;

    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          controller: _controller,
          taskId: taskId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _widgetSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'CTDP',
      debugShowCheckedModeBanner: false,
      theme: CtdpTheme.light(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return CtdpHome(controller: _controller);
        },
      ),
    );
  }
}

class CtdpHome extends StatefulWidget {
  final CtdpController controller;

  const CtdpHome({
    super.key,
    required this.controller,
  });

  @override
  State<CtdpHome> createState() => _CtdpHomeState();
}

class _CtdpHomeState extends State<CtdpHome> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  static const _titles = ['CTDP', '任务树', '历史', '设置'];

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(controller: widget.controller),
      TaskTreeScreen(controller: widget.controller),
      HistoryScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '待办',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: '任务树',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}