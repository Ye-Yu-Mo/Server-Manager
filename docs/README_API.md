# 分布式服务器管理系统 - API概述

## 📋 简介

Server Manager 提供了完整的 RESTful API 和 WebSocket 接口，用于节点管理、监控数据查询和远程命令执行。

---

## 🔗 快速链接

### 核心文档
- **[完整API设计文档](API设计.md)** - 详细的API规范和消息格式
- **[数据库设计](数据库设计.md)** - 数据库表结构和设计说明
- **[开发计划](开发计划.md)** - 项目开发进度和计划

### 开发指南
- **[Flutter客户端开发指南](Flutter客户端开发指南.md)** - 客户端开发完整指南
- **[Node代理使用指南](Node代理使用指南.md)** - Node代理的安装配置和使用

### 使用指南和示例
- **[RESTful API示例](RESTful_API示例.md)** - REST API请求响应示例，包含Python代码
- **[WebSocket通信示例](WebSocket通信示例.md)** - WebSocket消息格式和通信流程
- **[监控数据API使用指南](监控数据API使用指南.md)** - 监控数据查询接口详细说明

---

## 🌐 API概览

### Base URL
```
http://localhost:9999/api/v1
```

### 认证
```
Authorization: Bearer default-token
```

### 主要功能模块

#### 1. 节点管理
- `GET /nodes` - 获取节点列表
- `GET /nodes/{node_id}` - 获取单个节点信息  
- `DELETE /nodes/{node_id}` - 删除节点

#### 2. 监控数据查询
- `GET /nodes/{node_id}/metrics/latest` - 获取节点最新监控数据
- `GET /nodes/{node_id}/metrics` - 获取节点监控历史数据
- `GET /nodes/{node_id}/metrics/summary` - 获取监控数据统计摘要
- `GET /metrics/latest` - 获取所有节点最新监控数据

#### 3. 命令执行
- `POST /nodes/{node_id}/commands` - 执行命令
- `GET /commands/{command_id}` - 获取命令执行结果
- `GET /nodes/{node_id}/commands` - 获取节点命令历史
- `GET /commands` - 获取所有命令列表

#### 4. 系统信息
- `GET /system/stats` - 获取系统统计信息
- `GET /health` - 健康检查

---

## 🔌 WebSocket通信

### 连接地址
```
ws://localhost:9999/ws/node?token={TOKEN}&node_id={NODE_ID}
```

### 主要消息类型
- `node_register` - 节点注册
- `heartbeat` - 心跳包
- `execute_command` - 命令下发
- `command_result` - 命令结果

---

## 📝 使用示例

### 基础查询
```bash
# 检查API健康状态
curl http://localhost:9999/api/v1/health

# 获取所有节点
curl http://localhost:9999/api/v1/nodes

# 获取所有节点最新监控数据
curl http://localhost:9999/api/v1/metrics/latest
```

### 命令执行
```bash
# 执行命令
curl -X POST http://localhost:9999/api/v1/nodes/node-001/commands \
  -H "Content-Type: application/json" \
  -d '{"command_text": "ls -la", "timeout": 30}'

# 查询命令结果
curl http://localhost:9999/api/v1/commands/cmd-001
```

---

## 🚀 快速开始

1. **启动Core服务**: `cd server/core && cargo run`
2. **启动Node代理**: `cd server/node && cargo run`
3. **测试API**: `curl http://localhost:9999/api/v1/health`

---

## 📚 文档结构说明

### 技术设计文档
- **API设计.md**: MVP版本的完整API规范，包括WebSocket和REST接口
- **数据库设计.md**: SQLite数据库表结构设计，包含可视化图表代码
- **开发计划.md**: 项目开发阶段、里程碑和验收标准

### 使用指南文档  
- **Node代理使用指南.md**: Node代理的安装、配置、部署和故障排除
- **监控数据API使用指南.md**: 监控数据查询API的详细使用说明

### 示例文档
- **RESTful_API示例.md**: REST API的请求响应示例，包含curl和Python代码
- **WebSocket通信示例.md**: WebSocket消息格式和完整通信流程示例

---

*最后更新: 2025-09-10*