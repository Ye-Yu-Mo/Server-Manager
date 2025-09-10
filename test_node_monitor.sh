#!/bin/bash

# Node代理监控功能测试脚本

echo "🚀 测试Node代理监控功能..."

# 进入node目录
cd server/node

echo "📦 编译Node代理..."
cargo build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"

echo "🔧 创建测试配置..."
cat > config/test.toml << 'EOF'
[core]
url = "ws://localhost:9999/api/v1/ws"
token = "test-token"
node_id = "test-node-001"

[monitoring]
heartbeat_interval = 10
metrics_interval = 5
detailed_metrics = true

[system]
hostname = "test-server"
report_system_info = true

[logging]
level = "info"
file_enabled = false
file_path = "logs/test.log"
console_enabled = true

[advanced]
reconnect_interval = 3
max_retries = 5
command_timeout = 30
metrics_retention_days = 3
EOF

echo "🧪 运行测试（10秒后自动退出）..."
timeout 10s cargo run -- --config config/test.toml

echo "✅ 测试完成"
echo "📊 查看日志输出确认监控数据采集是否正常"
