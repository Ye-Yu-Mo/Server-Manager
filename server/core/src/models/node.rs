use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, SqlitePool};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Node {
    pub id: i64,
    pub node_id: String,
    pub hostname: String,
    pub ip_address: String,
    pub os_info: Option<String>,
    pub status: String,
    pub last_heartbeat: Option<DateTime<Utc>>,
    pub registered_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NodeCreate {
    pub node_id: String,
    pub hostname: String,
    pub ip_address: String,
    pub os_info: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NodeUpdate {
    pub hostname: Option<String>,
    pub ip_address: Option<String>,
    pub os_info: Option<String>,
    pub status: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NodeHeartbeat {
    pub node_id: String,
    pub status: String,
}

impl Node {
    /// 创建新节点
    pub async fn create(pool: &SqlitePool, node_data: NodeCreate) -> Result<Node> {
        let node = sqlx::query_as::<_, Node>(r#"
            INSERT INTO nodes (node_id, hostname, ip_address, os_info)
            VALUES (?, ?, ?, ?)
            RETURNING *
        "#)
        .bind(&node_data.node_id)
        .bind(&node_data.hostname)
        .bind(&node_data.ip_address)
        .bind(&node_data.os_info)
        .fetch_one(pool)
        .await?;
        
        Ok(node)
    }
    
    /// 根据node_id查找节点
    pub async fn find_by_node_id(pool: &SqlitePool, node_id: &str) -> Result<Option<Node>> {
        let node = sqlx::query_as::<_, Node>("SELECT * FROM nodes WHERE node_id = ?")
            .bind(node_id)
            .fetch_optional(pool)
            .await?;
            
        Ok(node)
    }
    
    /// 获取所有节点
    pub async fn find_all(pool: &SqlitePool) -> Result<Vec<Node>> {
        let nodes = sqlx::query_as::<_, Node>("SELECT * FROM nodes ORDER BY registered_at DESC")
            .fetch_all(pool)
            .await?;
            
        Ok(nodes)
    }
    
    /// 获取在线节点
    pub async fn find_online(pool: &SqlitePool) -> Result<Vec<Node>> {
        let nodes = sqlx::query_as::<_, Node>(
            "SELECT * FROM nodes WHERE status = 'online' ORDER BY last_heartbeat DESC"
        )
        .fetch_all(pool)
        .await?;
        
        Ok(nodes)
    }
    
    /// 更新节点信息
    pub async fn update(pool: &SqlitePool, node_id: &str, update_data: NodeUpdate) -> Result<Option<Node>> {
        // 简化版本的update，避免复杂的动态查询构建
        if update_data.hostname.is_none() && update_data.ip_address.is_none() && 
           update_data.os_info.is_none() && update_data.status.is_none() {
            return Self::find_by_node_id(pool, node_id).await;
        }
        
        // 先获取当前节点信息
        let current = Self::find_by_node_id(pool, node_id).await?;
        if let Some(current_node) = current {
            let new_hostname = update_data.hostname.unwrap_or(current_node.hostname);
            let new_ip = update_data.ip_address.unwrap_or(current_node.ip_address);
            let new_os_info = update_data.os_info.or(current_node.os_info);
            let new_status = update_data.status.unwrap_or(current_node.status);
            
            let node = sqlx::query_as::<_, Node>(r#"
                UPDATE nodes 
                SET hostname = ?, ip_address = ?, os_info = ?, status = ?, updated_at = CURRENT_TIMESTAMP
                WHERE node_id = ? 
                RETURNING *
            "#)
            .bind(&new_hostname)
            .bind(&new_ip)
            .bind(&new_os_info)
            .bind(&new_status)
            .bind(node_id)
            .fetch_optional(pool)
            .await?;
            
            Ok(node)
        } else {
            Ok(None)
        }
    }
    
    /// 更新心跳
    pub async fn update_heartbeat(pool: &SqlitePool, node_id: &str) -> Result<()> {
        sqlx::query(r#"
            UPDATE nodes 
            SET last_heartbeat = CURRENT_TIMESTAMP, 
                status = 'online',
                updated_at = CURRENT_TIMESTAMP
            WHERE node_id = ?
        "#)
        .bind(node_id)
        .execute(pool)
        .await?;
        
        Ok(())
    }
    
    /// 标记节点离线
    pub async fn mark_offline(pool: &SqlitePool, node_id: &str) -> Result<()> {
        sqlx::query(r#"
            UPDATE nodes 
            SET status = 'offline', 
                updated_at = CURRENT_TIMESTAMP
            WHERE node_id = ?
        "#)
        .bind(node_id)
        .execute(pool)
        .await?;
        
        Ok(())
    }
    
    /// 删除节点
    pub async fn delete(pool: &SqlitePool, node_id: &str) -> Result<bool> {
        let result = sqlx::query("DELETE FROM nodes WHERE node_id = ?")
            .bind(node_id)
            .execute(pool)
            .await?;
            
        Ok(result.rows_affected() > 0)
    }
    
    /// 清理长时间无心跳的离线节点
    pub async fn cleanup_stale_nodes(pool: &SqlitePool, timeout_minutes: i64) -> Result<u64> {
        let result = sqlx::query(r#"
            UPDATE nodes 
            SET status = 'offline' 
            WHERE status = 'online' 
            AND (last_heartbeat IS NULL OR last_heartbeat < datetime('now', '-' || ? || ' minutes'))
        "#)
        .bind(timeout_minutes)
        .execute(pool)
        .await?;
        
        Ok(result.rows_affected())
    }
}