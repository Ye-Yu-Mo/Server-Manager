#!/bin/bash

# 服务器管理器 Docker 运行脚本
echo "🚀 启动 Server Manager Docker 容器..."

# 检查是否存在同名容器，如果存在则停止并删除
if docker ps -a --format 'table {{.Names}}' | grep -q '^server-manager$'; then
    echo "📦 发现已存在的容器，正在停止并删除..."
    docker stop server-manager
    docker rm server-manager
fi

# 创建数据目录（如果不存在）
mkdir -p ./data

# 运行容器
echo "🌐 在端口 20002 启动服务器..."
docker run -d \
    --name server-manager \
    -p 20002:20002 \
    -v $(pwd)/data:/app/data \
    --restart unless-stopped \
    server-manager:latest

# 检查容器状态
if docker ps | grep -q server-manager; then
    echo "✅ Server Manager 已成功启动！"
    echo "📍 服务地址: http://localhost:20002"
    echo "🔍 查看日志: docker logs -f server-manager"
    echo "⏹️  停止服务: docker stop server-manager"
else
    echo "❌ 启动失败，请检查日志: docker logs server-manager"
fi