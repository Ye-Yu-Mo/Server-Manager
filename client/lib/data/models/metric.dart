class NodeMetric {
  final int id;
  final String nodeId;
  final DateTime metricTime;
  final double? cpuUsage;
  final double? memoryUsage;
  final double? diskUsage;
  final double? loadAverage;
  final DateTime createdAt;

  NodeMetric({
    required this.id,
    required this.nodeId,
    required this.metricTime,
    this.cpuUsage,
    this.memoryUsage,
    this.diskUsage,
    this.loadAverage,
    required this.createdAt,
  });

  factory NodeMetric.fromJson(Map<String, dynamic> json) {
    return NodeMetric(
      id: json['id'],
      nodeId: json['node_id'],
      metricTime: DateTime.parse(json['metric_time']),
      cpuUsage: json['cpu_usage']?.toDouble(),
      memoryUsage: json['memory_usage']?.toDouble(),
      diskUsage: json['disk_usage']?.toDouble(),
      loadAverage: json['load_average']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
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
