# 使用 Rust 官方镜像作为构建环境
FROM rust:latest AS builder

# 设置工作目录
WORKDIR /app

# 复制整个项目
COPY . .

# 构建项目
RUN cd server && cargo build --release

# 使用轻量级的运行时镜像
FROM debian:bookworm-slim

# 安装必要的运行时依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 创建运行用户
RUN useradd -r -s /bin/false server

# 设置工作目录
WORKDIR /app

# 创建数据目录
RUN mkdir -p /app/data && chown server:server /app/data

# 从构建阶段复制二进制文件
COPY --from=builder /app/server/target/release/core /app/server-manager

# 设置权限
RUN chown server:server /app/server-manager && chmod +x /app/server-manager

# 切换到非特权用户
USER server

# 暴露端口
EXPOSE 20002

# 启动应用
CMD ["./server-manager"]