import 'package:flutter/material.dart';

/// 系统资源使用率进度条组件
class SystemProgressBar extends StatelessWidget {
  final String label;
  final double percentage;
  final String? detail;
  final Color? color;
  final bool showPercentage;
  final IconData? icon;

  const SystemProgressBar({
    super.key,
    required this.label,
    required this.percentage,
    this.detail,
    this.color,
    this.showPercentage = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = color ?? _getProgressColor(percentage);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (showPercentage)
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail!,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// 根据使用率百分比返回对应的颜色
  Color _getProgressColor(double percentage) {
    if (percentage >= 90) {
      return Colors.red;
    } else if (percentage >= 75) {
      return Colors.orange;
    } else if (percentage >= 50) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }
}

/// 紧凑版进度条，用于列表显示
class CompactProgressBar extends StatelessWidget {
  final String label;
  final double percentage;
  final Color? color;

  const CompactProgressBar({
    super.key,
    required this.label,
    required this.percentage,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = color ?? _getProgressColor(percentage);
    
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: progressColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// 根据使用率百分比返回对应的颜色
  Color _getProgressColor(double percentage) {
    if (percentage >= 90) {
      return Colors.red;
    } else if (percentage >= 75) {
      return Colors.orange;
    } else if (percentage >= 50) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }
}

/// 系统资源监控卡片
class SystemMetricsCard extends StatelessWidget {
  final double? cpuUsage;
  final double? memoryUsage;
  final double? diskUsage;
  final String? memoryDetail;
  final String? diskDetail;
  final String? loadAverage;
  final String? uptime;

  const SystemMetricsCard({
    super.key,
    this.cpuUsage,
    this.memoryUsage,
    this.diskUsage,
    this.memoryDetail,
    this.diskDetail,
    this.loadAverage,
    this.uptime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '系统资源使用情况',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (cpuUsage != null) ...[
              SystemProgressBar(
                label: 'CPU使用率',
                percentage: cpuUsage!,
                icon: Icons.memory,
              ),
              const SizedBox(height: 12),
            ],
            if (memoryUsage != null) ...[
              SystemProgressBar(
                label: '内存使用率',
                percentage: memoryUsage!,
                detail: memoryDetail,
                icon: Icons.storage,
              ),
              const SizedBox(height: 12),
            ],
            if (diskUsage != null) ...[
              SystemProgressBar(
                label: '磁盘使用率',
                percentage: diskUsage!,
                detail: diskDetail,
                icon: Icons.storage,
              ),
              const SizedBox(height: 12),
            ],
            if (loadAverage != null) ...[
              Row(
                children: [
                  const Icon(Icons.speed, size: 16),
                  const SizedBox(width: 4),
                  const Text('系统负载:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(loadAverage!),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (uptime != null) ...[
              Row(
                children: [
                  const Icon(Icons.timer, size: 16),
                  const SizedBox(width: 4),
                  const Text('运行时间:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(uptime!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}