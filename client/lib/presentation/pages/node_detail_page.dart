import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/node_provider.dart';
import '../../data/models/node.dart';
import '../../data/models/metric.dart';
import 'metrics_chart_page.dart';

class NodeDetailPage extends StatefulWidget {
  final String nodeId;

  const NodeDetailPage({super.key, required this.nodeId});

  @override
  State<NodeDetailPage> createState() => _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  late Node? _node;
  NodeMetric? _latestMetric;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNodeData();
  }

  Future<void> _loadNodeData() async {
    final provider = Provider.of<NodeProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 从Provider中获取节点信息
      _node = provider.findNodeById(widget.nodeId);
      
      // 如果节点不存在，尝试从API获取
      if (_node == null) {
        final node = await provider.apiService.getNode(widget.nodeId);
        if (node != null) {
          _node = node;
        } else {
          throw Exception('节点不存在');
        }
      }

      // 获取最新监控数据
      _latestMetric = await provider.apiService.getLatestMetrics(widget.nodeId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载节点详情失败: $e';
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadNodeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_node?.hostname ?? '节点详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
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
              onPressed: _refreshData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_node == null) {
      return const Center(
        child: Text('节点不存在'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNodeInfoCard(),
          const SizedBox(height: 16),
          _buildMetricsCard(),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildNodeInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '节点信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('节点ID', _node!.nodeId),
            _buildInfoRow('主机名', _node!.hostname),
            _buildInfoRow('IP地址', _node!.ipAddress),
            if (_node!.osInfo != null) _buildInfoRow('操作系统', _node!.osInfo!),
            _buildInfoRow('状态', _node!.status, isStatus: true),
            _buildInfoRow('注册时间', _node!.registeredAt.toLocal().toString()),
            if (_node!.lastHeartbeat != null)
              _buildInfoRow('最后心跳', _node!.lastHeartbeat!.toLocal().toString()),
            _buildInfoRow('更新时间', _node!.updatedAt.toLocal().toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isStatus
                ? Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _node!.isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(value),
                    ],
                  )
                : Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '监控数据',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_latestMetric != null) ...[
              _buildMetricRow('CPU使用率', '${_latestMetric!.cpuUsagePercent.toStringAsFixed(1)}%'),
              _buildMetricRow('内存使用率', '${_latestMetric!.memoryUsagePercent.toStringAsFixed(1)}%'),
              if (_latestMetric!.diskUsage != null)
                _buildMetricRow('磁盘使用率', '${_latestMetric!.diskUsagePercent.toStringAsFixed(1)}%'),
              if (_latestMetric!.loadAverage != null)
                _buildMetricRow('系统负载', _latestMetric!.loadAverage!.toStringAsFixed(2)),
              _buildMetricRow('采集时间', _latestMetric!.metricTime.toLocal().toString()),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('刷新监控数据'),
              ),
            ] else ...[
              const Text('暂无监控数据'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('获取监控数据'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showCommandDialog();
                  },
                  icon: const Icon(Icons.terminal, size: 18),
                  label: const Text('执行命令'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MetricsChartPage(
                          nodeId: _node!.nodeId,
                          nodeName: _node!.hostname,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('监控图表'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showMetricsHistory();
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('历史数据'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _restartNode();
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('重启节点'),
                ),
                if (_node != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      _deleteNode();
                    },
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text('删除节点', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCommandDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('执行命令'),
        content: const Text('命令执行功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showMetricsHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('历史监控数据'),
        content: const Text('历史数据查看功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _restartNode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重启节点'),
        content: const Text('节点重启功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _deleteNode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除节点 ${_node!.hostname} 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = Provider.of<NodeProvider>(context, listen: false);
              final success = await provider.deleteNode(_node!.nodeId);
              if (success) {
                Navigator.pop(context); // 返回上一页
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
