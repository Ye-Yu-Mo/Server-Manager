class NodeMetric {
  final int id;
  final String nodeId;
  final DateTime metricTime;
  final double? cpuUsage;
  final double? memoryUsage;
  final double? diskUsage;
  final double? loadAverage;
  final DateTime createdAt;
  
  // 新增字段来支持实时数据
  final int? memoryTotal;
  final int? memoryAvailable;
  final int? uptime;

  NodeMetric({
    required this.id,
    required this.nodeId,
    required this.metricTime,
    this.cpuUsage,
    this.memoryUsage,
    this.diskUsage,
    this.loadAverage,
    required this.createdAt,
    this.memoryTotal,
    this.memoryAvailable,
    this.uptime,
  });

  factory NodeMetric.fromJson(Map<String, dynamic> json) {
    return NodeMetric(
      id: json['id'] ?? 0,
      nodeId: json['node_id'] ?? '',
      metricTime: json['metric_time'] != null 
          ? DateTime.parse(json['metric_time']) 
          : DateTime.now(),
      cpuUsage: json['cpu_usage']?.toDouble(),
      memoryUsage: json['memory_usage']?.toDouble(),
      diskUsage: json['disk_usage']?.toDouble(),
      loadAverage: json['load_average']?.toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      memoryTotal: json['memory_total']?.toInt(),
      memoryAvailable: json['memory_available']?.toInt(),
      uptime: json['uptime']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'metric_time': metricTime.toIso8601String(),
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'disk_usage': diskUsage,
      'load_average': loadAverage,
      'created_at': createdAt.toIso8601String(),
      'memory_total': memoryTotal,
      'memory_available': memoryAvailable,
      'uptime': uptime,
    };
  }

  double get cpuUsagePercent => cpuUsage ?? 0.0;
  double get memoryUsagePercent => memoryUsage ?? 0.0;
  double get diskUsagePercent => diskUsage ?? 0.0;

  String get formattedTime {
    return '${metricTime.hour.toString().padLeft(2, '0')}:${metricTime.minute.toString().padLeft(2, '0')}';
  }

  bool get hasData => cpuUsage != null || memoryUsage != null || diskUsage != null;
}
