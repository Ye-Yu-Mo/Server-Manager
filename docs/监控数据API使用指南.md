# 监控数据API使用指南

## 📋 概述

本文档提供Server Manager Core系统中监控数据查询API的详细使用说明，包括各种查询接口的参数、响应格式和示例。

---

## 🔌 基础信息

### Base URL
```
http://localhost:9999/api/v1
```

### 响应格式
所有API响应采用统一的JSON格式：

```json
{
  "success": true,
  "message": "操作成功描述",
  "data": { /* 具体数据内容 */ },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 错误响应格式
```json
{
  "success": false,
  "message": "错误描述",
  "error_code": "ERROR_CODE",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

## 📊 监控数据API列表

### 1. 获取节点最新监控数据

获取指定节点的最新监控数据记录。

#### 请求
```http
GET /api/v1/nodes/{node_id}/metrics/latest
```

#### 参数
- `node_id` (路径参数): 节点唯一标识符

#### 响应示例
```json
{
  "success": true,
  "message": "获取最新监控数据成功",
  "data": {
    "id": 123,
    "node_id": "node-001",
    "metric_time": "2025-01-21T10:00:00Z",
    "cpu_usage": 45.2,
    "memory_usage": 68.5,
    "disk_usage": 34.1,
    "load_average": 1.23,
    "created_at": "2025-01-21T10:00:00Z"
  },
  "timestamp": "2025-01-21T10:00:01Z"
}
```

#### 使用示例
```bash
curl http://localhost:9999/api/v1/nodes/node-001/metrics/latest
```

---

### 2. 获取节点监控历史数据

获取指定节点的监控历史数据，支持时间范围和分页。

#### 请求
```http
GET /api/v1/nodes/{node_id}/metrics
```

#### 查询参数
- `start_time` (可选): 开始时间，ISO 8601格式
- `end_time` (可选): 结束时间，ISO 8601格式  
- `limit` (可选): 每页数量，默认100
- `offset` (可选): 偏移量，默认0

#### 响应示例
```json
{
  "success": true,
  "message": "获取监控历史数据成功",
  "data": {
    "metrics": [
      {
        "id": 123,
        "node_id": "node-001",
        "metric_time": "2025-01-21T10:00:00Z",
        "cpu_usage": 45.2,
        "memory_usage": 68.5,
        "disk_usage": 34.1,
        "load_average": 1.23,
        "created_at": "2025-01-21T10:00:00Z"
      }
    ],
    "total": 150,
    "limit": 100,
    "offset": 0
  },
  "timestamp": "2025-01-21T10:00:01Z"
}
```

#### 使用示例
```bash
# 获取最近100条数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=100"

# 获取指定时间范围的数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"

# 分页查询
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=50&offset=100"
```

---

### 3. 获取监控数据统计摘要

获取指定节点在特定时间范围内的监控数据统计摘要。

#### 请求
```http
GET /api/v1/nodes/{node_id}/metrics/summary
```

#### 查询参数
- `start_time` (必需): 开始时间，ISO 8601格式
- `end_time` (必需): 结束时间，ISO 8601格式

#### 响应示例
```json
{
  "success": true,
  "message": "获取监控数据统计摘要成功",
  "data": {
    "node_id": "node-001",
    "avg_cpu_usage": 42.5,
    "max_cpu_usage": 89.2,
    "avg_memory_usage": 65.3,
    "max_memory_usage": 85.1,
    "avg_disk_usage": 34.7,
    "max_disk_usage": 36.2,
    "avg_load_average": 1.15,
    "max_load_average": 2.34,
    "sample_count": 120
  },
  "timestamp": "2025-01-21T10:00:01Z"
}
```

#### 使用示例
```bash
curl "http://localhost:9999/api/v1/nodes/node-001/metrics/summary?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"
```

---

### 4. 获取所有节点最新监控数据

获取所有节点的最新监控数据记录。

#### 请求
```http
GET /api/v1/metrics/latest
```

#### 响应示例
```json
{
  "success": true,
  "message": "获取所有节点最新监控数据成功",
  "data": [
    {
      "id": 123,
      "node_id": "node-001",
      "metric_time": "2025-01-21T10:00:00Z",
      "cpu_usage": 45.2,
      "memory_usage": 68.5,
      "disk_usage": 34.1,
      "load_average": 1.23,
      "created_at": "2025-01-21T10:00:00Z"
    },
    {
      "id": 124,
      "node_id": "node-002",
      "metric_time": "2025-01-21T10:00:00Z",
      "cpu_usage": 32.1,
      "memory_usage": 55.8,
      "disk_usage": 28.7,
      "load_average": 0.95,
      "created_at": "2025-01-21T10:00:00Z"
    }
  ],
  "timestamp": "2025-01-21T10:00:01Z"
}
```

#### 使用示例
```bash
curl http://localhost:9999/api/v1/metrics/latest
```

---

### 5. 获取系统监控统计信息

获取系统级别的监控数据统计信息。

#### 请求
```http
GET /api/v1/metrics/stats
```

#### 响应示例
```json
{
  "success": true,
  "message": "获取系统监控统计信息成功",
  "data": {
    "total_metrics": 1250,
    "last_24h_count": 120,
    "earliest_metric_time": "2025-01-20T08:00:00Z",
    "latest_metric_time": "2025-01-21T10:00:00Z",
    "metrics_per_hour": 5.0
  },
  "timestamp": "2025-01-21T10:00:01Z"
}
```

#### 使用示例
```bash
curl http://localhost:9999/api/v1/metrics/stats
```

---

## 🚀 完整使用示例

### 监控数据查询流程

```bash
# 1. 检查系统健康状态
curl http://localhost:9999/api/v1/health

# 2. 查看所有节点
curl http://localhost:9999/api/v1/nodes

# 3. 获取所有节点最新监控数据
curl http://localhost:9999/api/v1/metrics/latest

# 4. 获取特定节点最新监控数据
curl http://localhost:9999/api/v1/nodes/node-001/metrics/latest

# 5. 查询节点历史监控数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=10"

# 6. 获取监控数据统计摘要
curl "http://localhost:9999/api/v1/nodes/node-001/metrics/summary?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"

# 7. 查看系统监控统计
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

---

## 🔐 错误处理

### 常见错误码

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| `NODE_NOT_FOUND` | 节点不存在 | 检查节点ID是否正确 |
| `NO_METRICS_DATA` | 暂无监控数据 | 等待节点发送监控数据 |
| `INVALID_TIME_FORMAT` | 时间格式错误 | 使用ISO 8601格式 |
| `INVALID_TIME_RANGE` | 时间范围错误 | 开始时间必须早于结束时间 |

### 错误响应示例
```json
{
  "success": false,
  "message": "节点不存在",
  "error_code": "NODE_NOT_FOUND",
  "timestamp": "2025-01-21T10:00:01Z"
}
```

---

## 💡 最佳实践

1. **时间格式**: 始终使用ISO 8601格式的时间戳
2. **分页查询**: 大数据量时使用limit和offset参数
3. **错误处理**: 检查success字段判断操作是否成功
4. **数据缓存**: 客户端可以适当缓存监控数据减少请求
5. **实时更新**: 对于实时监控，建议每30秒查询一次最新数据

---

## 🧪 测试工具

### 使用测试脚本
```bash
chmod +x test_metrics_api.sh
./test_metrics_api.sh
```

### 手动测试
```bash
# 使用curl测试
curl -s "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=5" | jq .

# 使用httpie测试
http GET "http://localhost:9999/api/v1/metrics/latest"

# 使用Postman测试
# 导入Postman集合进行完整测试
```

---

*最后更新: 2025-09-10*
