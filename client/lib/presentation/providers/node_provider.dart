import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';
import '../../data/models/node.dart';
import '../../data/models/metric.dart';

class NodeProvider with ChangeNotifier {
  final ApiService _apiService;
  late final WebSocketService _webSocketService;
  
  List<Node> _nodes = [];
  bool _isLoading = false;
  String? _error;
  Map<String, NodeMetric> _latestMetrics = {};
  
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
      final prefs = await SharedPreferences.getInstance();
      _autoRefreshEnabled = prefs.getBool('auto_refresh') ?? true;
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;
      
      // 配置WebSocket服务
      final serverUrl = prefs.getString('server_url') ?? '';
      final apiToken = prefs.getString('api_token');
      _webSocketService.configure(baseUrl: serverUrl, apiToken: apiToken);
      
      // 根据设置启动自动刷新
      _updateAutoRefresh();
    } catch (e) {
      print('加载设置失败: $e');
    }
  }

  /// 更新自动刷新状态
  void _updateAutoRefresh() {
    _autoRefreshTimer?.cancel();
    
    if (_autoRefreshEnabled) {
      // 优先使用WebSocket连接
      if (!isWebSocketConnected) {
        _webSocketService.connect();
      }
      
      // 如果WebSocket连接失败，使用定时器轮询
      _autoRefreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
        if (!isWebSocketConnected) {
          loadNodes(); // 降级到RESTful API
        }
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

  /// 设置API基础URL同时配置WebSocket
  void setBaseUrl(String url) {
    _apiService.setBaseUrl(url);
    _webSocketService.configure(baseUrl: url);
    
    // 如果自动刷新已启用，重新连接WebSocket
    if (_autoRefreshEnabled) {
      _webSocketService.reconnect();
    }
  }

  /// 设置API Token同时配置WebSocket
  void setApiToken(String token) {
    _apiService.setApiToken(token);
    _webSocketService.configure(apiToken: token);
    
    // 如果自动刷新已启用，重新连接WebSocket
    if (_autoRefreshEnabled) {
      _webSocketService.reconnect();
    }
  }

  /// 手动重新连接WebSocket
  Future<void> reconnectWebSocket() async {
    await _webSocketService.reconnect();
  }

  /// 强制使用RESTful API刷新（用于测试或WebSocket失败时）
  Future<void> forceRefresh() async {
    await loadNodes();
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
