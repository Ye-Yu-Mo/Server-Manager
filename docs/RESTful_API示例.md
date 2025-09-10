# RESTful API 请求示例文档

## 📋 概述

本文档提供分布式服务器管理系统中RESTful API的详细使用示例，包括各种接口的请求和响应格式。

---

## 🔌 基础信息

### Base URL
```
http://localhost:9999/api/v1
```

### 认证头
```
Authorization: Bearer default-token
```

*注意：MVP版本使用固定token `default-token`*

### 通用响应格式
```json
{
  "success": true,
  "message": "操作成功描述",
  "data": { /* 具体数据 */ },
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

## 🚀 API 接口示例

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

## 🐍 Python 请求示例

### 安装依赖
```bash
pip install requests
```

### Python 示例代码
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

# 使用示例
if __name__ == "__main__":
    # 获取节点列表
    nodes = get_nodes()
    print("节点列表:", json.dumps(nodes, indent=2, ensure_ascii=False))
    
    # 获取统计信息
    stats = get_node_stats()
    print("节点统计:", json.dumps(stats, indent=2, ensure_ascii=False))
    
    # 删除节点（示例）
    # result = delete_node("node-001")
    # print("删除结果:", json.dumps(result, indent=2, ensure_ascii=False))
```

---

## 🔧 错误处理示例

### 无效token错误
```json
{
  "success": false,
  "message": "无效的认证token",
  "error_code": "INVALID_TOKEN",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 节点不存在错误
```json
{
  "success": false,
  "message": "节点不存在",
  "error_code": "NODE_NOT_FOUND",
  "timestamp": "2025-01-21T10:00:00Z"
}
```

### 参数验证错误
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

---

## 📝 使用建议

1. **错误处理**: 始终检查响应中的 `success` 字段
2. **超时设置**: 建议设置合理的请求超时时间
3. **重试机制**: 对于临时性错误实现重试逻辑
4. **日志记录**: 记录重要的API调用和错误信息
5. **版本兼容**: 注意API版本变化，及时更新客户端

---

## 🔗 相关文档

- [WebSocket通信示例](./WebSocket通信示例.md)
- [API设计文档](./API设计.md)
- [数据库设计](./数据库设计.md)
- [开发计划](./开发计划.md)

---

*最后更新: 2025-09-10*
