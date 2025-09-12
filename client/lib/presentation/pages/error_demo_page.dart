import 'package:flutter/material.dart';
import '../widgets/error_widget.dart';

/// 错误组件演示页面 - 仅用于开发测试
class ErrorDemoPage extends StatelessWidget {
  const ErrorDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错误组件演示'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基础错误组件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            EnhancedErrorWidget(
              error: '这是一个基础的错误信息示例。错误可能包含多行内容，组件会自动处理换行和布局。',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('重试功能被触发')),
                );
              },
              title: '加载失败',
              icon: Icons.warning_amber,
            ),
            const SizedBox(height: 24),
            
            const Text(
              '网络错误组件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            NetworkErrorWidget(
              error: '无法连接到服务器，请检查网络连接后重试。连接超时：10秒',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('网络重试功能被触发')),
                );
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'API错误组件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ApiErrorWidget(
              error: 'HTTP 500: Internal Server Error - 服务器内部错误',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API重试功能被触发')),
                );
              },
              details: '请求URL: https://api.example.com/nodes\n'
                      '响应代码: 500\n'
                      '响应时间: 2.3秒\n'
                      '用户代理: Flutter/3.9.2\n'
                      '时间戳: ${DateTime.now().toIso8601String()}',
            ),
            const SizedBox(height: 24),
            
            const Text(
              'WebSocket错误组件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            WebSocketErrorWidget(
              error: 'WebSocket连接断开：连接被服务器拒绝，错误代码1006',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('WebSocket重连功能被触发')),
                );
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              '长文本错误示例',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            EnhancedErrorWidget(
              error: 'DioException [connection timeout]: The request connection took longer than 10,000ms to complete. This might indicate a network connectivity issue, server overload, or firewall restrictions. Please check your internet connection and try again. Error occurred while attempting to fetch node data from the server endpoint at /api/v1/nodes. Additional context: User was attempting to refresh the node list when this error occurred.',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('长文本重试功能被触发')),
                );
              },
              title: '连接超时错误',
              details: '栈跟踪信息:\n'
                      '#0      DioHttpRequestExecutor.execute\n'
                      '#1      DioMixin.request\n'
                      '#2      ApiService.getNodes\n'
                      '#3      NodeProvider.loadNodes\n'
                      '#4      _NodeListPageState._loadNodes\n'
                      '\n'
                      '环境信息:\n'
                      '- Flutter版本: 3.9.2\n'
                      '- Dart版本: 3.0.0\n'
                      '- 平台: ${Theme.of(context).platform}\n'
                      '- 网络状态: 未知',
              icon: Icons.network_check,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}