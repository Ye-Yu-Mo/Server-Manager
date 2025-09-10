# Server Manager API 示例文档

## 📋 概述

本文档整合了Server Manager系统的所有API示例，包括RESTful API请求响应示例和WebSocket通信示例。

---

## 🔗 快速导航

- [RESTful API示例](#-restful-api示例)
- [WebSocket通信示例](#-websocket通信示例) 
- [Python代码示例](#-python代码示例)
- [错误处理示例](#-错误处理示例)

---

## 🌐 RESTful API示例

### 基础信息

#### Base URL
```
http://localhost:9999/api/v1
```

#### 认证头
```
Authorization: Bearer default-token
```

### 1. 健康检查

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/health" \
  -H "Authorization: Bearer default-token"
```

#### 响应示例
```json
{
  "success": true,
  "message": "✅ Core服务运行正常",
  "data": {
    "status": "healthy",
    "websocket": "running"
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 2. 获取节点列表

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/nodes" \
  -H "Authorization: Bearer default-token"
```

#### 查询参数
- `page` (可选): 页码，默认1
- `limit` (可选): 每页数量，默认20
- `status` (可选): 节点状态过滤 (online/offline)

#### 响应示例
```json
{
  "success": true,
  "message": "获取节点列表成功",
  "data": {
    "nodes": [
      {
        "id": 1,
        "node_id": "node-001",
        "hostname": "server-01",
        "ip_address": "192.168.1.100",
        "os_info": "Ubuntu 22.04",
        "status": "online",
        "last_heartbeat": "2025-01-21T09:58:00Z",
        "created_at": "2025-01-20T14:30:00Z",
        "updated_at": "2025-01-21T09:58:00Z"
      }
    ],
    "pagination": {
      "total": 15,
      "page": 1,
      "limit": 20,
      "pages": 1
    }
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 3. 获取单个节点信息

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/node-001" \
  -H "Authorization: Bearer default-token"
```

#### 响应示例
```json
{
  "success": true,
  "message": "获取节点信息成功",
  "data": {
    "node": {
      "id": 1,
      "node_id": "node-001",
      "hostname": "server-01",
      "ip_address": "192.168.1.100",
      "os_info": "Ubuntu 22.04",
      "status": "online",
      "last_heartbeat": "2025-01-21T09:58:00Z",
      "created_at": "2025-01-20T14:30:00Z",
      "updated_at": "2025-01-21T09:58:00Z"
    }
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 4. 删除节点

#### 请求示例
```bash
curl -X DELETE "http://localhost:9999/api/v1/nodes/node-001" \
  -H "Authorization: Bearer default-token"
```

#### 响应示例
```json
{
  "success": true,
  "message": "节点删除成功",
  "data": {
    "deleted": true,
    "node_id": "node-001"
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 5. 获取节点统计信息

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/stats" \
  -H "Authorization: Bearer default-token"
```

#### 响应示例
```json
{
  "success": true,
  "message": "获取节点统计成功",
  "data": {
    "total_nodes": 15,
    "online_nodes": 8,
    "offline_nodes": 7,
    "online_percentage": 53.3,
    "last_updated": "2025-01-21T10:00:00Z"
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 6. 清理过期节点

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/cleanup" \
  -H "Authorization: Bearer default-token"
```

#### 查询参数
- `timeout_minutes` (可选): 超时时间（分钟），默认30

#### 响应示例
```json
{
  "success": true,
  "message": "清理过期节点完成",
  "data": {
    "cleaned_nodes": 3,
    "remaining_nodes": 12,
    "timeout_minutes": 30
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

### 7. 获取节点最新监控数据

#### 请求示例
```bash
curl -X GET "http://localhost:9999/api/v1/nodes/node-001/metrics/latest" \
  -H "Authorization: Bearer default-token"
```

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

---

### 8. 获取节点监控历史数据

#### 请求示例
```bash
# 获取最近100条数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=100"

# 获取指定时间范围的数据
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"

# 分页查询
curl "http://localhost:9999/api/v1/nodes/node-001/metrics?limit=50&offset=100"
```

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

---

### 9. 获取监控数据统计摘要

#### 请求示例
```bash
curl "http://localhost:9999/api/v1/nodes/node-001/metrics/summary?start_time=2025-01-21T09:00:00Z&end_time=2025-01-21T10:00:00Z"
```

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

---

### 10. 获取所有节点最新监控数据

#### 请求示例
```bash
curl "http://localhost:9999/api/v1/metrics/latest"
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

---

### 11. 获取系统监控统计信息

#### 请求示例
```bash
curl "http://localhost:9999/api/v1/metrics/stats"
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

---

## 🔌 WebSocket通信示例

### 连接方式

#### WebSocket连接URL
```
ws://localhost:9999/api/v1/ws?token=default-token&node_id=node-001
```

**参数说明:**
- `token`: 认证令牌 (MVP版本使用固定值 `default-token`)
- `node_id`: 节点唯一标识符 (可选，不提供时自动生成UUID)

### 消息格式

所有WebSocket消息采用统一的JSON格式：

```json
{
  "type": "消息类型",
  "id": "消息唯一标识符",
  "timestamp": "ISO 8601时间戳",
  "data": { /* 具体数据内容 */ }
}
```

### 1. 节点注册 (Node → Core)

#### 请求示例
```json
{
  "type": "node_register",
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "timestamp": "2025-01-21T10:00:00Z",
  "data": {
    "node_id": "node-001",
    "hostname": "server-01",
    "ip_address": "192.168.1.100",
    "os_info": "Ubuntu 22.04 LTS"
  }
}
```

#### 响应示例
```json
{
  "type": "register_response",
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "timestamp": "2025-01-21T10:00:01Z",
  "data": {
    "success": true,
    "message": "节点注册成功",
    "node_id": "node-001"
  }
}
```

---

### 2. 心跳与监控数据 (Node → Core)

#### 请求示例
```json
{
  "type": "heartbeat",
  "id": "223e4567-e89b-12d3-a456-426614174001",
  "timestamp": "2025-01-21T10:00:30Z",
  "data": {
    "node_id": "node-001",
    "status": "online",
    "metrics": {
      "cpu_usage": 45.2,
      "memory_usage": 68.5,
      "disk_usage": 34.1,
      "load_average": 1.23
    }
  }
}
```

#### 响应示例
```json
{
  "type": "heartbeat_ack",
  "id": "223e4567-e89b-12d3-a456-426614174001",
  "timestamp": "2025-01-21T10:00:30Z",
  "data": {
    "received": true,
    "node_id": "node-001"
  }
}
```

---

### 3. 命令执行 (Core → Node)

#### 命令下发示例
```json
{
  "type": "execute_command",
  "id": "323e4567-e89b-12d3-a456-426614174002",
  "timestamp": "2025-01-21T10:01:00Z",
  "data": {
    "command_id": "cmd-001",
    "command_text": "ls -la /home",
    "timeout": 30
  }
}
```

#### 命令开始响应 (Node → Core)
```json
{
  "type": "command_started",
  "id": "323e4567-e89b-12d3-a456-426614174002",
  "timestamp": "2025-01-21T10:01:01Z",
  "data": {
    "command_id": "cmd-001"
  }
}
```

#### 命令结果 (Node → Core)
```json
{
  "type": "command_result",
  "id": "423e4567-e89b-12d3-a456-426614174003",
  "timestamp": "2025-01-21T10:01:02Z",
  "data": {
    "command_id": "cmd-001",
    "exit_code": 0,
    "stdout": "total 24\ndrwxr-xr-x 3 user user 4096 Jan 21 10:00 .\ndrwxr-xr-x 5 root root 4096 Jan 20 09:00 ..\ndrwxr-xr-x 2 user user 4096 Jan 21 09:30 documents",
    "stderr": "",
    "execution_time_ms": 125
  }
}
```

#### 命令接收确认 (Core → Node)
```json
{
  "type": "command_received",
  "id": "423e4567-e89b-12d3-a456-426614174003",
  "timestamp": "2025-01-21T10:01:02Z",
  "data": {
    "received": true,
    "node_id": "node-001"
  }
}
```

---

### 4. 连接欢迎消息 (Core → Node)

#### 连接成功欢迎消息
```json
{
  "type": "welcome",
  "id": "823e4567-e89b-12d3-a456-426614174007",
  "timestamp": "2025-01-21T10:00:00Z",
  "data": {
    "message": "欢迎连接到Server Manager Core",
    "node_id": "node-001"
  }
}
```

---

### 5. 错误消息示例

#### 认证错误
```json
{
  "type": "error",
  "id": "523e4567-e89b-12d3-a456-426614174004",
  "timestamp": "2025-01-21T10:00:05Z",
  "data": {
    "error_code": "INVALID_TOKEN",
    "message": "认证令牌无效",
    "details": "Token已过期或格式错误"
  }
}
```

#### 解析错误
```json
{
  "type": "error",
  "id": "623e4567-e89b-12d3-a456-426614174005",
  "timestamp": "2025-01-21T10:00:06Z",
  "data": {
    "error_code": "PARSE_ERROR",
    "message": "消息解析失败",
    "details": "JSON解析错误: 期望值在位置10"
  }
}
```

#### 未知消息类型错误
```json
{
  "type": "error",
  "id": "723e4567-e89b-12d3-a456-426614174006",
  "timestamp": "2025-01-21T10:00:07Z",
  "data": {
    "error_code": "UNKNOWN_MESSAGE_TYPE",
    "message": "未知的消息类型: invalid_type",
    "details": "支持的消息类型: node_register, heartbeat, command_result"
  }
}
```

---

## 🐍 Python代码示例

### 安装依赖
```bash
pip install requests
```

### Python API客户端示例
```python
import requests
import json

BASE_URL = "http://localhost:9999/api/v1"
HEADERS = {
    "Authorization": "Bearer default-token",
    "Content-Type": "application/json"
}

def get_health():
    """健康检查"""
    response = requests.get(f"{BASE_URL}/health", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"健康检查失败: {response.status_code}")
        return None

def get_nodes(page=1, limit=20, status=None):
    """获取节点列表"""
    params = {"page": page, "limit": limit}
    if status:
        params["status"] = status
        
    response = requests.get(f"{BASE_URL}/nodes", headers=HEADERS, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取节点列表失败: {response.status_code}")
        return None

def get_node_detail(node_id):
    """获取节点详情"""
    response = requests.get(f"{BASE_URL}/nodes/{node_id}", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取节点详情失败: {response.status_code}")
        return None

def get_latest_metrics(node_id):
    """获取节点最新监控数据"""
    response = requests.get(f"{BASE_URL}/nodes/{node_id}/metrics/latest", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取监控数据失败: {response.status_code}")
        return None

def get_history_metrics(node_id, start_time=None, end_time=None, limit=100):
    """获取节点历史监控数据"""
    params = {"limit": limit}
    if start_time:
        params["start_time"] = start_time
    if end_time:
        params["end_time"] = end_time
        
    response = requests.get(f"{BASE_URL}/nodes/{node_id}/metrics", headers=HEADERS, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"获取历史监控数据失败: {response.status_code}")
        return None

def delete_node(node_id):
    """删除节点"""
    response = requests.delete(f"{BASE_URL}/nodes/{node_id}", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"删除节点失败: {response.status_code}")
        return None

# 使用示例
if __name__ == "__main__":
    # 健康检查
    health = get_health()
    print("健康状态:", json.dumps(health, indent=2, ensure_ascii=False))
    
    # 获取节点列表
    nodes = get_nodes()
    print("节点列表:", json.dumps(nodes, indent=2, ensure_ascii=False))
    
    # 获取节点详情
    if nodes and nodes["data"]["nodes"]:
        node_id = nodes["data"]["nodes"][0]["node_id"]
        node_detail = get_node_detail(node_id)
        print("节点详情:", json.dumps(node_detail, indent=2, ensure_ascii=False))
        
        # 获取监控数据
        metrics = get_latest_metrics(node_id)
        print("最新监控数据:", json.dumps(metrics, indent=2, ensure_ascii=False))
        
        # 获取历史数据
        history = get_history_metrics(node_id, limit=5)
        print("历史监控数据:", json.dumps(history, indent=2, ensure_ascii=False))
```

---

## ⚠️ 错误处理示例

### 1. 无效token错误
```json
{
  "success": false,
  "message": "无效的认证token",
  "error_code": "INVALID_TOKEN",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 2. 节点不存在错误
```json
{
  "success": false,
  "message": "节点不存在",
  "error_code": "NODE_NOT_FOUND",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 3. 参数验证错误
```json
{
  "success": false,
  "message": "参数验证失败",
  "error_code": "VALIDATION_ERROR",
  "details": {
    "page": ["必须为数字"],
    "limit": ["必须在1到100之间"]
  },
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 4. 暂无监控数据错误
```json
{
  "success": false,
  "message": "暂无监控数据",
  "error_code": "NO_METRICS_DATA",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 5. 时间格式错误
```json
{
  "success": false,
  "message": "时间格式错误",
  "error_code": "INVALID_TIME_FORMAT",
  "details": "请使用ISO 8601格式的时间戳",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 6. 时间范围错误
```json
{
  "success": false,
  "message": "时间范围错误",
  "error_code": "INVALID_TIME_RANGE",
  "details": "开始时间必须早于结束时间",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 7. 数据库错误
```json
{
  "success": false,
  "message": "数据库操作失败",
  "error_code": "DATABASE_ERROR",
  "details": "数据库连接异常",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 8. 命令执行超时错误
```json
{
  "success": false,
  "message": "命令执行超时",
  "error_code": "COMMAND_TIMEOUT",
  "details": "命令在30秒内未完成执行",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

---

## 📝 使用建议

1. **错误处理**: 始终检查响应中的 `success` 字段
2. **超时设置**: 建议设置合理的请求超时时间
3. **重试机制**: 对于临时性错误实现重试逻辑
4. **日志记录**: 记录重要的API调用和错误信息
5. **版本兼容**: 注意API版本变化，及时更新客户端
6. **数据缓存**: 适当缓存监控数据减少请求频率
7. **批量操作**: 批量获取数据时使用分页参数

---

## 🚀 完整使用流程示例

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

---

## 🔗 相关文档

- [Server Manager 使用指南](./Server_Manager_使用指南.md)
- [API设计文档](./API设计.md)
- [数据库设计](./数据库设计.md)
- [开发计划](./开发计划.md)

---

*最后更新: 2025-09-10*
