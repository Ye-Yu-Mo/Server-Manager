import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';
import '../../data/models/node.dart';
import '../../data/models/metric.dart';

/// 应用初始化状态
enum AppInitState {
  loading,        // 正在加载设置
  needsSetup,     // 需要配置设置
  ready,          // 已配置，可以使用
  error,          // 配置错误
}

class NodeProvider with ChangeNotifier {
  final ApiService _apiService;
  late final WebSocketService _webSocketService;
  
  List<Node> _nodes = [];
  bool _isLoading = false;
  String? _error;
  Map<String, NodeMetric> _latestMetrics = {};
  
  // 应用初始化状态
  AppInitState _appInitState = AppInitState.loading;
  String _serverUrl = '';
  String _apiToken = '';
  
  // WebSocket相关状态
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  bool _autoRefreshEnabled = true;
  Timer? _autoRefreshTimer;
  int _refreshInterval = 30; // 默认30秒
  
  // Stream订阅
  StreamSubscription? _stateSubscription;
  StreamSubscription? _nodesSubscription;
  StreamSubscription? _metricsSubscription;
  StreamSubscription? _errorSubscription;

  NodeProvider(this._apiService) {
    _webSocketService = WebSocketService();
    _initializeWebSocket();
    _loadSettings();
  }

  // Getters
  List<Node> get nodes => _nodes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AppInitState get appInitState => _appInitState;
  String get serverUrl => _serverUrl;
  String get apiToken => _apiToken;
  bool get isConfigured => _serverUrl.isNotEmpty;
  WebSocketConnectionState get connectionState => _connectionState;
  bool get isWebSocketConnected => _connectionState == WebSocketConnectionState.connected;
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  int get refreshInterval => _refreshInterval;
  
  // 获取节点的最新监控数据
  NodeMetric? getMetricForNode(String nodeId) => _latestMetrics[nodeId];

  // 加载所有节点
  Future<void> loadNodes() async {
    _setLoading(true);
    _error = null;
    
    try {
      _nodes = await _apiService.getNodes();
      await _loadLatestMetrics();
      notifyListeners();
    } catch (e) {
      _error = '加载节点失败: $e';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 加载所有节点的最新监控数据
  Future<void> _loadLatestMetrics() async {
    try {
      final metrics = await _apiService.getAllLatestMetrics();
      _latestMetrics = {
        for (var metric in metrics) metric.nodeId: metric
      };
    } catch (e) {
      print('加载监控数据失败: $e');
      // 不抛出错误，因为节点列表仍然可以显示
    }
  }

  // 刷新单个节点的监控数据
  Future<void> refreshNodeMetrics(String nodeId) async {
    try {
      final metric = await _apiService.getLatestMetrics(nodeId);
      if (metric != null) {
        _latestMetrics[nodeId] = metric;
        notifyListeners();
      }
    } catch (e) {
      print('刷新节点 $nodeId 监控数据失败: $e');
    }
  }

  // 删除节点
  Future<bool> deleteNode(String nodeId) async {
    try {
      final success = await _apiService.deleteNode(nodeId);
      if (success) {
        _nodes.removeWhere((node) => node.nodeId == nodeId);
        _latestMetrics.remove(nodeId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = '删除节点失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 获取在线节点数量
  int get onlineCount => _nodes.where((node) => node.isOnline).length;

  // 获取离线节点数量
  int get offlineCount => _nodes.where((node) => !node.isOnline).length;

  // 根据状态过滤节点
  List<Node> getNodesByStatus(String status) {
    return _nodes.where((node) => node.status == status).toList();
  }

  // 根据节点ID查找节点
  Node? findNodeById(String nodeId) {
    return _nodes.firstWhere((node) => node.nodeId == nodeId);
  }

  // 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 检查服务健康状态
  Future<bool> checkHealth() async {
    return await _apiService.healthCheck();
  }


  // 获取API服务实例（用于页面直接调用）
  ApiService get apiService => _apiService;

  /// 初始化WebSocket连接
  void _initializeWebSocket() {
    _stateSubscription = _webSocketService.stateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _nodesSubscription = _webSocketService.nodesStream.listen((nodes) {
      _nodes = nodes;
      notifyListeners();
    });

    _metricsSubscription = _webSocketService.metricsStream.listen((metrics) {
      _latestMetrics = metrics;
      notifyListeners();
    });

    _errorSubscription = _webSocketService.errorStream.listen((error) {
      _error = error;
      notifyListeners();
    });
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      _appInitState = AppInitState.loading;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      _autoRefreshEnabled = prefs.getBool('auto_refresh') ?? true;
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;
      
      // 读取服务器配置
      _serverUrl = prefs.getString('server_url') ?? '';
      _apiToken = prefs.getString('api_token') ?? '';
      
      // 检查是否已配置
      if (_serverUrl.isEmpty) {
        _appInitState = AppInitState.needsSetup;
        print('应用需要配置：服务器地址未设置');
      } else {
        // 配置API和WebSocket服务
        _apiService.setBaseUrl(_serverUrl);
        if (_apiToken.isNotEmpty) {
          _apiService.setApiToken(_apiToken);
        }
        _webSocketService.configure(baseUrl: _serverUrl, apiToken: _apiToken);
        
        _appInitState = AppInitState.ready;
        print('配置加载完成：$_serverUrl');
        
        // 尝试加载节点数据
        await _tryLoadNodes();
        
        // 启动自动刷新
        _updateAutoRefresh();
      }
      
      notifyListeners();
    } catch (e) {
      print('加载设置失败: $e');
      _appInitState = AppInitState.error;
      _error = '加载设置失败: $e';
      notifyListeners();
    }
  }
  
  /// 尝试加载节点数据
  Future<void> _tryLoadNodes() async {
    try {
      await loadNodes();
    } catch (e) {
      // 不在这里设置错误状态，让loadNodes自己处理
      print('初始加载节点失败: $e');
    }
  }

  /// 更新自动刷新状态
  void _updateAutoRefresh() {
    _autoRefreshTimer?.cancel();
    
    if (_autoRefreshEnabled) {
      // 尝试WebSocket连接
      if (!isWebSocketConnected) {
        _webSocketService.connect();
      }
      
      // 使用定时器定期刷新（无论WebSocket是否连接）
      _autoRefreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
        loadNodes(); // 定期刷新数据
      });
    } else {
      _webSocketService.disconnect();
    }
  }

  /// 设置自动刷新
  Future<void> setAutoRefresh(bool enabled, {int? interval}) async {
    _autoRefreshEnabled = enabled;
    if (interval != null) {
      _refreshInterval = interval;
    }
    
    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_refresh', _autoRefreshEnabled);
    if (interval != null) {
      await prefs.setInt('refresh_interval', _refreshInterval);
    }
    
    _updateAutoRefresh();
    notifyListeners();
  }

  /// 更新配置并重新初始化
  Future<void> updateConfiguration(String serverUrl, String apiToken) async {
    try {
      _serverUrl = serverUrl;
      _apiToken = apiToken;
      
      // 保存到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', _serverUrl);
      await prefs.setString('api_token', _apiToken);
      
      // 配置服务
      _apiService.setBaseUrl(_serverUrl);
      _apiService.setApiToken(_apiToken);
      _webSocketService.configure(baseUrl: _serverUrl, apiToken: _apiToken);
      
      // 更新状态
      _appInitState = AppInitState.ready;
      _error = null;
      
      notifyListeners();
      
      // 尝试连接和加载数据
      await _tryLoadNodes();
      _updateAutoRefresh();
      
    } catch (e) {
      _appInitState = AppInitState.error;
      _error = '更新配置失败: $e';
      notifyListeners();
    }
  }

  /// 设置API基础URL同时配置WebSocket
  void setBaseUrl(String url) {
    _apiService.setBaseUrl(url);
    _webSocketService.configure(baseUrl: url);
  }

  /// 设置API Token同时配置WebSocket
  void setApiToken(String token) {
    _apiService.setApiToken(token);
    _webSocketService.configure(apiToken: token);
  }


  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _stateSubscription?.cancel();
    _nodesSubscription?.cancel();
    _metricsSubscription?.cancel();
    _errorSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
