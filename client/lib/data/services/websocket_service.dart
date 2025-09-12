import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/node.dart';
import '../models/metric.dart';

/// WebSocket连接状态
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// WebSocket消息类型
class WebSocketMessage {
  final String type;
  final String id;
  final String timestamp;
  final Map<String, dynamic> data;

  WebSocketMessage({
    required this.type,
    required this.id,
    required this.timestamp,
    required this.data,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'timestamp': timestamp,
      'data': data,
    };
  }
}

/// WebSocket客户端服务
class WebSocketService {
  WebSocketChannel? _channel;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  
  // 连接配置
  String _baseUrl = 'http://47.92.242.94:20001/api/v1';
  String? _apiToken;
  
  // 重连配置
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  
  // 事件流控制器
  final StreamController<WebSocketConnectionState> _stateController = 
      StreamController<WebSocketConnectionState>.broadcast();
  final StreamController<List<Node>> _nodesController = 
      StreamController<List<Node>>.broadcast();
  final StreamController<Map<String, NodeMetric>> _metricsController = 
      StreamController<Map<String, NodeMetric>>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  // 数据缓存
  List<Node> _nodes = [];
  Map<String, NodeMetric> _metrics = {};

  // Getters
  WebSocketConnectionState get connectionState => _state;
  bool get isConnected => _state == WebSocketConnectionState.connected;
  List<Node> get nodes => _nodes;
  Map<String, NodeMetric> get metrics => _metrics;
  
  // 事件流
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<List<Node>> get nodesStream => _nodesController.stream;
  Stream<Map<String, NodeMetric>> get metricsStream => _metricsController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// 设置连接配置
  void configure({String? baseUrl, String? apiToken}) {
    if (baseUrl != null) {
      _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    }
    _apiToken = apiToken;
  }

  /// 连接到WebSocket服务器
  Future<void> connect() async {
    if (_state == WebSocketConnectionState.connecting || 
        _state == WebSocketConnectionState.connected) {
      return;
    }

    _updateState(WebSocketConnectionState.connecting);
    
    try {
      // 构建WebSocket URL
      final wsUrl = _buildWebSocketUrl();
      print('🔌 WebSocket连接中: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // 设置统一的消息监听器，不再单独等待连接
      _setupMessageListener();
      
      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      
      // 启动心跳
      _startHeartbeat();
      
      print('✅ WebSocket连接成功');
      
    } catch (e) {
      print('❌ WebSocket连接失败: $e');
      _updateState(WebSocketConnectionState.error);
      _errorController.add('连接失败: $e');
      
      // 自动重连
      _scheduleReconnect();
    }
  }

  /// 构建WebSocket URL
  String _buildWebSocketUrl() {
    // 将HTTP URL转换为WebSocket URL
    String wsUrl = _baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    
    // 移除 /api/v1 后缀，因为WebSocket端点在根路径
    wsUrl = wsUrl.replaceAll('/api/v1', '');
    
    // 确保不以斜杠结尾
    if (wsUrl.endsWith('/')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 1);
    }
    
    // 添加WebSocket路径和参数
    wsUrl += '/ws/client?type=monitor';
    
    if (_apiToken != null && _apiToken!.isNotEmpty) {
      wsUrl += '&token=$_apiToken';
    } else {
      wsUrl += '&token=default-token';
    }
    
    return wsUrl;
  }

  /// 设置消息监听器
  void _setupMessageListener() {
    _channel?.stream.listen(
      (data) {
        try {
          final message = _parseMessage(data);
          _handleMessage(message);
        } catch (e) {
          print('解析消息失败: $e');
          _errorController.add('消息解析失败: $e');
        }
      },
      onError: (error) {
        print('❌ WebSocket错误: $error');
        _updateState(WebSocketConnectionState.error);
        _errorController.add('连接错误: $error');
        _scheduleReconnect();
      },
      onDone: () {
        print('🔌 WebSocket连接关闭');
        _updateState(WebSocketConnectionState.disconnected);
        _scheduleReconnect();
      },
    );
  }

  /// 解析消息
  WebSocketMessage _parseMessage(dynamic data) {
    if (data is String) {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return WebSocketMessage.fromJson(json);
    } else {
      throw Exception('不支持的消息格式');
    }
  }

  /// 处理收到的消息
  void _handleMessage(WebSocketMessage message) {
    print('📨 收到消息: ${message.type}');
    
    switch (message.type) {
      case 'welcome':
        print('🎉 ${message.data['message']}');
        break;
        
      case 'nodes_update':
        _handleNodesUpdate(message);
        break;
        
      case 'metrics_update':
        _handleMetricsUpdate(message);
        break;
        
      case 'node_status_change':
        _handleNodeStatusChange(message);
        break;
        
      case 'error':
        _handleError(message);
        break;
        
      default:
        print('未知消息类型: ${message.type}');
    }
  }

  /// 处理节点列表更新
  void _handleNodesUpdate(WebSocketMessage message) {
    try {
      final nodesData = message.data['nodes'] as List;
      _nodes = nodesData.map((nodeJson) => Node.fromJson(nodeJson)).toList();
      _nodesController.add(_nodes);
      print('✅ 节点列表已更新: ${_nodes.length}个节点');
    } catch (e) {
      print('处理节点更新失败: $e');
      _errorController.add('节点数据更新失败: $e');
    }
  }

  /// 处理监控数据更新
  void _handleMetricsUpdate(WebSocketMessage message) {
    try {
      final metricsData = message.data['metrics'] as List;
      for (final metricJson in metricsData) {
        final metric = NodeMetric.fromJson(metricJson);
        _metrics[metric.nodeId] = metric;
      }
      _metricsController.add(_metrics);
      print('✅ 监控数据已更新: ${metricsData.length}条记录');
    } catch (e) {
      print('处理监控数据更新失败: $e');
      _errorController.add('监控数据更新失败: $e');
    }
  }

  /// 处理节点状态变化
  void _handleNodeStatusChange(WebSocketMessage message) {
    try {
      final nodeId = message.data['node_id'] as String;
      final status = message.data['status'] as String;
      
      // 更新本地节点状态
      final nodeIndex = _nodes.indexWhere((node) => node.nodeId == nodeId);
      if (nodeIndex != -1) {
        _nodes[nodeIndex] = _nodes[nodeIndex].copyWith(status: status);
        _nodesController.add(_nodes);
        print('✅ 节点状态已更新: $nodeId -> $status');
      }
    } catch (e) {
      print('处理节点状态变化失败: $e');
      _errorController.add('节点状态更新失败: $e');
    }
  }

  /// 处理错误消息
  void _handleError(WebSocketMessage message) {
    final errorCode = message.data['error_code'] ?? 'UNKNOWN_ERROR';
    final errorMessage = message.data['message'] ?? '未知错误';
    final details = message.data['details'] ?? '';
    
    print('❌ 服务器错误: $errorCode - $errorMessage');
    if (details.isNotEmpty) {
      print('   详情: $details');
    }
    
    _errorController.add('$errorMessage${details.isNotEmpty ? ': $details' : ''}');
  }

  /// 更新连接状态
  void _updateState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (!isConnected) {
        timer.cancel();
        return;
      }
      
      _sendHeartbeat();
    });
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!isConnected) return;
    
    final heartbeat = {
      'type': 'ping',
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'client_type': 'monitor',
      }
    };
    
    try {
      _channel?.sink.add(jsonEncode(heartbeat));
      print('💓 心跳发送');
    } catch (e) {
      print('心跳发送失败: $e');
    }
  }

  /// 计划重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ 达到最大重连次数，停止重连');
      _errorController.add('连接失败，已达到最大重试次数');
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    print('🔄 ${_reconnectInterval.inSeconds}秒后尝试重连 ($_reconnectAttempts/$_maxReconnectAttempts)');
    
    _reconnectTimer = Timer(_reconnectInterval, () {
      connect();
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    print('🔌 断开WebSocket连接');
    
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
    }
    
    _updateState(WebSocketConnectionState.disconnected);
    _reconnectAttempts = 0;
  }

  /// 清理资源
  void dispose() {
    disconnect();
    _stateController.close();
    _nodesController.close();
    _metricsController.close();
    _errorController.close();
  }

  /// 重置重连计数
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  /// 手动触发重连
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }
}