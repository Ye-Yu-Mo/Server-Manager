#!/bin/bash

# 分布式服务器管理系统启动脚本

echo "🚀 启动分布式服务器管理系统..."

# 检查是否安装了Rust
if ! command -v cargo &> /dev/null; then
    echo "❌ 未找到Rust和Cargo，请先安装Rust: https://rustup.rs"
    exit 1
fi

# 切换到core目录
cd server/core

echo "📦 编译Core服务..."
cargo build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"
echo "🌐 启动Core服务..."

# 在后台启动Core服务
cargo run &

# 获取进程ID
CORE_PID=$!

echo "📊 Core服务已启动 (PID: $CORE_PID)"
echo "⏳ 等待服务初始化..."

# 等待服务启动
sleep 3

echo "🔍 测试服务状态..."

# 测试健康检查
curl -s http://localhost:9999/api/v1/health | python3 -m json.tool

echo ""
echo "📋 测试节点管理API..."

# 测试获取节点列表
echo "节点列表:"
curl -s http://localhost:9999/api/v1/nodes | python3 -m json.tool

echo ""
echo "📊 测试节点统计:"
curl -s http://localhost:9999/api/v1/nodes/stats | python3 -m json.tool

echo ""
echo "✅ 系统启动完成!"
echo "📌 Core服务运行在: http://localhost:9999"
echo "📌 WebSocket端点: ws://localhost:9999/api/v1/ws"
echo "📌 健康检查: http://localhost:9999/api/v1/health"
echo ""
echo "🛑 要停止服务，请运行: kill $CORE_PID"

# 等待用户中断
wait $CORE_PID
