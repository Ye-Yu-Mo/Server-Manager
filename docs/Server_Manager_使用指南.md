# Server Manager 使用指南

## 📋 概述

本文档整合了Server Manager系统的所有使用指南，包括Node代理配置、API使用、监控数据查询和Flutter客户端开发。

---

## 🔗 快速导航

- [Node代理使用指南](#-node代理使用指南)
- [API使用指南](#-api使用指南) 
- [监控数据API指南](#-监控数据api指南)
- [Flutter客户端开发指南](#-flutter客户端开发指南)
- [故障排除](#-故障排除)

---

## 🔧 Node代理使用指南

### 安装与运行

#### 从源码编译运行
```bash
# 进入node目录
cd server/node

# 编译
cargo build --release

# 运行（使用默认配置）
cargo run

# 运行（指定配置文件）
cargo run -- --config config/custom.toml
```

#### 二进制文件运行
```bash
# 直接运行二进制文件
./target/release/node

# 指定配置文件
./target/release/node --config /path/to/config.toml
```

### 配置说明

#### 配置文件位置
Node代理会按以下顺序查找配置文件：
1. 命令行指定的配置文件路径
2. `./config/default.toml`
3. 内置默认配置

#### 配置示例
```toml
# config/default.toml

[core]
# Core服务WebSocket地址
url = "ws://localhost:9999/api/v1/ws"
# 认证令牌
token = "default-token"
# 节点ID（可选，不设置时自动生成）
node_id = ""

[monitoring]
# 心跳间隔（秒）
heartbeat_interval = 30
# 监控数据采集间隔（秒）
metrics_interval = 10
# 是否启用详细监控（采集更多指标）
detailed_metrics = false

[system]
# 主机名（可选，不设置时自动获取）
hostname = ""
# 是否上报系统信息
report_system_info = true

[logging]
# 日志级别：trace, debug, info, warn, error
level = "info"
# 是否输出到文件
file_enabled = false
# 日志文件路径
file_path = "logs/node.log"
# 是否输出到控制台
console_enabled = true

[advanced]
# 连接重试间隔（秒）
reconnect_interval = 5
# 最大重试次数
max_retries = 10
# 命令执行超时时间（秒）
command_timeout = 30
# 监控数据保留天数
metrics_retention_days = 7
```

#### 环境变量配置
所有配置都可以通过环境变量覆盖，环境变量格式为：
```
SM_NODE__SECTION__FIELD=value
```

例如：
```bash
# 设置Core服务地址
export SM_NODE__CORE__URL="ws://192.168.1.100:9999/api/v1/ws"

# 设置认证令牌
export SM_NODE__CORE__TOKEN="my-secret-token"

# 设置监控间隔
export SM_NODE__MONITORING__METRICS_INTERVAL=5
```

### 监控指标

Node代理采集以下系统监控指标：

- **CPU监控**: CPU使用率、CPU信息（核心数、型号名称）
- **内存监控**: 内存使用率、内存总量、可用内存
- **磁盘监控**: 磁盘使用率、磁盘总量、可用空间、所有磁盘信息
- **系统信息**: 主机名、操作系统、内核版本、运行时间
- **网络监控**: 网络接收、网络发送数据量
- **系统负载**: 系统1分钟负载平均值（Linux）

### 功能特性

- **实时监控**: 按配置间隔自动采集系统指标
- **自动重连**: 网络中断时自动重连Core服务
- **灵活配置**: 多配置文件支持，环境变量覆盖
- **详细日志**: 多级别日志输出，控制台和文件日志

### 部署建议

#### 生产环境部署
```bash
# 创建专用用户
sudo useradd -r -s /bin/false server-manager

# 创建配置目录
sudo mkdir -p /etc/server-manager/node
sudo cp config/default.toml /etc/server-manager/node/

# 创建日志目录
sudo mkdir -p /var/log/server-manager
sudo chown server-manager:server-manager /var/log/server-manager

# 使用systemd管理服务
sudo cp systemd/server-manager-node.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable server-manager-node
sudo systemctl start server-manager-node
```

#### Docker部署
```dockerfile
FROM rust:alpine AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM alpine:latest
COPY --from=builder /app/target/release/node /usr/local/bin/
COPY config/default.toml /etc/server-manager/node/config.toml
CMD ["node", "--config", "/etc/server-manager/node/config.toml"]
```

---

## 🌐 API使用指南

### 基础信息

#### Base URL
```
http://localhost:9999/api/v1
```

#### 认证头
```
Authorization: Bearer default-token
```

*注意：MVP版本使用固定token `default-token`*

#### 通用响应格式
```json
{
  "success": true,
  "message": "操作成功描述",
  "data": { /* 具体数据 */ },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

#### 错误响应格式
```json
{
  "success": false,
  "message": "错误描述",
  "error_code": "ERROR_CODE",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 主要API接口

#### 1. 健康检查
```bash
curl -X GET "http://localhost:9999/api/v1/health" \
  -H "Authorization: Bearer default-token"
```

#### 2. 获取节点列表
```bash
curl -X GET "http://localhost:9999/api/v1/nodes" \
  -H "Authorization: Bearer default-token"
```

#### 3. 获取单个节点信息
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/node-001" \
  -H "Authorization: Bearer default-token"
```

#### 4. 删除节点
```bash
curl -X DELETE "http://localhost:9999/api/v1/nodes/node-001" \
  -H "Authorization: Bearer default-token"
```

#### 5. 获取节点统计信息
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/stats" \
  -H "Authorization: Bearer default-token"
```

#### 6. 清理过期节点
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/cleanup" \
  -H "Authorization: Bearer default-token"
```

### Python请求示例

```python
import requests
import json

BASE_URL = "http://localhost:9999/api/v1"
HEADERS = {
    "Authorization": "Bearer default-token",
    "Content-Type": "application/json"
}

def get_nodes():
    """获取节点列表"""
    response = requests.get(f"{BASE_URL}/nodes", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"请求失败: {response.status_code}")
        return None

def get_node_stats():
    """获取节点统计"""
    response = requests.get(f"{BASE_URL}/nodes/stats", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"请求失败: {response.status_code}")
        return None

def delete_node(node_id):
    """删除节点"""
    response = requests.delete(f"{BASE_URL}/nodes/{node_id}", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"请求失败: {response.status_code}")
        return None
```

---

## 📊 监控数据API指南

### 监控数据API列表

#### 1. 获取节点最新监控数据
```bash
curl http://localhost:9999/api/v1/nodes/node-001/metrics/latest
```

#### 2. 获取节点监控历史数据
```bash
# 获取最近100条数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=100"

# 获取指定时间范围的数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"

# 分页查询
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=50&offset=100"
```

#### 3. 获取监控数据统计摘要
```bash
curl "http://localhost:9999/api/v1/nodes/node-001/metrics/summary?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"
```

#### 4. 获取所有节点最新监控数据
```bash
curl http://localhost:9999/api/v1/metrics/latest
```

#### 5. 获取系统监控统计信息
```bash
curl http://localhost:9999/api/v1/metrics/stats
```

### 使用jq处理JSON响应

```bash
# 提取特定字段
curl -s http://localhost:9999/api/v1/metrics/latest | jq '.data[].cpu_usage'

# 格式化输出
curl -s http://localhost:9999/api/v1/nodes/node-001/metrics/latest | jq '.data | {node_id, cpu_usage, memory_usage, disk_usage}'

# 过滤数据
curl -s http://localhost:9999/api/v1/metrics/latest | jq '.data[] | select(.cpu_usage > 50)'
```

### 错误码说明

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| `NODE_NOT_FOUND` | 节点不存在 | 检查节点ID是否正确 |
| `NO_METRICS_DATA` | 暂无监控数据 | 等待节点发送监控数据 |
| `INVALID_TIME_FORMAT` | 时间格式错误 | 使用ISO 8601格式 |
| `INVALID_TIME_RANGE` | 时间范围错误 | 开始时间必须早于结束时间 |

---

## 📱 Flutter客户端开发指南

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

### 功能模块规划

#### 1. 首页仪表盘 (`/`)
- 节点总览卡片（在线/离线统计）
- 系统资源使用率概览
- 最近命令执行记录
- 快速操作面板

#### 2. 节点管理 (`/nodes`)
- 节点列表展示（网格/列表视图）
- 节点搜索和筛选
- 节点详情查看
- 节点删除操作

#### 3. 节点详情 (`/nodes/{nodeId}`)
- 节点基本信息
- 实时监控图表
- 监控历史数据查询
- 快速命令执行

#### 4. 监控中心 (`/monitoring`)
- 多节点监控对比
- 自定义时间范围查询
- 监控数据导出
- 告警阈值设置

#### 5. 命令中心 (`/commands`)
- 命令执行界面
- 命令历史记录
- 批量命令执行
- 常用命令收藏

#### 6. 设置页面 (`/settings`)
- 服务器连接配置
- 主题设置
- 语言设置
- 关于应用

### API集成设计

#### 网络层架构
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
}
```

#### WebSocket集成
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
}
```

### 开发流程

#### 阶段1: 项目基础搭建 (1天)
- [x] Flutter项目初始化
- [ ] 依赖包配置
- [ ] 项目结构搭建
- [ ] 主题和路由配置

#### 阶段2: 核心功能开发 (3天)
- [ ] API客户端封装
- [ ] 状态管理配置
- [ ] 数据模型定义
- [ ] Repository层实现

#### 阶段3: 页面开发 (4天)
- [ ] 首页仪表盘
- [ ] 节点列表页面
- [ ] 节点详情页面
- [ ] 监控图表组件

#### 阶段4: 高级功能 (2天)
- [ ] WebSocket实时数据
- [ ] 命令执行功能
- [ ] 设置页面
- [ ] 错误处理优化

#### 阶段5: 测试和优化 (1天)
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能优化
- [ ] 跨平台适配

---

## 🔍 故障排除

### 常见问题

#### 1. 连接失败
```bash
# 检查Core服务是否运行
curl http://localhost:9999/api/v1/health

# 检查网络连通性
ping <core-server-ip>
```

#### 2. 认证失败
```bash
# 检查token配置是否正确
echo $SM_NODE__CORE__TOKEN

# 查看Core服务日志确认token验证
```

#### 3. 监控数据异常
```bash
# 检查系统权限
# Node代理需要足够的权限来读取系统信息

# 检查sysinfo库支持
# 某些系统可能需要额外依赖
```

### 日志分析

查看日志文件获取详细错误信息：
```bash
# 查看最新日志
tail -f logs/node.log

# 根据日志级别过滤
grep "ERROR" logs/node.log
grep "WARN" logs/node.log
```

### 性能调优

如果监控数据采集影响系统性能：
```toml
[monitoring]
# 增加采集间隔
metrics_interval = 30
# 关闭详细监控
detailed_metrics = false
```

### 错误码处理

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| `INVALID_TOKEN` | 认证令牌无效 | 检查token配置，重新连接 |
| `NODE_NOT_FOUND` | 节点不存在 | 重新发送注册消息 |
| `COMMAND_TIMEOUT` | 命令执行超时 | 检查网络连接或命令复杂度 |
| `PARSE_ERROR` | 消息解析失败 | 检查JSON格式是否正确 |
| `UNKNOWN_MESSAGE_TYPE` | 未知消息类型 | 检查消息类型拼写 |
| `DATABASE_ERROR` | 数据库操作失败 |
