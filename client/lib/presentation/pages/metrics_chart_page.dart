import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/node_provider.dart';
import '../widgets/error_widget.dart';
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
  List<NodeMetric> _metrics = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTimeRange = 0; // 0: 1小时, 1: 6小时, 2: 24小时
  final GlobalKey _chartKey = GlobalKey();
  bool _showComparision = false;
  Set<String> _selectedMetrics = {'cpu'}; // 默认显示CPU

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

      // 保存原始数据用于交互和导出
      _metrics = metrics;
      
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

    // 性能优化：只处理必要的数据点，避免过多点导致卡顿
    const maxPoints = 200;
    final step = metrics.length > maxPoints ? (metrics.length / maxPoints).ceil() : 1;

    // 创建数据点 - 使用时间戳作为X轴更真实
    for (int i = 0; i < metrics.length; i += step) {
      final metric = metrics[i];
      final x = metric.metricTime.millisecondsSinceEpoch.toDouble();
      
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

  void _toggleMetricVisibility(String metric) {
    setState(() {
      if (_selectedMetrics.contains(metric)) {
        _selectedMetrics.remove(metric);
      } else {
        _selectedMetrics.add(metric);
      }
    });
  }

  Future<void> _exportChart() async {
    try {
      final RenderRepaintBoundary boundary = _chartKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/metrics_chart_${widget.nodeId}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: '${widget.nodeName} - 监控图表');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  String _formatTimestamp(double timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getTimeRangeLabel() {
    switch (_selectedTimeRange) {
      case 0: return '1小时';
      case 1: return '6小时'; 
      case 2: return '24小时';
      default: return '1小时';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.nodeName} - 监控图表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare),
            onPressed: () {
              setState(() {
                _showComparision = !_showComparision;
              });
            },
            tooltip: _showComparision ? '单独显示' : '对比显示',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportChart();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('导出图表'),
                  ],
                ),
              ),
            ],
          ),
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
        child: SingleChildScrollView(
          child: EnhancedErrorWidget(
            error: _error!,
            onRetry: _loadMetricsData,
            title: '加载图表数据失败',
            icon: Icons.bar_chart,
          ),
        ),
      );
    }

    return RepaintBoundary(
      key: _chartKey,
      child: Column(
        children: [
          _buildTimeRangeSelector(),
          _buildMetricSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _showComparision ? _buildComparisonChart() : _buildSeparateCharts(),
            ),
          ),
        ],
      ),
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

  Widget _buildMetricSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('指标选择:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                _buildMetricChip('CPU', 'cpu', Colors.blue),
                _buildMetricChip('内存', 'memory', Colors.green),
                _buildMetricChip('磁盘', 'disk', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String metric, Color color) {
    final isSelected = _selectedMetrics.contains(metric);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _toggleMetricVisibility(metric),
      backgroundColor: color.withValues(alpha: 0.1),
      selectedColor: color.withValues(alpha: 0.3),
    );
  }

  Widget _buildSeparateCharts() {
    return Column(
      children: [
        if (_selectedMetrics.contains('cpu') && _cpuSpots.isNotEmpty) _buildCpuChart(),
        if (_selectedMetrics.contains('memory') && _memorySpots.isNotEmpty) _buildMemoryChart(),
        if (_selectedMetrics.contains('disk') && _diskSpots.isNotEmpty) _buildDiskChart(),
        if (_selectedMetrics.isEmpty)
          const Center(child: Text('请选择要显示的监控指标')),
        if (_selectedMetrics.isNotEmpty && _cpuSpots.isEmpty && _memorySpots.isEmpty && _diskSpots.isEmpty)
          const Center(child: Text('暂无监控数据')),
      ],
    );
  }

  Widget _buildComparisonChart() {
    final List<LineChartBarData> lineBars = [];
    
    if (_selectedMetrics.contains('cpu') && _cpuSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: _cpuSpots,
        isCurved: true,
        color: Colors.blue,
        barWidth: 2,
        isStrokeCapRound: true,
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    if (_selectedMetrics.contains('memory') && _memorySpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: _memorySpots,
        isCurved: true,
        color: Colors.green,
        barWidth: 2,
        isStrokeCapRound: true,
        belowBarData: BarAreaData(show: false),
      ));
    }
    
    if (_selectedMetrics.contains('disk') && _diskSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: _diskSpots,
        isCurved: true,
        color: Colors.orange,
        barWidth: 2,
        isStrokeCapRound: true,
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (lineBars.isEmpty) {
      return const Center(child: Text('请选择要显示的监控指标'));
    }

    // 计算时间范围
    double? minX, maxX;
    for (final lineBar in lineBars) {
      for (final spot in lineBar.spots) {
        minX = minX == null ? spot.x : (spot.x < minX ? spot.x : minX);
        maxX = maxX == null ? spot.x : (spot.x > maxX ? spot.x : maxX);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '综合监控图表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '时间范围: ${_getTimeRangeLabel()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1);
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: (maxX! - minX!) / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatTimestamp(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: lineBars,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          String metricName = '';
                          if (spot.barIndex == 0 && _selectedMetrics.contains('cpu')) {
                            metricName = 'CPU';
                          } else if ((_selectedMetrics.contains('cpu') && spot.barIndex == 1) || 
                                  (!_selectedMetrics.contains('cpu') && spot.barIndex == 0 && _selectedMetrics.contains('memory'))) {
                            metricName = '内存';
                          } else if (spot.barIndex == 2 || 
                                  (!_selectedMetrics.contains('cpu') && !_selectedMetrics.contains('memory') && spot.barIndex == 0)) {
                            metricName = '磁盘';
                          }
                          
                          return LineTooltipItem(
                            '$metricName: ${spot.y.toStringAsFixed(1)}%\n${_formatTimestamp(spot.x)}',
                            TextStyle(color: spot.bar.color),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedMetrics.contains('cpu'))
          _buildLegendItem('CPU', Colors.blue),
        if (_selectedMetrics.contains('memory'))
          _buildLegendItem('内存', Colors.green),
        if (_selectedMetrics.contains('disk'))
          _buildLegendItem('磁盘', Colors.orange),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 2,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
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
    if (spots.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              const Text('暂无数据'),
              const SizedBox(height: 50),
            ],
          ),
        ),
      );
    }

    final minX = spots.first.x;
    final maxX = spots.last.x;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '时间范围: ${_getTimeRangeLabel()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1);
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: (maxX - minX) / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatTimestamp(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}%\n${_formatTimestamp(spot.x)}',
                            TextStyle(color: color, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
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
