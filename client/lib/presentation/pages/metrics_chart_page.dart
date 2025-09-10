import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/node_provider.dart';
import '../../data/models/metric.dart';

class MetricsChartPage extends StatefulWidget {
  final String nodeId;
  final String nodeName;

  const MetricsChartPage({
    super.key,
    required this.nodeId,
    required this.nodeName,
  });

  @override
  State<MetricsChartPage> createState() => _MetricsChartPageState();
}

class _MetricsChartPageState extends State<MetricsChartPage> {
  final List<FlSpot> _cpuSpots = [];
  final List<FlSpot> _memorySpots = [];
  final List<FlSpot> _diskSpots = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTimeRange = 0; // 0: 1小时, 1: 6小时, 2: 24小时

  @override
  void initState() {
    super.initState();
    _loadMetricsData();
  }

  Future<void> _loadMetricsData() async {
    final provider = Provider.of<NodeProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 计算时间范围
      final endTime = DateTime.now();
      final startTime = _getStartTimeForRange(_selectedTimeRange);

      // 获取历史监控数据
      final metrics = await provider.apiService.getNodeMetrics(
        widget.nodeId,
        startTime: startTime,
        endTime: endTime,
        limit: 100,
      );

      // 处理数据点
      _processMetricsData(metrics);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载监控数据失败: $e';
      });
    }
  }

  DateTime _getStartTimeForRange(int range) {
    switch (range) {
      case 0: // 1小时
        return DateTime.now().subtract(const Duration(hours: 1));
      case 1: // 6小时
        return DateTime.now().subtract(const Duration(hours: 6));
      case 2: // 24小时
        return DateTime.now().subtract(const Duration(hours: 24));
      default:
        return DateTime.now().subtract(const Duration(hours: 1));
    }
  }

  void _processMetricsData(List<NodeMetric> metrics) {
    _cpuSpots.clear();
    _memorySpots.clear();
    _diskSpots.clear();

    // 按时间排序
    metrics.sort((a, b) => a.metricTime.compareTo(b.metricTime));

    // 创建数据点
    for (int i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      final x = i.toDouble();
      
      if (metric.cpuUsage != null) {
        _cpuSpots.add(FlSpot(x, metric.cpuUsage!));
      }
      
      if (metric.memoryUsage != null) {
        _memorySpots.add(FlSpot(x, metric.memoryUsage!));
      }
      
      if (metric.diskUsage != null) {
        _diskSpots.add(FlSpot(x, metric.diskUsage!));
      }
    }
  }

  void _changeTimeRange(int range) {
    setState(() {
      _selectedTimeRange = range;
    });
    _loadMetricsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.nodeName} - 监控图表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetricsData,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMetricsData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTimeRangeSelector(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_cpuSpots.isNotEmpty) _buildCpuChart(),
                if (_memorySpots.isNotEmpty) _buildMemoryChart(),
                if (_diskSpots.isNotEmpty) _buildDiskChart(),
                if (_cpuSpots.isEmpty && _memorySpots.isEmpty && _diskSpots.isEmpty)
                  const Center(child: Text('暂无监控数据')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeRangeButton('1小时', 0),
          _buildTimeRangeButton('6小时', 1),
          _buildTimeRangeButton('24小时', 2),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String text, int range) {
    final isSelected = _selectedTimeRange == range;
    return ElevatedButton(
      onPressed: () => _changeTimeRange(range),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
      child: Text(text),
    );
  }

  Widget _buildCpuChart() {
    return _buildChart(
      title: 'CPU使用率 (%)',
      spots: _cpuSpots,
      color: Colors.blue,
    );
  }

  Widget _buildMemoryChart() {
    return _buildChart(
      title: '内存使用率 (%)',
      spots: _memorySpots,
      color: Colors.green,
    );
  }

  Widget _buildDiskChart() {
    return _buildChart(
      title: '磁盘使用率 (%)',
      spots: _diskSpots,
      color: Colors.orange,
    );
  }

  Widget _buildChart({
    required String title,
    required List<FlSpot> spots,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: spots.isNotEmpty ? spots.last.x : 1,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            _buildChartStats(spots, color),
          ],
        ),
      ),
    );
  }

  Widget _buildChartStats(List<FlSpot> spots, Color color) {
    if (spots.isEmpty) {
      return const SizedBox();
    }

    final values = spots.map((spot) => spot.y).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final avgValue = values.reduce((a, b) => a + b) / values.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('最大值', '${maxValue.toStringAsFixed(1)}%', color),
          _buildStatItem('最小值', '${minValue.toStringAsFixed(1)}%', color),
          _buildStatItem('平均值', '${avgValue.toStringAsFixed(1)}%', color),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
