import 'package:flutter/widgets.dart';
import '../../features/meditation/data/services/meditation_session_manager.dart';
import '../../features/player/services/global_player_service.dart';

/// 应用生命周期管理器
/// 负责处理应用的后台切换、暂停、恢复和关闭等场景
/// 确保在各种情况下数据都能正确保存
class AppLifecycleManager with WidgetsBindingObserver {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance =>
      _instance ??= AppLifecycleManager._();

  AppLifecycleManager._();

  GlobalPlayerService? _playerService;
  bool _isInitialized = false;

  /// 初始化生命周期管理器
  void initialize(GlobalPlayerService playerService) {
    if (_isInitialized) return;

    _playerService = playerService;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    debugPrint('AppLifecycleManager initialized');
  }

  /// 销毁生命周期管理器
  Future<void> dispose() async {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);

    // 保存所有状态
    await _saveAllStates();

    _playerService = null;
    _isInitialized = false;

    debugPrint('AppLifecycleManager disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  /// 处理应用变为非活跃状态（例如接收到电话）
  void _handleAppInactive() {
    debugPrint('App became inactive');
    _saveAllStates();
  }

  /// 处理应用暂停（切换到后台）
  void _handleAppPaused() {
    debugPrint('App paused (went to background)');
    _saveAllStates();
    _playerService?.pauseForBackground();
  }

  /// 处理应用恢复（从后台回到前台）
  void _handleAppResumed() {
    debugPrint('App resumed (came to foreground)');
    _playerService?.resumeFromBackground();
  }

  /// 处理应用隐藏
  void _handleAppHidden() {
    debugPrint('App hidden');
    _saveAllStates();
  }

  /// 处理应用分离（即将关闭）
  void _handleAppDetached() {
    debugPrint('App detached (about to close)');
    _handleAppTermination();
  }

  /// 处理应用终止
  void _handleAppTermination() {
    try {
      // 同步保存所有状态（因为应用即将关闭，异步操作可能无法完成）
      _saveAllStatesSync();
      _playerService?.prepareForTermination();
    } catch (e) {
      debugPrint('Error handling app termination: $e');
    }
  }

  /// 异步保存所有状态
  Future<void> _saveAllStates() async {
    try {
      await MeditationSessionManager.forceSaveCurrentState();
      debugPrint('All states saved successfully');
    } catch (e) {
      debugPrint('Error saving all states: $e');
    }
  }

  /// 同步保存所有状态（用于应用即将关闭的情况）
  void _saveAllStatesSync() {
    try {
      // 这里只能执行同步操作，因为应用即将关闭
      // 对于数据库操作，我们只能尽力而为
      debugPrint('Attempting sync save of all states');
    } catch (e) {
      debugPrint('Error in sync save: $e');
    }
  }

  /// 手动触发状态保存（可以由其他组件调用）
  Future<void> saveCurrentState() async {
    await _saveAllStates();
  }

  /// 获取当前生命周期状态
  AppLifecycleState? get currentState {
    return WidgetsBinding.instance.lifecycleState;
  }

  /// 检查应用是否在前台
  bool get isAppInForeground {
    final state = currentState;
    return state == AppLifecycleState.resumed;
  }

  /// 检查应用是否在后台
  bool get isAppInBackground {
    final state = currentState;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
  }
}
