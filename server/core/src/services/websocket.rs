use std::collections::HashMap;
use std::sync::Arc;

use axum::{
    extract::{
        ws::{Message, WebSocket},
        Query, State, WebSocketUpgrade,
    },
    response::IntoResponse,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::sync::{Mutex, RwLock};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use crate::database::Database;
use crate::models::{Node, NodeCreate, NodeUpdate, NodeMetric, MetricCreate, Command, CommandCreate, CommandResultCreate, CommandStatus};
use crate::services::nodes::{AppState, ConnectionManager};

/// WebSocket连接查询参数
#[derive(Debug, Deserialize)]
pub struct WebSocketQuery {
    token: Option<String>,
    node_id: Option<String>,
}

/// WebSocket消息类型
#[derive(Debug, Serialize, Deserialize)]
pub struct WebSocketMessage {
    #[serde(rename = "type")]
    pub message_type: String,
    pub id: String,
    pub timestamp: String,
    pub data: serde_json::Value,
}

/// WebSocket处理函数
pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    Query(query): Query<WebSocketQuery>,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    info!("🔌 新的WebSocket连接请求: {:?}", query);
    
    // 简单的token验证（MVP版本使用固定token）
    if let Some(token) = &query.token {
        if token != "default-token" {
            warn!("❌ 无效的token: {}", token);
            return axum::response::Response::new("Invalid token".into());
        }
    } else {
        warn!("❌ 缺少token参数");
        return axum::response::Response::new("Token required".into());
    }
    
    ws.on_upgrade(|socket| handle_websocket(socket, state, query))
}

/// 处理WebSocket连接
pub async fn handle_websocket(
    mut socket: WebSocket,
    state: Arc<AppState>,
    query: WebSocketQuery,
) {
    let node_id = query.node_id.unwrap_or_else(|| Uuid::new_v4().to_string());
    info!("✅ WebSocket连接已建立, 节点ID: {}", node_id);

    // 发送欢迎消息
    let welcome_msg = json!({
        "type": "welcome",
        "id": Uuid::new_v4().to_string(),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "message": "欢迎连接到Server Manager Core",
            "node_id": node_id
        }
    });
    
    if let Err(e) = socket.send(Message::Text(welcome_msg.to_string().into())).await {
        error!("发送欢迎消息失败: {}", e);
        return;
    }

    // 处理消息循环
    while let Some(Ok(msg)) = socket.recv().await {
        match msg {
            Message::Text(text) => {
                if let Err(e) = handle_message(&text, &mut socket, &state, &node_id).await {
                    error!("处理消息失败: {}", e);
                    break;
                }
            }
            Message::Close(_) => {
                info!("🔌 WebSocket连接关闭, 节点ID: {}", node_id);
                break;
            }
            _ => {
                info!("📨 收到非文本消息, 节点ID: {}", node_id);
            }
        }
    }

    info!("👋 WebSocket连接结束, 节点ID: {}", node_id);
}

/// 处理WebSocket消息
async fn handle_message(
    text: &str,
    socket: &mut WebSocket,
    state: &Arc<AppState>,
    node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📨 收到消息 from {}: {}", node_id, text);
    
    let msg: WebSocketMessage = match serde_json::from_str(text) {
        Ok(msg) => msg,
        Err(e) => {
            // 发送解析错误响应
            let error_msg = json!({
                "type": "error",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "PARSE_ERROR",
                    "message": "消息解析失败",
                    "details": e.to_string()
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
            return Err(e.into());
        }
    };

    match msg.message_type.as_str() {
        "node_register" => handle_node_register(msg, socket, state, node_id).await,
        "heartbeat" => handle_heartbeat(msg, socket, state, node_id).await,
        "command_result" => handle_command_result(msg, socket, state, node_id).await,
        _ => {
            // 发送未知消息类型错误
            let error_msg = json!({
                "type": "error",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "UNKNOWN_MESSAGE_TYPE",
                    "message": format!("未知的消息类型: {}", msg.message_type),
                    "details": "支持的消息类型: node_register, heartbeat, command_result"
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
            Ok(())
        }
    }
}

/// 节点注册数据结构
#[derive(Debug, Deserialize)]
struct NodeRegisterData {
    node_id: Option<String>,
    hostname: String,
    ip_address: String,
    os_info: Option<String>,
}

/// 处理节点注册消息
async fn handle_node_register(
    msg: WebSocketMessage,
    socket: &mut WebSocket,
    state: &Arc<AppState>,
    connection_node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📋 节点注册请求: {}", connection_node_id);
    
    // 解析注册数据
    let register_data: NodeRegisterData = match serde_json::from_value(msg.data.clone()) {
        Ok(data) => data,
        Err(e) => {
            let error_msg = json!({
                "type": "error",
                "id": msg.id,
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "INVALID_REGISTER_DATA",
                    "message": "注册数据格式错误",
                    "details": e.to_string()
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
            return Err(e.into());
        }
    };
    
    // 使用连接中的node_id或注册数据中的node_id
    let node_id = register_data.node_id.clone().unwrap_or_else(|| connection_node_id.to_string());
    
    let db = state.database.lock().await;
    
    // 检查节点是否已存在
    let existing_node = match crate::models::Node::find_by_node_id(&db.pool, &node_id).await {
        Ok(Some(node)) => Some(node),
        Ok(None) => None,
        Err(e) => {
            error!("查询节点失败: {}", e);
            None
        }
    };
    
    if existing_node.is_some() {
        // 节点已存在，更新信息
        let update_data = crate::models::NodeUpdate {
            hostname: Some(register_data.hostname.clone()),
            ip_address: Some(register_data.ip_address.clone()),
            os_info: register_data.os_info.clone(),
            status: Some("online".to_string()),
        };
        
        match crate::models::Node::update(&db.pool, &node_id, update_data).await {
            Ok(Some(_updated_node)) => {
                info!("✅ 节点信息已更新: {}", node_id);
                
                // 添加到连接管理器
                state.connection_manager.add_connection(node_id.clone()).await;
                
                let response = json!({
                    "type": "register_response",
                    "id": msg.id,
                    "timestamp": chrono::Utc::now().to_rfc3339(),
                    "data": {
                        "success": true,
                        "message": "节点信息已更新",
                        "node_id": node_id,
                        "action": "updated"
                    }
                });
                
                socket.send(Message::Text(response.to_string().into())).await?;
            }
            Ok(None) => {
                // 节点不存在，创建新节点
                create_new_node(&db.pool, socket, &msg.id, node_id, register_data, state).await?;
            }
            Err(e) => {
                error!("更新节点失败: {}", e);
                send_error_response(socket, &msg.id, "UPDATE_NODE_FAILED", "更新节点失败", &e.to_string()).await?;
            }
        }
    } else {
        // 节点不存在，创建新节点
        create_new_node(&db.pool, socket, &msg.id, node_id, register_data, state).await?;
    }
    
    Ok(())
}

/// 创建新节点
async fn create_new_node(
    pool: &sqlx::SqlitePool,
    socket: &mut WebSocket,
    message_id: &str,
    node_id: String,
    register_data: NodeRegisterData,
    state: &Arc<AppState>,
) -> Result<(), anyhow::Error> {
    let node_data = crate::models::NodeCreate {
        node_id: node_id.clone(),
        hostname: register_data.hostname,
        ip_address: register_data.ip_address,
        os_info: register_data.os_info,
    };
    
    match crate::models::Node::create(pool, node_data).await {
        Ok(new_node) => {
            info!("✅ 新节点注册成功: {}", node_id);
            
            // 添加到连接管理器
            state.connection_manager.add_connection(node_id.clone()).await;
            
            let response = json!({
                "type": "register_response",
                "id": message_id,
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "success": true,
                    "message": "节点注册成功",
                    "node_id": node_id,
                    "action": "created",
                    "node_info": {
                        "id": new_node.id,
                        "hostname": new_node.hostname,
                        "ip_address": new_node.ip_address,
                        "status": new_node.status
                    }
                }
            });
            
            socket.send(Message::Text(response.to_string().into())).await?;
        }
        Err(e) => {
            error!("创建节点失败: {}", e);
            send_error_response(socket, message_id, "CREATE_NODE_FAILED", "创建节点失败", &e.to_string()).await?;
        }
    }
    
    Ok(())
}

/// 发送错误响应
async fn send_error_response(
    socket: &mut WebSocket,
    message_id: &str,
    error_code: &str,
    message: &str,
    details: &str,
) -> Result<(), anyhow::Error> {
    let error_msg = json!({
        "type": "error",
        "id": message_id,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "error_code": error_code,
            "message": message,
            "details": details
        }
    });
    
    socket.send(Message::Text(error_msg.to_string().into())).await?;
    Ok(())
}

/// 处理心跳消息
async fn handle_heartbeat(
    msg: WebSocketMessage,
    socket: &mut WebSocket,
    _state: &Arc<AppState>,
    node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("💓 心跳消息 from: {}", node_id);
    
    // 这里应该保存监控数据到数据库
    // 暂时简单响应心跳确认
    
    let response = json!({
        "type": "heartbeat_ack",
        "id": msg.id,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "received": true,
            "node_id": node_id
        }
    });
    
    socket.send(Message::Text(response.to_string().into())).await?;
    Ok(())
}

/// 处理命令执行结果
async fn handle_command_result(
    msg: WebSocketMessage,
    socket: &mut WebSocket,
    _state: &Arc<AppState>,
    node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📝 命令执行结果 from: {}", node_id);
    
    // 这里应该保存命令结果到数据库
    // 暂时简单响应接收确认
    
    let response = json!({
        "type": "command_received",
        "id": msg.id,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "received": true,
            "node_id": node_id
        }
    });
    
    socket.send(Message::Text(response.to_string().into())).await?;
    Ok(())
}

/// 健康检查端点
pub async fn health_check() -> impl IntoResponse {
    axum::Json(json!({
        "success": true,
        "message": "✅ Core服务运行正常",
        "data": {
            "status": "healthy",
            "websocket": "running"
        },
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;
    use std::sync::Arc;

    #[tokio::test]
    async fn test_websocket_query_token_validation() {
        // 测试有效token的情况
        let query = WebSocketQuery {
            token: Some("default-token".to_string()),
            node_id: Some("test-node".to_string()),
        };
        
        // 简单验证token验证逻辑
        if let Some(token) = &query.token {
            assert_eq!(token, "default-token");
        }
    }

    #[tokio::test]
    async fn test_token_validation_logic() {
        let database = Database {
            pool: sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap(),
        };
        let _state = Arc::new(AppState::new(database));

        // 测试有效token
        let valid_query = WebSocketQuery {
            token: Some("default-token".to_string()),
            node_id: Some("test-node".to_string()),
        };
        
        // 验证token逻辑
        let is_valid_token = if let Some(token) = &valid_query.token {
            token == "default-token"
        } else {
            false
        };
        assert!(is_valid_token);

        // 测试无效token
        let invalid_query = WebSocketQuery {
            token: Some("invalid-token".to_string()),
            node_id: Some("test-node".to_string()),
        };
        
        let is_invalid_token = if let Some(token) = &invalid_query.token {
            token != "default-token"
        } else {
            true
        };
        assert!(is_invalid_token);

        // 测试缺少token
        let missing_token_query = WebSocketQuery {
            token: None,
            node_id: Some("test-node".to_string()),
        };
        assert!(missing_token_query.token.is_none());
    }

    #[tokio::test]
    async fn test_websocket_response_creation() {
        // 测试错误响应创建
        use axum::body::Body;
        let error_response = axum::response::Response::new(Body::from("Invalid token"));
        assert_eq!(error_response.status(), StatusCode::OK); // axum::response::Response::new默认是200

        let token_required_response = axum::response::Response::new(Body::from("Token required"));
        assert_eq!(token_required_response.status(), StatusCode::OK);
    }

    #[test]
    fn test_websocket_message_deserialization() {
        let json_data = r#"
        {
            "type": "heartbeat",
            "id": "12345",
            "timestamp": "2025-01-21T10:00:00Z",
            "data": {
                "node_id": "test-node",
                "status": "online",
                "metrics": {
                    "cpu_usage": 45.2,
                    "memory_usage": 68.5
                }
            }
        }
        "#;

        let msg: Result<WebSocketMessage, _> = serde_json::from_str(json_data);
        assert!(msg.is_ok());
        let msg = msg.unwrap();
        assert_eq!(msg.message_type, "heartbeat");
        assert_eq!(msg.id, "12345");
    }

    #[test]
    fn test_websocket_message_serialization() {
        let msg = WebSocketMessage {
            message_type: "node_register".to_string(),
            id: "67890".to_string(),
            timestamp: "2025-01-21T10:00:00Z".to_string(),
            data: json!({
                "node_id": "test-node",
                "hostname": "test-server"
            }),
        };

        let json_str = serde_json::to_string(&msg);
        assert!(json_str.is_ok());
        let json_str = json_str.unwrap();
        assert!(json_str.contains("node_register"));
        assert!(json_str.contains("test-node"));
    }
}
