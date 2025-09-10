use std::collections::HashMap;
use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::sync::{Mutex, RwLock};
use tracing::{debug, error, info, warn};
use uuid::Uuid;
use sqlx::Row;

use crate::database::Database;
use crate::models::{Node, NodeCreate, NodeUpdate, NodeMetric, MetricCreate};

/// 活跃连接信息
#[derive(Debug, Clone, Serialize)]
pub struct ActiveConnection {
    pub node_id: String,
    pub connected_at: chrono::DateTime<Utc>,
    pub last_activity: chrono::DateTime<Utc>,
    pub status: String,
}

/// 连接管理器
#[derive(Debug, Clone)]
pub struct ConnectionManager {
    connections: Arc<RwLock<HashMap<String, ActiveConnection>>>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 添加新连接
    pub async fn add_connection(&self, node_id: String) {
        let mut connections = self.connections.write().await;
        connections.insert(
            node_id.clone(),
            ActiveConnection {
                node_id: node_id.clone(),
                connected_at: Utc::now(),
                last_activity: Utc::now(),
                status: "online".to_string(),
            },
        );
        info!("✅ 节点连接已添加: {}", node_id);
    }

    /// 更新连接活动时间
    pub async fn update_activity(&self, node_id: &str) -> bool {
        let mut connections = self.connections.write().await;
        if let Some(connection) = connections.get_mut(node_id) {
            connection.last_activity = Utc::now();
            connection.status = "online".to_string();
            debug!("🔄 更新节点活动时间: {}", node_id);
            true
        } else {
            false
        }
    }

    /// 更新连接状态
    pub async fn update_status(&self, node_id: &str, status: &str) -> bool {
        let mut connections = self.connections.write().await;
        if let Some(connection) = connections.get_mut(node_id) {
            connection.status = status.to_string();
            connection.last_activity = Utc::now();
            true
        } else {
            false
        }
    }

    /// 移除连接
    pub async fn remove_connection(&self, node_id: &str) -> bool {
        let mut connections = self.connections.write().await;
        if let Some(connection) = connections.get_mut(node_id) {
            connection.status = "offline".to_string();
            connections.remove(node_id).is_some()
        } else {
            false
        }
    }

    /// 获取所有活跃连接
    pub async fn get_connections(&self) -> Vec<ActiveConnection> {
        let connections = self.connections.read().await;
        connections.values().cloned().collect()
    }

    /// 获取特定节点的连接信息
    pub async fn get_connection(&self, node_id: &str) -> Option<ActiveConnection> {
        let connections = self.connections.read().await;
        connections.get(node_id).cloned()
    }

    /// 清理长时间无活动的连接
    pub async fn cleanup_inactive_connections(&self, timeout_minutes: i64) -> usize {
        let mut connections = self.connections.write().await;
        let timeout = chrono::Duration::minutes(timeout_minutes);
        let now = Utc::now();
        
        let inactive_nodes: Vec<String> = connections
            .iter()
            .filter(|(_, conn)| now - conn.last_activity > timeout)
            .map(|(node_id, _)| node_id.clone())
            .collect();
        
        for node_id in &inactive_nodes {
            if let Some(connection) = connections.get_mut(node_id) {
                connection.status = "offline".to_string();
            }
            connections.remove(node_id);
            warn!("🧹 清理长时间无活动的连接: {}", node_id);
        }
        
        inactive_nodes.len()
    }

    /// 获取在线节点数量
    pub async fn get_online_count(&self) -> usize {
        let connections = self.connections.read().await;
        connections.values()
            .filter(|conn| conn.status == "online")
            .count()
    }

    /// 获取离线节点数量
    pub async fn get_offline_count(&self) -> usize {
        let connections = self.connections.read().await;
        connections.values()
            .filter(|conn| conn.status == "offline")
            .count()
    }
}

/// 节点查询参数
#[derive(Debug, Deserialize)]
pub struct NodeQuery {
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 节点服务响应
#[derive(Debug, Serialize)]
pub struct NodeServiceResponse<T> {
    pub success: bool,
    pub message: String,
    pub data: Option<T>,
    pub timestamp: String,
}

impl<T> NodeServiceResponse<T> {
    pub fn success(data: T, message: &str) -> Self {
        Self {
            success: true,
            message: message.to_string(),
            data: Some(data),
            timestamp: Utc::now().to_rfc3339(),
        }
    }

    pub fn error(message: &str) -> Self {
        Self {
            success: false,
            message: message.to_string(),
            data: None,
            timestamp: Utc::now().to_rfc3339(),
        }
    }
}

/// 获取节点列表
pub async fn get_nodes(
    State(state): State<Arc<AppState>>,
    Query(query): Query<NodeQuery>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    let nodes = match Node::find_all(&db.pool).await {
        Ok(nodes) => nodes,
        Err(e) => {
            error!("获取节点列表失败: {}", e);
            return Json(NodeServiceResponse::error("获取节点列表失败"));
        }
    };

    // 根据状态过滤
    let filtered_nodes: Vec<Node> = if let Some(status) = &query.status {
        nodes.into_iter()
            .filter(|node| node.status == *status)
            .collect()
    } else {
        nodes
    };

    // 分页处理
    let limit = query.limit.unwrap_or(50);
    let offset = query.offset.unwrap_or(0);
    
    let total = filtered_nodes.len();
    let paginated_nodes: Vec<Node> = filtered_nodes
        .into_iter()
        .skip(offset as usize)
        .take(limit as usize)
        .collect();

    let response_data = json!({
        "nodes": paginated_nodes,
        "total": total,
        "limit": limit,
        "offset": offset
    });

    Json(NodeServiceResponse::success(response_data, "获取节点列表成功"))
}

/// 获取单个节点信息
pub async fn get_node(
    State(state): State<Arc<AppState>>,
    Path(node_id): Path<String>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    match Node::find_by_node_id(&db.pool, &node_id).await {
        Ok(Some(node)) => {
            Json(NodeServiceResponse::success(node, "获取节点信息成功"))
        }
        Ok(None) => {
            Json(NodeServiceResponse::error("节点不存在"))
        }
        Err(e) => {
            error!("获取节点信息失败: {}", e);
            Json(NodeServiceResponse::error("获取节点信息失败"))
        }
    }
}

/// 删除节点
pub async fn delete_node(
    State(state): State<Arc<AppState>>,
    Path(node_id): Path<String>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    match Node::delete(&db.pool, &node_id).await {
        Ok(true) => {
            info!("🗑️ 节点已删除: {}", node_id);
            Json(NodeServiceResponse::success((), "节点删除成功"))
        }
        Ok(false) => {
            Json(NodeServiceResponse::error("节点不存在"))
        }
        Err(e) => {
            error!("删除节点失败: {}", e);
            Json(NodeServiceResponse::error("删除节点失败"))
        }
    }
}

/// 获取节点统计信息
pub async fn get_node_stats(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    let connection_manager = &state.connection_manager;
    
    let total_nodes = match sqlx::query("SELECT COUNT(*) as count FROM nodes")
        .fetch_one(&db.pool)
        .await
    {
        Ok(row) => row.get::<i64, _>("count"),
        Err(e) => {
            error!("获取节点总数失败: {}", e);
            return Json(NodeServiceResponse::error("获取统计信息失败"));
        }
    };

    let online_nodes = connection_manager.get_online_count().await;
    let offline_nodes = connection_manager.get_offline_count().await;

    let stats = json!({
        "total_nodes": total_nodes,
        "online_nodes": online_nodes,
        "offline_nodes": offline_nodes,
        "connection_count": online_nodes + offline_nodes
    });

    Json(NodeServiceResponse::success(stats, "获取节点统计信息成功"))
}

/// 清理长时间无活动的节点
pub async fn cleanup_stale_nodes(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    // 清理数据库中的过期节点
    match Node::cleanup_stale_nodes(&db.pool, 30).await {
        Ok(cleaned_count) => {
            info!("🧹 清理了 {} 个过期节点", cleaned_count);
            Json(NodeServiceResponse::success(cleaned_count, "清理过期节点成功"))
        }
        Err(e) => {
            error!("清理过期节点失败: {}", e);
            Json(NodeServiceResponse::error("清理过期节点失败"))
        }
    }
}


/// 应用状态（包含连接管理器）
#[derive(Clone)]
pub struct AppState {
    pub database: Arc<Mutex<Database>>,
    pub connection_manager: Arc<ConnectionManager>,
}

impl AppState {
    pub fn new(database: Database) -> Self {
        Self {
            database: Arc::new(Mutex::new(database)),
            connection_manager: Arc::new(ConnectionManager::new()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::SqlitePool;

    #[tokio::test]
    async fn test_connection_manager() {
        let manager = ConnectionManager::new();
        
        // 测试添加连接
        manager.add_connection("test-node-1".to_string()).await;
        assert_eq!(manager.get_online_count().await, 1);
        
        // 测试更新活动时间
        assert!(manager.update_activity("test-node-1").await);
        
        // 测试获取连接
        let connection = manager.get_connection("test-node-1").await;
        assert!(connection.is_some());
        assert_eq!(connection.unwrap().node_id, "test-node-1");
        
        // 测试移除连接
        assert!(manager.remove_connection("test-node-1").await);
        assert_eq!(manager.get_online_count().await, 0);
    }

    #[tokio::test]
    async fn test_connection_manager_cleanup() {
        let manager = ConnectionManager::new();
        
        // 添加测试连接
        manager.add_connection("test-node-1".to_string()).await;
        
        // 清理应该不会移除刚刚添加的连接
        let cleaned = manager.cleanup_inactive_connections(1).await;
        assert_eq!(cleaned, 0);
        assert_eq!(manager.get_online_count().await, 1);
    }

    #[test]
    fn test_node_service_response() {
        // 测试成功响应
        let success_response = NodeServiceResponse::success("test_data", "操作成功");
        assert!(success_response.success);
        assert_eq!(success_response.message, "操作成功");
        assert!(success_response.data.is_some());
        
        // 测试错误响应
        let error_response = NodeServiceResponse::<()>::error("操作失败");
        assert!(!error_response.success);
        assert_eq!(error_response.message, "操作失败");
        assert!(error_response.data.is_none());
    }
}
