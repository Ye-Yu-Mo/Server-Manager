import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/node_provider.dart';
import '../providers/theme_provider.dart';
import '../../data/models/node.dart';
import '../../data/models/metric.dart';
import '../../data/services/websocket_service.dart';
import 'node_detail_page.dart';

class NodeListPage extends StatefulWidget {
  const NodeListPage({super.key});

  @override
  State<NodeListPage> createState() => _NodeListPageState();
}

class _NodeListPageState extends State<NodeListPage> {
  @override
  void initState() {
    super.initState();
    // 初始化时加载节点数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNodes();
    });
  }

  Future<void> _loadNodes() async {
    final provider = Provider.of<NodeProvider>(context, listen: false);
    await provider.loadNodes();
  }

  Future<void> _refreshData() async {
    await _loadNodes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器节点'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: themeProvider.isDarkMode ? '切换到亮色模式' : '切换到暗黑模式',
              );
            },
          ),
          // WebSocket连接状态指示器
          Consumer<NodeProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: _buildConnectionIcon(provider.connectionState),
                onPressed: () => _showConnectionStatus(provider),
                tooltip: _getConnectionTooltip(provider.connectionState),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: Consumer<NodeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.nodes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.error!,
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

          if (provider.nodes.isEmpty) {
            return const Center(
              child: Text('暂无节点数据'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              itemCount: provider.nodes.length,
              itemBuilder: (context, index) {
                final node = provider.nodes[index];
                final metric = provider.getMetricForNode(node.nodeId);
                return _buildNodeCard(node, metric);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNodeCard(Node node, NodeMetric? metric) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildStatusIndicator(node.isOnline),
        title: Text(
          node.hostname,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: ${node.ipAddress}'),
            Text('状态: ${node.status}'),
            if (node.lastHeartbeat != null)
              Text('最后心跳: ${node.lastHeartbeatFormatted}'),
            if (metric != null) _buildMetricsInfo(metric),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NodeDetailPage(nodeId: node.nodeId),
            ),
          );
        },
        onLongPress: () {
          _showNodeActions(node);
        },
      ),
    );
  }

  Widget _buildStatusIndicator(bool isOnline) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMetricsInfo(NodeMetric metric) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('CPU: ${metric.cpuUsagePercent.toStringAsFixed(1)}%'),
        Text('内存: ${metric.memoryUsagePercent.toStringAsFixed(1)}%'),
        if (metric.diskUsage != null)
          Text('磁盘: ${metric.diskUsagePercent.toStringAsFixed(1)}%'),
      ],
    );
  }


  void _showNodeActions(Node node) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('刷新监控数据'),
            onTap: () {
              Navigator.pop(context);
              _refreshNodeMetrics(node.nodeId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除节点', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteNode(node);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNodeMetrics(String nodeId) async {
    final provider = Provider.of<NodeProvider>(context, listen: false);
    await provider.refreshNodeMetrics(nodeId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('监控数据已刷新')),
    );
  }

  Future<void> _deleteNode(Node node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除节点 ${node.hostname} 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<NodeProvider>(context, listen: false);
      final success = await provider.deleteNode(node.nodeId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('节点 ${node.hostname} 已删除')),
        );
      }
    }
  }

  /// 构建连接状态图标
  Widget _buildConnectionIcon(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return const Icon(Icons.cloud_done, color: Colors.green);
      case WebSocketConnectionState.connecting:
        return const Icon(Icons.cloud_sync, color: Colors.orange);
      case WebSocketConnectionState.error:
        return const Icon(Icons.cloud_off, color: Colors.red);
      case WebSocketConnectionState.disconnected:
      default:
        return const Icon(Icons.cloud_off, color: Colors.grey);
    }
  }

  /// 获取连接状态提示
  String _getConnectionTooltip(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return '实时连接正常';
      case WebSocketConnectionState.connecting:
        return '正在连接...';
      case WebSocketConnectionState.error:
        return '连接错误';
      case WebSocketConnectionState.disconnected:
      default:
        return '连接已断开';
    }
  }

  /// 显示连接状态详情
  void _showConnectionStatus(NodeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '连接状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildConnectionIcon(provider.connectionState),
                const SizedBox(width: 8),
                Text(_getConnectionTooltip(provider.connectionState)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.refresh),
                const SizedBox(width: 8),
                Text('自动刷新: ${provider.autoRefreshEnabled ? "已启用" : "已禁用"}'),
              ],
            ),
            if (provider.autoRefreshEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer),
                  const SizedBox(width: 8),
                  Text('刷新间隔: ${provider.refreshInterval}秒'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.reconnectWebSocket();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新连接'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.forceRefresh();
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('强制刷新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
