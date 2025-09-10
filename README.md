# 分布式服务器管理系统 (Server Manager)

一个 **轻量级、开箱即用** 的分布式服务器管理系统。采用 **Rust** 实现核心服务与节点代理，使用 **Flutter** 构建跨平台客户端，支持 **移动端、桌面端与 Web 页面**。系统专注于 **分布式节点管理、实时监控与远程运维**，无需繁琐配置即可快速投入使用。

---

## 📚 文档导航

### 核心文档
- **[API概述](docs/README_API.md)** - API接口快速索引
- **[服务器架构说明](docs/README_SERVER.md)** - 详细架构设计
- **[数据库设计](docs/数据库设计.md)** - 数据库表结构
- **[开发计划](docs/开发计划.md)** - 项目开发进度

### 开发指南
- **[Flutter客户端开发指南](docs/Flutter客户端开发指南.md)** - 客户端开发完整指南
- **[Node代理使用指南](docs/Node代理使用指南.md)** - Node代理安装配置

## 🚀 快速开始

### 1. 启动Core服务
```bash
cd server/core
cargo run
# 获取认证令牌
```

### 2. 配置Node代理
```bash
cd server/node
# 配置config/default.toml中的token
cargo run
```

### 3. 启动Flutter客户端
```bash
cd client
flutter run
```

## 系统架构

```mermaid
graph TD
    subgraph Client[控制与展示层 - Flutter]
        A1[移动端]
        A2[桌面端]
        A3[Web 页面]
    end

    subgraph Core[核心服务层 - Rust]
        B1[API Server Axum/Actix]
        B2[WebSocket Gateway]
        B3[任务调度 & 命令分发]
        B4[数据存储接口]
    end

    subgraph Storage[存储与缓存层]
        C1[(SQLite)]
        C2[(Redis 缓存/队列)]
    end

    subgraph Node[节点代理 - Rust]
        D1[注册与认证]
        D2[心跳与状态采集]
        D3[远程命令执行]
        D4[日志与监控数据推送]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1

    B1 --> C1
    B1 --> C2
    B2 <--> D1
    B2 <--> D2
    B2 <--> D3
    B2 <--> D4
```

---

## 系统流程

```mermaid
sequenceDiagram
    participant N as Node 代理
    participant C as Core 服务
    participant DB as SQLite/Redis
    participant F as Flutter 客户端

    N->>C: 注册请求 (Token/证书)
    C-->>N: 注册成功 & 分配 Node ID

    loop 定时心跳
        N->>C: 心跳 + 指标数据
        C->>DB: 存储监控数据
    end

    F->>C: 请求节点列表/监控数据
    C-->>F: 返回节点状态/监控指标

    F->>C: 下发命令 (cmd_id, 指令)
    C->>N: 推送命令
    N->>N: 执行命令
    N->>C: 返回执行结果 (stdout/stderr)
    C->>DB: 保存命令日志
    C-->>F: 推送执行结果
```

---

## 核心功能

### 节点管理

* 节点自动注册与身份验证（共享 Token 或证书）
* 心跳检测与实时状态监控
* 节点分组与标签管理
* 批量操作与指令下发

### 系统监控

* CPU、内存、磁盘、网络等实时监控
* 历史数据存储与趋势查询（SQLite 存储）
* 执行结果与采样数据的持久化

### 远程控制

* Shell 命令远程执行（异步返回结果）
* 系统服务控制（启动/停止/重启）
* 完整的日志与审计追踪

### 安全机制

* Token 或证书认证的节点注册流程
* 全链路 TLS 通信加密
* 命令与执行结果的审计记录
* 可扩展 RBAC（角色与权限控制）

### 界面与扩展

* Flutter 跨平台客户端（移动端、桌面端、Web 页面）
* 响应式 UI，支持暗黑模式
* 可扩展的 REST API / WebSocket 接口

---

## 🎯 核心特性

- **轻量级部署** - 单二进制文件，无复杂依赖
- **跨平台支持** - 支持多种操作系统和架构
- **实时监控** - CPU、内存、磁盘等系统指标实时采集
- **远程管理** - 安全的远程命令执行和结果查看
- **多端客户端** - Flutter跨平台客户端，支持移动端、桌面端、Web

---