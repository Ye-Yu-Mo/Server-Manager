import '../../../utils/format_utils.dart';

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
  final int? diskTotal;
  final int? diskAvailable;
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
    this.diskTotal,
    this.diskAvailable,
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
      diskTotal: json['disk_total']?.toInt(),
      diskAvailable: json['disk_available']?.toInt(),
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
      'disk_total': diskTotal,
      'disk_available': diskAvailable,
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

  // 格式化的数据显示方法
  String get formattedCpuUsage => FormatUtils.formatCpuUsage(cpuUsage);
  String get formattedLoadAverage => FormatUtils.formatLoadAverage(loadAverage);
  String get formattedUptime => FormatUtils.formatUptime(uptime);
  
  // 详细的内存使用情况
  String get formattedMemoryUsage => FormatUtils.formatMemoryUsage(memoryTotal, memoryAvailable);
  
  // 简化的内存使用情况
  String get formattedMemorySimple => FormatUtils.formatMemorySimple(memoryTotal, memoryAvailable);
  
  // 详细的磁盘使用情况
  String get formattedDiskUsage => FormatUtils.formatDiskUsage(diskTotal, diskAvailable, diskUsage);
  
  // 简化的磁盘使用情况
  String get formattedDiskSimple => FormatUtils.formatDiskSimple(diskTotal, diskAvailable, diskUsage);
}
