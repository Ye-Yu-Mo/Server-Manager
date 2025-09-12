# Widgets 组件库

## 错误显示组件

### EnhancedErrorWidget

一个功能丰富的错误显示组件，提供更好的用户体验和调试支持。

#### 特性
- ✅ **可复制错误信息** - 一键复制完整错误信息到剪贴板
- ✅ **可展开详情** - 支持展开/收起错误详情
- ✅ **响应式设计** - 适配暗黑/亮色模式
- ✅ **时间戳显示** - 显示错误发生时间
- ✅ **重试功能** - 内置重试按钮
- ✅ **可选择文本** - 错误信息可选择复制

#### 使用方法

```dart
import '../widgets/error_widget.dart';

// 基础用法
EnhancedErrorWidget(
  error: '这是错误信息',
  onRetry: () => _retryFunction(),
)

// 完整用法
EnhancedErrorWidget(
  error: '这是错误信息',
  onRetry: _retryFunction,
  title: '自定义标题',
  details: '更多技术详情...',
  icon: Icons.warning_amber,
)
```

#### 专用错误组件

为常见错误类型提供了预配置的组件：

```dart
// 网络错误
NetworkErrorWidget(
  error: '网络连接失败',
  onRetry: _retryFunction,
)

// API错误
ApiErrorWidget(
  error: 'API请求失败',
  onRetry: _retryFunction,
  details: '详细的错误信息...',
)

// WebSocket错误
WebSocketErrorWidget(
  error: 'WebSocket连接失败',
  onRetry: _reconnectWebSocket,
)
```

#### 替换原有错误显示

原来的错误显示：
```dart
if (error != null) {
  return Center(
    child: Column(
      children: [
        Text(error!, style: TextStyle(color: Colors.red)),
        ElevatedButton(
          onPressed: _retry,
          child: Text('重试'),
        ),
      ],
    ),
  );
}
```

新的错误显示：
```dart
if (error != null) {
  return Center(
    child: SingleChildScrollView(
      child: EnhancedErrorWidget(
        error: error!,
        onRetry: _retry,
        title: '加载失败',
        icon: Icons.error_outline,
      ),
    ),
  );
}
```

#### 设计原则

1. **用户友好** - 清晰的错误信息展示，避免技术术语
2. **调试友好** - 提供完整的错误信息和复制功能
3. **一致性** - 统一的视觉风格和交互模式
4. **可访问性** - 支持无障碍访问和键盘导航

#### 自定义样式

组件会自动适配当前主题的颜色方案：
- 错误容器颜色基于 `ColorScheme.errorContainer`
- 边框和图标使用 `ColorScheme.error`
- 文本颜色使用 `ColorScheme.onSurface`
- 支持暗黑模式自动切换

## 配置引导组件

### SetupPromptWidget

一个友好的初始配置引导组件，用于首次启动时引导用户配置服务器连接。

#### 特性
- ✅ **美观的欢迎界面** - 现代化的卡片设计
- ✅ **表单验证** - 自动验证URL格式
- ✅ **配置示例** - 提供常见的配置示例
- ✅ **连接测试** - 配置时自动测试连接
- ✅ **响应式设计** - 适配不同屏幕尺寸
- ✅ **主题适配** - 支持亮色/暗黑模式

#### 使用方法

```dart
import '../widgets/setup_prompt_widget.dart';

// 在应用启动检查逻辑中使用
switch (appInitState) {
  case AppInitState.needsSetup:
    return const SingleChildScrollView(
      child: SetupPromptWidget(),
    );
}
```

#### 自动集成

SetupPromptWidget已经集成到NodeProvider的状态管理中：
- 当检测到未配置时自动显示
- 配置完成后自动切换到正常界面
- 配置过程中提供实时反馈

#### 配置验证

组件提供以下验证：
- URL格式验证（必须以http://或https://开头）
- 必填字段检查
- 连接测试和错误反馈