# Node代理使用指南

## 📋 概述

Node代理是Server Manager系统的客户端组件，负责采集本地系统的监控数据并通过WebSocket发送到Core服务。本文档提供Node代理的安装、配置和使用说明。

---

## 🔧 安装与运行

### 从源码编译运行

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

### 二进制文件运行

```bash
# 直接运行二进制文件
./target/release/node

# 指定配置文件
./target/release/node --config /path/to/config.toml
```

---

## ⚙️ 配置说明

### 配置文件位置
Node代理会按以下顺序查找配置文件：
1. 命令行指定的配置文件路径
2. `./config/default.toml`
3. 内置默认配置

### 配置示例

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

### 环境变量配置

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

---

## 📊 监控指标

Node代理采集以下系统监控指标：

### CPU监控
- **CPU使用率**: 所有CPU核心的平均使用率
- **CPU信息**: 核心数、型号名称

### 内存监控
- **内存使用率**: 已用内存占总内存的百分比
- **内存总量**: 系统总物理内存
- **可用内存**: 当前可用内存大小

### 磁盘监控
- **磁盘使用率**: 根分区或主要分区的使用率
- **磁盘总量**: 总磁盘空间
- **可用空间**: 可用磁盘空间
- **所有磁盘信息**: 包括挂载点、文件系统等

### 系统信息
- **主机名**: 系统主机名
- **操作系统**: 操作系统名称和版本
- **内核版本**: 系统内核版本
- **运行时间**: 系统运行时长

### 网络监控（基础）
- **网络接收**: 网络接收数据量
- **网络发送**: 网络发送数据量

### 系统负载（Linux）
- **负载平均值**: 系统1分钟负载平均值

---

## 🚀 功能特性

### 实时监控
- 按配置间隔自动采集系统指标
- 支持自定义采集频率
- 实时数据上报

### 自动重连
- 网络中断时自动重连Core服务
- 可配置重试间隔和最大重试次数
- 连接状态监控

### 灵活配置
- 多配置文件支持
- 环境变量覆盖配置
- 动态配置更新

### 详细日志
- 多级别日志输出
- 控制台和文件日志
- 运行状态监控

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

---

## 🧪 测试验证

### 功能测试
```bash
# 运行测试脚本
chmod +x test_node_monitor.sh
./test_node_monitor.sh
```

### 手动测试
```bash
# 编译并运行测试
cd server/node
cargo test

# 运行单个测试
cargo test test_monitor_creation -- --nocapture
```

### 集成测试
1. 启动Core服务
2. 运行Node代理
3. 使用API查询监控数据
```bash
curl http://localhost:9999/api/v1/metrics/latest
```

---

## 📝 部署建议

### 生产环境部署
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

### Docker部署
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

### 监控建议
- 监控Node代理进程状态
- 监控系统资源使用情况
- 设置日志轮转策略
- 配置告警规则

---

## 🔄 更新与维护

### 版本升级
```bash
# 拉取最新代码
git pull

# 重新编译
cargo build --release

# 重启服务
sudo systemctl restart server-manager-node
```

### 配置更新
```bash
# 编辑配置文件
sudo vim /etc/server-manager/node/config.toml

# 重载配置（部分配置支持热重载）
sudo systemctl reload server-manager-node
```

### 日志管理
```bash
# 设置日志轮转
sudo vim /etc/logrotate.d/server-manager-node

# 清理旧日志
find /var/log/server-manager -name "*.log.*" -mtime +30 -delete
```

---

## 📞 技术支持

### 获取帮助
- 查看日志文件获取错误信息
- 检查系统文档和配置示例
- 查阅项目README文件

### 问题报告
遇到问题时请提供：
1. Node代理版本信息
2. 操作系统版本
3. 配置文件内容（脱敏后）
4. 相关日志输出
5. 错误现象描述

### 社区支持
- GitHub Issues: 提交问题和功能请求
- Documentation: 查阅详细文档
- Examples: 参考配置示例

---

*最后更新: 2025-09-10*
