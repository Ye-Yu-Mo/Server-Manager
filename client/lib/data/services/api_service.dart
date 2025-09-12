import 'package:dio/dio.dart';
import '../models/node.dart';
import '../models/metric.dart';

class ApiService {
  final Dio _dio;
  String _baseUrl = '';
  String? _apiToken;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: '',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    // 添加拦截器用于认证和日志记录
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加认证头
        if (_apiToken != null && _apiToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_apiToken';
        }
        
        print('🚀 请求: ${options.method} ${options.uri}');
        print('📍 Base URL: $_baseUrl');
        print('🔧 完整URL: ${options.uri}');
        if (_apiToken != null) {
          print('🔑 使用Token: $_apiToken');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ 响应: ${response.statusCode} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print('❌ 错误: ${e.type} ${e.message}');
        if (e.response != null) {
          print('📋 错误响应: ${e.response?.statusCode} ${e.response?.data}');
        }
        return handler.next(e);
      },
    ));
  }

  // 设置基础URL
  void setBaseUrl(String url) {
    // 确保URL格式正确：去掉末尾斜杠，因为请求路径都以'/'开头
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    // 更新Dio的基础URL配置
    _dio.options.baseUrl = _baseUrl;
  }

  // 设置API Token
  void setApiToken(String token) {
    _apiToken = token;
  }

  // 获取所有节点
  Future<List<Node>> getNodes({String? status}) async {
    try {
      final response = await _dio.get('/nodes', queryParameters: {
        if (status != null) 'status': status,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['nodes'] is List) {
          return (data['nodes'] as List)
              .map((nodeJson) => Node.fromJson(nodeJson))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      print('获取节点列表失败: ${e.message}');
      rethrow;
    }
  }

  // 获取单个节点信息
  Future<Node?> getNode(String nodeId) async {
    try {
      final response = await _dio.get('/nodes/$nodeId');
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          return Node.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      print('获取节点信息失败: ${e.message}');
      rethrow;
    }
  }

  // 获取节点最新监控数据
  Future<NodeMetric?> getLatestMetrics(String nodeId) async {
    try {
      final response = await _dio.get('/nodes/$nodeId/metrics/latest');
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          return NodeMetric.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      print('获取监控数据失败: ${e.message}');
      rethrow;
    }
  }

  // 获取节点监控历史数据
  Future<List<NodeMetric>> getNodeMetrics(
    String nodeId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'limit': limit,
        'offset': offset,
      };

      if (startTime != null) {
        queryParams['start_time'] = startTime.toIso8601String();
      }
      if (endTime != null) {
        queryParams['end_time'] = endTime.toIso8601String();
      }

      final response = await _dio.get(
        '/nodes/$nodeId/metrics',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['metrics'] is List) {
          return (data['metrics'] as List)
              .map((metricJson) => NodeMetric.fromJson(metricJson))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      print('获取监控历史数据失败: ${e.message}');
      rethrow;
    }
  }

  // 获取所有节点最新监控数据
  Future<List<NodeMetric>> getAllLatestMetrics() async {
    try {
      final response = await _dio.get('/metrics/latest');
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['metrics'] is List) {
          return (data['metrics'] as List)
              .map((metricJson) => NodeMetric.fromJson(metricJson))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      print('获取所有节点监控数据失败: ${e.message}');
      rethrow;
    }
  }

  // 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  // 删除节点
  Future<bool> deleteNode(String nodeId) async {
    try {
      final response = await _dio.delete('/nodes/$nodeId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('删除节点失败: ${e.message}');
      rethrow;
    }
  }
}
