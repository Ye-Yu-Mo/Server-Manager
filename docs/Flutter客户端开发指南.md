# Flutter客户端开发指南

## 📋 概述

本文档提供Server Manager Flutter客户端的完整开发指南，包括技术选型、架构设计、功能模块规划和开发流程。

---

## 🎯 项目目标

创建一个**跨平台**的Server Manager客户端，支持：
- **移动端**：iOS、Android
- **桌面端**：macOS、Windows、Linux  
- **Web端**：浏览器访问

### 核心功能
- 节点管理和状态查看
- 实时监控数据展示
- 远程命令执行
- 系统统计和报告

---

## 🏗 技术架构

### 技术栈选择

```yaml
# pubspec.yaml 主要依赖
dependencies:
  flutter: ^3.16.0
  
  # 状态管理
  riverpod: ^2.4.0
  flutter_riverpod: ^2.4.0
  
  # 网络请求
  dio: ^5.4.0
  retrofit: ^4.1.0
  
  # WebSocket
  web_socket_channel: ^2.4.0
  
  # 本地存储
  shared_preferences: ^2.2.0
  hive: ^2.2.3
  
  # UI组件
  flutter_screenutil: ^5.9.0
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  
  # 图表
  fl_chart: ^0.66.0
  
  # 工具
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1
  
dev_dependencies:
  # 代码生成
  json_serializable: ^6.7.1
  freezed: ^2.4.6
  build_runner: ^2.4.7
  
  # 代码生成 - 网络
  retrofit_generator: ^7.0.8
  
  # 测试
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2
```

### 架构模式

采用 **MVVM + Repository** 模式：

```
lib/
├── main.dart
├── app/                     # 应用配置
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/                    # 核心功能
│   ├── constants/
│   ├── errors/
│   ├── network/
│   └── utils/
├── data/                    # 数据层
│   ├── models/             # 数据模型
│   ├── repositories/       # 数据仓库
│   └── services/           # API服务
├── presentation/            # 展示层
│   ├── pages/              # 页面
│   ├── widgets/            # 共用组件
│   └── providers/          # 状态管理
└── domain/                  # 业务逻辑层
    ├── entities/           # 业务实体
    └── usecases/           # 业务用例
```

---

## 📱 功能模块规划

### 1. 首页仪表盘
**路径**: `/`

**功能特性**:
- 节点总览卡片（在线/离线统计）
- 系统资源使用率概览
- 最近命令执行记录
- 快速操作面板

**UI组件**:
```dart
// 主要Widget
HomePage
├── DashboardHeader        // 顶部统计卡片
├── SystemOverviewChart    // 系统概览图表
├── RecentCommandsList     // 最近命令列表
└── QuickActionPanel       // 快速操作面板
```

### 2. 节点管理
**路径**: `/nodes`

**功能特性**:
- 节点列表展示（网格/列表视图）
- 节点搜索和筛选
- 节点详情查看
- 节点删除操作

**页面结构**:
```dart
NodesPage
├── NodesAppBar           // 搜索、筛选、视图切换
├── NodesGridView         // 网格视图
├── NodesListView         // 列表视图
└── NodeCard              // 单个节点卡片
```

### 3. 节点详情
**路径**: `/nodes/{nodeId}`

**功能特性**:
- 节点基本信息
- 实时监控图表
- 监控历史数据查询
- 快速命令执行

**组件结构**:
```dart
NodeDetailPage
├── NodeInfoCard          // 节点基本信息
├── MetricsChartSection   // 监控图表区域
│   ├── CPUChart
│   ├── MemoryChart
│   └── DiskChart
├── HistoryDataTable      // 历史数据表格
└── QuickCommandPanel     // 快速命令面板
```

### 4. 监控中心
**路径**: `/monitoring`

**功能特性**:
- 多节点监控对比
- 自定义时间范围查询
- 监控数据导出
- 告警阈值设置（后续版本）

### 5. 命令中心
**路径**: `/commands`

**功能特性**:
- 命令执行界面
- 命令历史记录
- 批量命令执行（后续版本）
- 常用命令收藏

### 6. 设置页面
**路径**: `/settings`

**功能特性**:
- 服务器连接配置
- 主题设置
- 语言设置
- 关于应用

---

## 🔌 API集成设计

### 网络层架构

```dart
// core/network/api_client.dart
@RestApi(baseUrl: "http://localhost:9999/api/v1")
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;
  
  // 节点管理
  @GET("/nodes")
  Future<NodesResponse> getNodes();
  
  @GET("/nodes/{nodeId}")
  Future<NodeDetailResponse> getNodeDetail(@Path() String nodeId);
  
  @DELETE("/nodes/{nodeId}")
  Future<void> deleteNode(@Path() String nodeId);
  
  // 监控数据
  @GET("/nodes/{nodeId}/metrics/latest")
  Future<MetricsResponse> getLatestMetrics(@Path() String nodeId);
  
  @GET("/nodes/{nodeId}/metrics")
  Future<HistoryMetricsResponse> getHistoryMetrics(
    @Path() String nodeId,
    @Query("start_time") String? startTime,
    @Query("end_time") String? endTime,
    @Query("limit") int? limit,
  );
  
  // 命令执行
  @POST("/nodes/{nodeId}/commands")
  Future<CommandResponse> executeCommand(
    @Path() String nodeId,
    @Body() ExecuteCommandRequest request,
  );
  
  @GET("/commands/{commandId}")
  Future<CommandResultResponse> getCommandResult(@Path() String commandId);
}
```

### WebSocket集成

```dart
// core/network/websocket_service.dart
class WebSocketService {
  WebSocketChannel? _channel;
  Stream<WebSocketMessage>? _messageStream;
  
  Future<void> connect({
    required String url,
    required String token,
    String? nodeId,
  }) async {
    final uri = Uri.parse('$url?token=$token${nodeId != null ? '&node_id=$nodeId' : ''}');
    _channel = WebSocketChannel.connect(uri);
    
    _messageStream = _channel!.stream
        .map((data) => WebSocketMessage.fromJson(json.decode(data)));
  }
  
  Stream<WebSocketMessage> get messageStream => _messageStream!;
  
  void sendMessage(WebSocketMessage message) {
    _channel?.sink.add(json.encode(message.toJson()));
  }
  
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
```

### 状态管理设计

```dart
// presentation/providers/nodes_provider.dart
final nodesProvider = StateNotifierProvider<NodesNotifier, NodesState>((ref) {
  final repository = ref.read(nodesRepositoryProvider);
  return NodesNotifier(repository);
});

class NodesNotifier extends StateNotifier<NodesState> {
  final NodesRepository _repository;
  
  NodesNotifier(this._repository) : super(const NodesState.loading());
  
  Future<void> loadNodes() async {
    state = const NodesState.loading();
    try {
      final nodes = await _repository.getNodes();
      state = NodesState.loaded(nodes);
    } catch (e) {
      state = NodesState.error(e.toString());
    }
  }
  
  Future<void> deleteNode(String nodeId) async {
    // 删除逻辑
  }
}

// 状态类定义
@freezed
class NodesState with _$NodesState {
  const factory NodesState.loading() = _Loading;
  const factory NodesState.loaded(List<Node> nodes) = _Loaded;
  const factory NodesState.error(String message) = _Error;
}
```

---

## 🎨 UI设计规范

### 设计系统

```dart
// app/theme.dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.light,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.dark,
    ),
  );
}
```

### 响应式设计

```dart
// core/utils/responsive.dart
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;
      
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 && 
      MediaQuery.of(context).size.width < 1024;
      
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}
```

### 通用组件设计

```dart
// presentation/widgets/common/
├── loading_widget.dart        // 加载指示器
├── error_widget.dart          // 错误展示组件
├── empty_state_widget.dart    // 空状态组件
├── refresh_indicator_widget.dart  // 刷新组件
├── status_badge.dart          // 状态徽章
└── metric_card.dart          // 监控指标卡片
```

---

## 📊 数据可视化

### 图表组件设计

```dart
// presentation/widgets/charts/
class CPUUsageChart extends StatelessWidget {
  final List<MetricData> data;
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: data.map((e) => FlSpot(
                e.timestamp.millisecondsSinceEpoch.toDouble(),
                e.cpuUsage,
              )).toList(),
              isCurved: true,
              color: Theme.of(context).primaryColor,
            ),
          ],
          // 图表配置...
        ),
      ),
    );
  }
}
```

---

## 🔧 开发流程

### 阶段1: 项目基础搭建 (1天)
- [x] Flutter项目初始化
- [ ] 依赖包配置
- [ ] 项目结构搭建
- [ ] 主题和路由配置

### 阶段2: 核心功能开发 (3天)
- [ ] API客户端封装
- [ ] 状态管理配置
- [ ] 数据模型定义
- [ ] Repository层实现

### 阶段3: 页面开发 (4天)
- [ ] 首页仪表盘
- [ ] 节点列表页面
- [ ] 节点详情页面
- [ ] 监控图表组件

### 阶段4: 高级功能 (2天)
- [ ] WebSocket实时数据
- [ ] 命令执行功能
- [ ] 设置页面
- [ ] 错误处理优化

### 阶段5: 测试和优化 (1天)
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能优化
- [ ] 跨平台适配

---

## 🧪 测试策略

### 单元测试
```dart
// test/presentation/providers/nodes_provider_test.dart
void main() {
  group('NodesNotifier', () {
    late MockNodesRepository mockRepository;
    late NodesNotifier notifier;
    
    setUp(() {
      mockRepository = MockNodesRepository();
      notifier = NodesNotifier(mockRepository);
    });
    
    test('should load nodes successfully', () async {
      // 测试逻辑
    });
  });
}
```

### 集成测试
- API接口集成测试
- 页面导航测试
- WebSocket连接测试

---

## 🚀 部署配置

### Web部署
```yaml
# flutter build web配置
name: server_manager_client
description: Server Manager Flutter Client

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/icons/
```

### 移动端打包
```bash
# Android
flutter build apk --release

# iOS  
flutter build ios --release
```

### 桌面端打包
```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

---

## 📋 开发检查清单

### 开发前准备
- [ ] 确认Flutter环境版本
- [ ] 配置IDE插件和工具
- [ ] 阅读API文档和接口规范
- [ ] 准备测试服务器环境

### 开发中检查
- [ ] 代码格式化 (flutter format)
- [ ] 静态分析 (flutter analyze)
- [ ] 单元测试覆盖率
- [ ] 性能监控

### 发布前检查
- [ ] 多平台兼容性测试
- [ ] 网络异常处理
- [ ] 内存泄漏检查
- [ ] 用户体验优化

---

## 🔗 相关文档

- [API设计文档](./API设计.md) - 后端API接口规范
- [README_API](./README_API.md) - API使用快速入门
- [数据库设计](./数据库设计.md) - 数据模型参考
- [Node代理使用指南](./Node代理使用指南.md) - Node代理配置

---

*最后更新: 2025-09-10*