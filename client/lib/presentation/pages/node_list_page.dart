import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/node_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/error_widget.dart';
import '../widgets/setup_prompt_widget.dart';
import '../widgets/progress_bar_widget.dart';
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
    // 只有在已配置状态下才尝试加载节点
    if (provider.appInitState == AppInitState.ready) {
      await provider.loadNodes();
    }
  }

  Future<void> _refreshData() async {
    await _loadNodes();
  }

  /// 构建错误显示组件
  Widget _buildErrorWidget(String error) {
    // 根据错误类型选择不同的错误组件
    if (error.contains('网络') || error.contains('连接') || error.contains('timeout')) {
      return NetworkErrorWidget(
        error: error,
        onRetry: _refreshData,
      );
    } else if (error.contains('API') || error.contains('HTTP') || error.contains('服务器')) {
      return ApiErrorWidget(
        error: error,
        onRetry: _refreshData,
        details: _getApiErrorDetails(error),
      );
    } else if (error.contains('WebSocket') || error.contains('实时')) {
      return WebSocketErrorWidget(
        error: error,
        onRetry: () async {
          if (!mounted) return;
          await _refreshData();
        },
      );
    } else {
      return EnhancedErrorWidget(
        error: error,
        onRetry: _refreshData,
        title: '加载失败',
        icon: Icons.warning_amber,
      );
    }
  }

  /// 获取API错误的详细信息
  String? _getApiErrorDetails(String error) {
    if (error.contains('DioException')) {
      return '这通常是由于网络连接问题或服务器不可用导致的。请检查：\n'
          '1. 网络连接是否正常\n'
          '2. 服务器地址是否正确\n'
          '3. 服务器是否正在运行\n'
          '4. 防火墙是否阻止连接';
    }
    return null;
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
          // 只在已配置状态下显示连接状态和刷新按钮
          Consumer<NodeProvider>(
            builder: (context, provider, child) {
              if (provider.appInitState != AppInitState.ready) {
                return const SizedBox.shrink();
              }
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // WebSocket连接状态指示器
                  IconButton(
                    icon: _buildConnectionIcon(provider.connectionState),
                    onPressed: () => _showConnectionStatus(provider),
                    tooltip: _getConnectionTooltip(provider.connectionState),
                  ),
                  // 刷新按钮
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshData,
                    tooltip: '刷新数据',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NodeProvider>(
        builder: (context, provider, child) {
          // 根据应用初始化状态显示不同内容
          switch (provider.appInitState) {
            case AppInitState.loading:
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载配置...'),
                  ],
                ),
              );
              
            case AppInitState.needsSetup:
              return const SingleChildScrollView(
                child: SetupPromptWidget(),
              );
              
            case AppInitState.error:
              return Center(
                child: SingleChildScrollView(
                  child: _buildErrorWidget(provider.error ?? '未知错误'),
                ),
              );
              
            case AppInitState.ready:
              // 已配置，显示节点列表或加载状态
              if (provider.isLoading && provider.nodes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在加载节点数据...'),
                    ],
                  ),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: SingleChildScrollView(
                    child: _buildErrorWidget(provider.error!),
                  ),
                );
              }

              if (provider.nodes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.devices_other,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '暂无节点数据',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请确保有Node代理连接到服务器',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('刷新'),
                      ),
                    ],
                  ),
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
          }
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
        const SizedBox(height: 8),
        CompactProgressBar(
          label: 'CPU',
          percentage: metric.cpuUsagePercent,
        ),
        const SizedBox(height: 4),
        CompactProgressBar(
          label: '内存',
          percentage: metric.memoryUsagePercent,
        ),
        const SizedBox(height: 4),
        CompactProgressBar(
          label: '磁盘',
          percentage: metric.diskUsagePercent,
        ),
        if (metric.loadAverage != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 40),
              const Icon(Icons.speed, size: 12),
              const SizedBox(width: 4),
              Text(
                '负载: ${metric.formattedLoadAverage}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
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
    if (!mounted) return;
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
      if (!mounted) return;
      final provider = Provider.of<NodeProvider>(context, listen: false);
      final success = await provider.deleteNode(node.nodeId);
      if (success && mounted) {
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
        return '连接失败';
      case WebSocketConnectionState.disconnected:
        return '未连接';
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
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _refreshData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('刷新数据'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
