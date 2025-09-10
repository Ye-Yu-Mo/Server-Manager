mod database;
mod models;
mod services;
use anyhow::Result;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
    routing::{get, delete},
    Router,
};
use database::Database;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{info, warn, error};
use tracing_subscriber;

use crate::services::{
    metrics::{
        get_all_latest_metrics, get_latest_metrics, get_metrics_summary, 
        get_node_metrics, get_system_metrics_stats
    },
    nodes::{cleanup_stale_nodes, delete_node, get_node, get_node_stats, get_nodes}, 
    websocket::{health_check, websocket_handler}
};

#[tokio::main]
async fn main() -> Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    info!("🚀 Server Manager Core 启动中...");
    
    // 初始化数据库连接
    let database = match database::initialize_database().await {
        Ok(db) => {
            info!("✅ 数据库初始化成功");
            db
        }
        Err(e) => {
            error!("❌ 数据库初始化失败: {}", e);
            return Err(e);
        }
    };
    
    // 显示数据库统计信息
    match database.get_stats().await {
        Ok(stats) => {
            info!("📊 数据库统计:");
            info!("  - 总节点数: {}", stats.total_nodes);
            info!("  - 在线节点数: {}", stats.online_nodes);
            info!("  - 总命令数: {}", stats.total_commands);
        }
        Err(e) => {
            warn!("⚠️ 无法获取数据库统计信息: {}", e);
        }
    }
    
    // 创建共享状态
    let shared_state = Arc::new(crate::services::nodes::AppState::new(database));
    
    // 创建路由
    let app = Router::new()
        // WebSocket路由
        .route("/api/v1/ws", get(websocket_handler))
        // 健康检查
        .route("/api/v1/health", get(health_check))
        // 节点管理API
        .route("/api/v1/nodes", get(get_nodes))
        .route("/api/v1/nodes/{node_id}", get(get_node))
        .route("/api/v1/nodes/{node_id}", delete(delete_node))
        .route("/api/v1/nodes/stats", get(get_node_stats))
        .route("/api/v1/nodes/cleanup", get(cleanup_stale_nodes))
        // 监控数据API
        .route("/api/v1/nodes/{node_id}/metrics/latest", get(get_latest_metrics))
        .route("/api/v1/nodes/{node_id}/metrics", get(get_node_metrics))
        .route("/api/v1/nodes/{node_id}/metrics/summary", get(get_metrics_summary))
        .route("/api/v1/metrics/latest", get(get_all_latest_metrics))
        .route("/api/v1/metrics/stats", get(get_system_metrics_stats))
        .with_state(shared_state);
    
    // 启动WebSocket服务器
    let listener = tokio::net::TcpListener::bind("0.0.0.0:9999").await?;
    info!("🌐 WebSocket服务器启动成功，监听端口: 9999");
    
    // 启动服务器
    axum::serve(listener, app).await?;
    
    info!("👋 Core服务正在关闭...");
    
    Ok(())
}
