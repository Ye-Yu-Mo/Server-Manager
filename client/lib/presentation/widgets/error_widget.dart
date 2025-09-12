import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 增强的错误显示组件
class EnhancedErrorWidget extends StatefulWidget {
  final String error;
  final VoidCallback? onRetry;
  final String? title;
  final String? details;
  final IconData? icon;

  const EnhancedErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.details,
    this.icon,
  });

  @override
  State<EnhancedErrorWidget> createState() => _EnhancedErrorWidgetState();
}

class _EnhancedErrorWidgetState extends State<EnhancedErrorWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _copyErrorToClipboard() {
    final errorText = _buildFullErrorText();
    Clipboard.setData(ClipboardData(text: errorText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('错误信息已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _buildFullErrorText() {
    final buffer = StringBuffer();
    if (widget.title != null) {
      buffer.writeln('错误标题: ${widget.title}');
    }
    buffer.writeln('错误信息: ${widget.error}');
    if (widget.details != null) {
      buffer.writeln('错误详情: ${widget.details}');
    }
    buffer.writeln('时间: ${DateTime.now().toString()}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
          ? colorScheme.errorContainer.withValues(alpha: 0.1)
          : colorScheme.errorContainer.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主要错误信息区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和图标
                Row(
                  children: [
                    Icon(
                      widget.icon ?? Icons.error_outline,
                      color: colorScheme.error,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title ?? '发生错误',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.details != null || widget.error.length > 100)
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.expand_more),
                        ),
                        onPressed: _toggleExpanded,
                        tooltip: _isExpanded ? '收起详情' : '展开详情',
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // 错误信息预览
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark 
                      ? Colors.grey[800] 
                      : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    widget.error.length > 100 && !_isExpanded
                        ? '${widget.error.substring(0, 100)}...'
                        : widget.error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                
                // 操作按钮区域
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.onRetry != null)
                      ElevatedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _copyErrorToClipboard,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 可展开的详情区域
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: ExpansionTile(
                title: const Text('错误详情'),
                initiallyExpanded: false,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark 
                        ? Colors.grey[900] 
                        : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '完整错误信息:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _buildFullErrorText(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                        if (widget.details != null) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            '技术详情:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            widget.details!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 网络错误专用组件
class NetworkErrorWidget extends EnhancedErrorWidget {
  const NetworkErrorWidget({
    super.key,
    required super.error,
    super.onRetry,
  }) : super(
          title: '网络连接错误',
          icon: Icons.wifi_off,
        );
}

/// API错误专用组件
class ApiErrorWidget extends EnhancedErrorWidget {
  const ApiErrorWidget({
    super.key,
    required super.error,
    super.onRetry,
    super.details,
  }) : super(
          title: 'API请求错误',
          icon: Icons.cloud_off,
        );
}

/// WebSocket连接错误专用组件
class WebSocketErrorWidget extends EnhancedErrorWidget {
  const WebSocketErrorWidget({
    super.key,
    required super.error,
    super.onRetry,
  }) : super(
          title: '实时连接错误',
          icon: Icons.sync_problem,
        );
}