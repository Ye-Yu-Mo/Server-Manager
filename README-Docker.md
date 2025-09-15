# Server Manager Docker 部署指南

## 概述

Server Manager 已成功打包为 Docker 镜像，监听端口为 20002。

## 镜像信息

- **镜像名称**: `server-manager:latest`
- **监听端口**: 20002
- **数据存储**: `/app/data` (可挂载到宿主机)

## 快速启动

### 方法一：使用提供的脚本
```bash
./docker-run.sh
```

### 方法二：手动运行
```bash
# 创建数据目录
mkdir -p ./data

# 运行容器
docker run -d \
    --name server-manager \
    -p 20002:20002 \
    -v $(pwd)/data:/app/data \
    --restart unless-stopped \
    server-manager:latest
```

## 常用命令

### 查看容器状态
```bash
docker ps | grep server-manager
```

### 查看服务日志
```bash
docker logs -f server-manager
```

### 停止服务
```bash
docker stop server-manager
```

### 删除容器
```bash
docker rm server-manager
```

### 重新构建镜像
```bash
docker build -t server-manager:latest .
```

## 访问地址

- **WebSocket 连接**: `ws://localhost:20002/api/v1/ws`
- **健康检查**: `http://localhost:20002/api/v1/health`
- **节点列表**: `http://localhost:20002/api/v1/nodes`

## 数据持久化

容器中的数据库文件存储在 `/app/data` 目录下，通过卷挂载到宿主机的 `./data` 目录，确保数据持久化。

## 环境要求

- Docker 18.06 或更高版本
- 可用端口 20002

## 故障排除

1. **端口占用**：确保端口 20002 未被其他程序占用
2. **权限问题**：确保脚本有执行权限 `chmod +x docker-run.sh`
3. **数据目录**：确保有权限创建和写入 `./data` 目录

## 容器配置

- **用户**: 非特权用户 `server`
- **工作目录**: `/app`
- **数据目录**: `/app/data`
- **重启策略**: `unless-stopped`