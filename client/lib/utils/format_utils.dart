class FormatUtils {
  /// 将字节数转换为可读格式（B, KB, MB, GB, TB）
  static String formatBytes(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    
    const List<String> units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    // 保留1位小数，除非是整数
    if (size == size.roundToDouble()) {
      return '${size.toInt()} ${units[unitIndex]}';
    } else {
      return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
    }
  }
  
  /// 格式化内存使用情况：已用/总计 (百分比%)
  static String formatMemoryUsage(int? memoryTotal, int? memoryAvailable) {
    if (memoryTotal == null || memoryAvailable == null) {
      return '未知';
    }
    
    final used = memoryTotal - memoryAvailable;
    final percentage = (used / memoryTotal * 100).round();
    
    return '${formatBytes(used)} / ${formatBytes(memoryTotal)} ($percentage%)';
  }
  
  /// 格式化磁盘使用情况：已用/总计 (百分比%)
  static String formatDiskUsage(int? diskTotal, int? diskAvailable, double? diskUsagePercent) {
    if (diskTotal != null && diskAvailable != null) {
      final used = diskTotal - diskAvailable;
      final percentage = (used / diskTotal * 100).round();
      return '${formatBytes(used)} / ${formatBytes(diskTotal)} ($percentage%)';
    } else if (diskUsagePercent != null) {
      return '使用率 ${diskUsagePercent.toStringAsFixed(1)}%';
    } else {
      return '未知';
    }
  }
  
  /// 格式化CPU使用率
  static String formatCpuUsage(double? cpuUsage) {
    if (cpuUsage == null) return '未知';
    return '${cpuUsage.toStringAsFixed(1)}%';
  }
  
  /// 格式化负载均值
  static String formatLoadAverage(double? loadAverage) {
    if (loadAverage == null) return '未知';
    return loadAverage.toStringAsFixed(2);
  }
  
  /// 格式化运行时间（秒转为天时分秒）
  static String formatUptime(int? uptimeSeconds) {
    if (uptimeSeconds == null) return '未知';
    
    final days = uptimeSeconds ~/ (24 * 3600);
    final hours = (uptimeSeconds % (24 * 3600)) ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    
    if (days > 0) {
      return '${days}天 ${hours}小时 ${minutes}分钟';
    } else if (hours > 0) {
      return '${hours}小时 ${minutes}分钟';
    } else {
      return '${minutes}分钟';
    }
  }
  
  /// 简化的内存使用显示（仅显示百分比和总量）
  static String formatMemorySimple(int? memoryTotal, int? memoryAvailable) {
    if (memoryTotal == null || memoryAvailable == null) {
      return '内存: 未知';
    }
    
    final used = memoryTotal - memoryAvailable;
    final percentage = (used / memoryTotal * 100).round();
    
    return '内存: $percentage% (${formatBytes(memoryTotal)})';
  }
  
  /// 简化的磁盘使用显示
  static String formatDiskSimple(int? diskTotal, int? diskAvailable, double? diskUsagePercent) {
    if (diskTotal != null && diskAvailable != null) {
      final used = diskTotal - diskAvailable;
      final percentage = (used / diskTotal * 100).round();
      return '磁盘: $percentage% (${formatBytes(diskTotal)})';
    } else if (diskUsagePercent != null) {
      return '磁盘: ${diskUsagePercent.toStringAsFixed(1)}%';
    } else {
      return '磁盘: 未知';
    }
  }
}