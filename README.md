# 分布式服务器管理系统 (Server Manager)

一个 **轻量级、开箱即用** 的分布式服务器管理系统。采用 **Rust** 实现核心服务与节点代理，使用 **Flutter** 构建跨平台客户端，支持 **移动端、桌面端与 Web 页面**。系统专注于 **分布式节点管理、实时监控与远程运维**，无需繁琐配置即可快速投入使用。

---

## 使用流程

1. 启动core, 获取secret_key
2. 配置node中的 secret_key
3. 配置client中的 secret_key

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

## 技术选型

| 层级        | 技术选型                                   |
| --------- | -------------------------------------- |
| 节点代理      | Rust (tokio, async, sysinfo)           |
| 核心服务 Core | Rust (axum/actix-web) + SQLite + Redis |
| 通信协议      | WebSocket + HTTP/REST                  |
| 数据存储      | SQLite（本地轻量数据库） + Redis（缓存/队列）         |
| 客户端展示     | Flutter（跨平台：移动、桌面、Web）                 |

---