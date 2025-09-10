import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/models/node.dart';
import '../../data/models/metric.dart';

class NodeProvider with ChangeNotifier {
  final ApiService _apiService;
  
  List<Node> _nodes = [];
  bool _isLoading = false;
  String? _error;
  Map<String, NodeMetric> _latestMetrics = {};

  NodeProvider(this._apiService);

  // Getters
  List<Node> get nodes => _nodes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
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

  // 设置API基础URL
  void setBaseUrl(String url) {
    _apiService.setBaseUrl(url);
  }

  // 设置API Token
  void setApiToken(String token) {
    _apiService.setApiToken(token);
  }

  // 获取API服务实例（用于页面直接调用）
  ApiService get apiService => _apiService;
}
