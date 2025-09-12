use std::collections::HashMap;
use std::sync::Arc;

use axum::{
    extract::{
        ws::{Message, WebSocket},
        Query, State, WebSocketUpgrade,
    },
    response::IntoResponse,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::sync::{broadcast, mpsc, Mutex, RwLock};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use crate::database::Database;
use crate::models::{Node, NodeCreate, NodeUpdate, NodeMetric, MetricCreate, Command, CommandCreate, CommandResultCreate, CommandStatus};
use crate::services::nodes::{AppState, ConnectionManager, ClientBroadcastMessage};

/// WebSocket连接查询参数
#[derive(Debug, Deserialize)]
pub struct WebSocketQuery {
    token: Option<String>,
    node_id: Option<String>,
    #[serde(rename = "type")]
    connection_type: Option<String>,
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
    
    // 根据连接类型分发处理
    let connection_type = query.connection_type.as_deref().unwrap_or("node");
    match connection_type {
        "monitor" => {
            info!("📱 客户端监控连接");
            ws.on_upgrade(|socket| handle_client_websocket(socket, state, query))
        }
        _ => {
            info!("🤖 节点代理连接");
            ws.on_upgrade(|socket| handle_websocket(socket, state, query))
        }
    }
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
    
    // 处理节点断开连接
    handle_node_disconnect(&node_id, &state).await;
}

/// 处理节点断开连接
async fn handle_node_disconnect(node_id: &str, state: &Arc<AppState>) {
    let db = state.database.lock().await;
    
    // 1. 将数据库中的节点状态标记为离线
    if let Err(e) = crate::models::Node::mark_offline(&db.pool, node_id).await {
        error!("标记节点离线失败: {}", e);
    } else {
        info!("✅ 节点已标记为离线: {}", node_id);
    }
    
    // 2. 从连接管理器中移除连接
    state.connection_manager.remove_connection(node_id).await;
    
    // 3. 向所有客户端广播节点状态变化
    let status_change_message = crate::services::nodes::ClientBroadcastMessage {
        message_type: "node_status_change".to_string(),
        id: uuid::Uuid::new_v4().to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
        data: serde_json::json!({
            "node_id": node_id,
            "status": "offline",
            "timestamp": chrono::Utc::now().to_rfc3339()
        }),
    };
    
    state.broadcast_to_clients(status_change_message);
    info!("📢 广播节点状态变化: {} -> offline", node_id);
}

/// 处理WebSocket消息
async fn handle_message(
    text: &str,
    socket: &mut WebSocket,
    state: &Arc<AppState>,
    connection_node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📨 收到消息 from {}: {}", connection_node_id, text);
    
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

    // 确定要使用的节点ID：优先使用消息中的node_id，如果没有则使用连接时的node_id
    let node_id = if let Some(msg_node_id) = extract_node_id_from_message(&msg) {
        msg_node_id
    } else {
        connection_node_id.to_string()
    };

    match msg.message_type.as_str() {
        "node_register" => handle_node_register(msg, socket, state, &node_id).await,
        "heartbeat" => handle_heartbeat(msg, socket, state, &node_id).await,
        "metrics" => handle_metrics(msg, socket, state, &node_id).await,
        "command_result" => handle_command_result(msg, socket, state, &node_id).await,
        _ => {
            // 发送未知消息类型错误
            let error_msg = json!({
                "type": "error",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "UNKNOWN_MESSAGE_TYPE",
                    "message": format!("未知的消息类型: {}", msg.message_type),
                    "details": "支持的消息类型: node_register, heartbeat, metrics, command_result"
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
            Ok(())
        }
    }
}

/// 从消息中提取节点ID
fn extract_node_id_from_message(msg: &WebSocketMessage) -> Option<String> {
    // 尝试从data字段中提取node_id
    if let Some(node_id) = msg.data.get("node_id").and_then(|v| v.as_str()) {
        return Some(node_id.to_string());
    }
    
    // 如果消息类型是node_register，尝试从注册数据中提取
    if msg.message_type == "node_register" {
        if let Ok(register_data) = serde_json::from_value::<NodeRegisterData>(msg.data.clone()) {
            return register_data.node_id;
        }
    }
    
    None
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
                
                // 广播节点状态变化
                let status_change_message = crate::services::nodes::ClientBroadcastMessage {
                    message_type: "node_status_change".to_string(),
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp: chrono::Utc::now().to_rfc3339(),
                    data: serde_json::json!({
                        "node_id": node_id,
                        "status": "online",
                        "timestamp": chrono::Utc::now().to_rfc3339()
                    }),
                };
                state.broadcast_to_clients(status_change_message);
                info!("📢 广播节点状态变化: {} -> online", node_id);
                
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
            
            // 广播节点状态变化
            let status_change_message = crate::services::nodes::ClientBroadcastMessage {
                message_type: "node_status_change".to_string(),
                id: uuid::Uuid::new_v4().to_string(),
                timestamp: chrono::Utc::now().to_rfc3339(),
                data: serde_json::json!({
                    "node_id": node_id,
                    "status": "online",
                    "timestamp": chrono::Utc::now().to_rfc3339()
                }),
            };
            state.broadcast_to_clients(status_change_message);
            info!("📢 广播新节点状态变化: {} -> online", node_id);
            
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

/// 监控数据结构
#[derive(Debug, Deserialize)]
struct MetricData {
    cpu_usage: Option<f64>,
    memory_usage: Option<f64>,
    disk_usage: Option<f64>,
    load_average: Option<f64>,
    // 可选的其他字段，用于未来扩展
    memory_total: Option<f64>,
    memory_available: Option<f64>,
    disk_total: Option<f64>,
    disk_available: Option<f64>,
    network_rx: Option<f64>,
    network_tx: Option<f64>,
    uptime: Option<f64>,
}

/// 处理心跳消息（包含监控数据）
async fn handle_heartbeat(
    msg: WebSocketMessage,
    socket: &mut WebSocket,
    state: &Arc<AppState>,
    node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("💓 心跳消息 from: {}", node_id);
    
    // 解析监控数据 - 从heartbeat消息的metrics字段中提取
    let metric_data: MetricData = match msg.data.get("metrics").and_then(|v| serde_json::from_value(v.clone()).ok()) {
        Some(data) => data,
        None => {
            warn!("心跳消息中缺少metrics字段或格式错误");
            // 即使数据格式错误，也继续处理心跳
            MetricData {
                cpu_usage: None,
                memory_usage: None,
                memory_total: None,
                memory_available: None,
                disk_usage: None,
                disk_total: None,
                disk_available: None,
                network_rx: None,
                network_tx: None,
                load_average: None,
                uptime: None,
            }
        }
    };
    
    // 保存监控数据到数据库
    let db = state.database.lock().await;
    
    // 首先检查节点是否存在，如果不存在则创建
    let node_exists = match crate::models::Node::find_by_node_id(&db.pool, node_id).await {
        Ok(Some(_)) => true,
        Ok(None) => false,
        Err(e) => {
            error!("检查节点存在失败: {}", e);
            false
        }
    };
    
    if !node_exists {
        // 节点不存在，自动创建节点
        let node_data = crate::models::NodeCreate {
            node_id: node_id.to_string(),
            hostname: "unknown".to_string(),
            ip_address: "0.0.0.0".to_string(),
            os_info: None,
        };
        
        match crate::models::Node::create(&db.pool, node_data).await {
            Ok(_) => {
                info!("✅ 自动创建节点: {}", node_id);
                // 添加到连接管理器
                state.connection_manager.add_connection(node_id.to_string()).await;
            }
            Err(e) => {
                error!("❌ 自动创建节点失败: {}", e);
            }
        }
    }
    
    let metric_create = crate::models::MetricCreate {
        node_id: node_id.to_string(),
        cpu_usage: metric_data.cpu_usage,
        memory_usage: metric_data.memory_usage,
        disk_usage: metric_data.disk_usage,
        disk_total: metric_data.disk_total.map(|v| v as i64),
        disk_available: metric_data.disk_available.map(|v| v as i64),
        load_average: metric_data.load_average,
        memory_total: metric_data.memory_total.map(|v| v as i64),
        memory_available: metric_data.memory_available.map(|v| v as i64),
        uptime: metric_data.uptime.map(|v| v as i64),
    };
    
    // 更新节点心跳时间和在线状态
    if let Err(e) = crate::models::Node::update_heartbeat(&db.pool, node_id).await {
        error!("❌ 更新节点心跳失败: {}", e);
    }
    
    // 更新连接管理器中的活动时间
    state.connection_manager.update_activity(node_id).await;
    
    match crate::models::NodeMetric::create(&db.pool, metric_create).await {
        Ok(metric) => {
            debug!("✅ 监控数据保存成功: {}", node_id);
            
            // 广播新的监控数据给所有客户端（包含完整的原始数据）
            let enhanced_metric = json!({
                "id": metric.id,
                "node_id": metric.node_id,
                "metric_time": metric.metric_time,
                "cpu_usage": metric.cpu_usage,
                "memory_usage": metric.memory_usage,
                "disk_usage": metric.disk_usage,
                "disk_total": metric.disk_total,
                "disk_available": metric.disk_available,
                "load_average": metric.load_average,
                "memory_total": metric.memory_total,
                "memory_available": metric.memory_available,
                "uptime": metric.uptime,
                "created_at": metric.created_at,
            });
            
            let broadcast_msg = ClientBroadcastMessage {
                message_type: "metrics_update".to_string(),
                id: Uuid::new_v4().to_string(),
                timestamp: chrono::Utc::now().to_rfc3339(),
                data: json!({
                    "metrics": [enhanced_metric]
                }),
            };
            state.broadcast_to_clients(broadcast_msg);
        }
        Err(e) => {
            error!("❌ 保存监控数据失败: {}", e);
        }
    }
    
    let response = json!({
        "type": "heartbeat_ack",
        "id": msg.id,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "received": true,
            "node_id": node_id,
            "metrics_saved": true
        }
    });
    
    socket.send(Message::Text(response.to_string().into())).await?;
    Ok(())
}

/// 处理专门的监控数据消息
async fn handle_metrics(
    msg: WebSocketMessage,
    socket: &mut WebSocket,
    state: &Arc<AppState>,
    node_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📊 监控数据消息 from: {}", node_id);
    
    // 解析监控数据
    let metric_data: MetricData = match serde_json::from_value(msg.data.clone()) {
        Ok(data) => data,
        Err(e) => {
            let error_msg = json!({
                "type": "error",
                "id": msg.id,
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "INVALID_METRIC_DATA",
                    "message": "监控数据格式错误",
                    "details": e.to_string()
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
            return Err(e.into());
        }
    };
    
    // 保存监控数据到数据库
    let db = state.database.lock().await;
    
    // 首先检查节点是否存在，如果不存在则创建
    let node_exists = match crate::models::Node::find_by_node_id(&db.pool, node_id).await {
        Ok(Some(_)) => true,
        Ok(None) => false,
        Err(e) => {
            error!("检查节点存在失败: {}", e);
            false
        }
    };
    
    if !node_exists {
        // 节点不存在，自动创建节点
        let node_data = crate::models::NodeCreate {
            node_id: node_id.to_string(),
            hostname: "unknown".to_string(),
            ip_address: "0.0.0.0".to_string(),
            os_info: None,
        };
        
        match crate::models::Node::create(&db.pool, node_data).await {
            Ok(_) => {
                info!("✅ 自动创建节点: {}", node_id);
                // 添加到连接管理器
                state.connection_manager.add_connection(node_id.to_string()).await;
            }
            Err(e) => {
                error!("❌ 自动创建节点失败: {}", e);
                send_error_response(socket, &msg.id, "CREATE_NODE_FAILED", "自动创建节点失败", &e.to_string()).await?;
                return Ok(());
            }
        }
    }
    
    let metric_create = crate::models::MetricCreate {
        node_id: node_id.to_string(),
        cpu_usage: metric_data.cpu_usage,
        memory_usage: metric_data.memory_usage,
        disk_usage: metric_data.disk_usage,
        disk_total: metric_data.disk_total.map(|v| v as i64),
        disk_available: metric_data.disk_available.map(|v| v as i64),
        load_average: metric_data.load_average,
        memory_total: metric_data.memory_total.map(|v| v as i64),
        memory_available: metric_data.memory_available.map(|v| v as i64),
        uptime: metric_data.uptime.map(|v| v as i64),
    };
    
    match crate::models::NodeMetric::create(&db.pool, metric_create).await {
        Ok(metric) => {
            info!("✅ 监控数据保存成功: {}", node_id);
            
            // 广播新的监控数据给所有客户端
            let broadcast_msg = ClientBroadcastMessage {
                message_type: "metrics_update".to_string(),
                id: Uuid::new_v4().to_string(),
                timestamp: chrono::Utc::now().to_rfc3339(),
                data: json!({
                    "metrics": [&metric]
                }),
            };
            state.broadcast_to_clients(broadcast_msg);
            
            let response = json!({
                "type": "metrics_response",
                "id": msg.id,
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "success": true,
                    "message": "监控数据保存成功",
                    "node_id": node_id,
                    "metric_id": metric.id
                }
            });
            
            socket.send(Message::Text(response.to_string().into())).await?;
        }
        Err(e) => {
            error!("❌ 保存监控数据失败: {}", e);
            send_error_response(socket, &msg.id, "SAVE_METRICS_FAILED", "保存监控数据失败", &e.to_string()).await?;
        }
    }
    
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

/// 处理客户端监控WebSocket连接
pub async fn handle_client_websocket(
    mut socket: WebSocket,
    state: Arc<AppState>,
    _query: WebSocketQuery,
) {
    let client_id = Uuid::new_v4().to_string();
    info!("✅ 客户端监控WebSocket连接已建立, 客户端ID: {}", client_id);

    // 订阅广播消息
    let mut broadcast_receiver = state.client_broadcaster.subscribe();

    // 发送欢迎消息
    let welcome_msg = json!({
        "type": "welcome",
        "id": Uuid::new_v4().to_string(),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "message": "欢迎连接到Server Manager监控",
            "client_id": client_id,
            "connection_type": "monitor"
        }
    });
    
    if let Err(e) = socket.send(Message::Text(welcome_msg.to_string().into())).await {
        error!("发送欢迎消息失败: {}", e);
        return;
    }

    // 发送初始数据
    if let Err(e) = send_initial_data(&mut socket, &state).await {
        error!("发送初始数据失败: {}", e);
        return;
    }

    // 处理消息循环 - 同时监听客户端消息和广播消息
    loop {
        tokio::select! {
            // 处理客户端发送的消息
            client_msg = socket.recv() => {
                match client_msg {
                    Some(Ok(Message::Text(text))) => {
                        if let Err(e) = handle_client_message(&text, &mut socket, &state, &client_id).await {
                            error!("处理客户端消息失败: {}", e);
                            break;
                        }
                    }
                    Some(Ok(Message::Close(_))) => {
                        info!("🔌 客户端监控WebSocket连接关闭, 客户端ID: {}", client_id);
                        break;
                    }
                    Some(Ok(_)) => {
                        info!("📨 收到客户端非文本消息, 客户端ID: {}", client_id);
                    }
                    Some(Err(e)) => {
                        error!("客户端消息错误: {}", e);
                        break;
                    }
                    None => {
                        info!("客户端连接已关闭");
                        break;
                    }
                }
            }
            
            // 处理广播消息
            broadcast_msg = broadcast_receiver.recv() => {
                match broadcast_msg {
                    Ok(msg) => {
                        let json_msg = match serde_json::to_string(&msg) {
                            Ok(json) => json,
                            Err(e) => {
                                error!("序列化广播消息失败: {}", e);
                                continue;
                            }
                        };
                        
                        if let Err(e) = socket.send(Message::Text(json_msg.into())).await {
                            error!("发送广播消息失败: {}", e);
                            break;
                        }
                        info!("📢 向客户端 {} 广播消息: {}", client_id, msg.message_type);
                    }
                    Err(broadcast::error::RecvError::Lagged(n)) => {
                        warn!("客户端 {} 广播消息滞后 {} 条", client_id, n);
                    }
                    Err(broadcast::error::RecvError::Closed) => {
                        info!("广播通道已关闭");
                        break;
                    }
                }
            }
        }
    }

    info!("👋 客户端监控WebSocket连接结束, 客户端ID: {}", client_id);
}

/// 发送初始数据到客户端
async fn send_initial_data(
    socket: &mut WebSocket,
    state: &Arc<AppState>,
) -> Result<(), anyhow::Error> {
    let db = state.database.lock().await;
    
    // 发送节点列表
    match crate::models::Node::find_all(&db.pool).await {
        Ok(nodes) => {
            let nodes_msg = json!({
                "type": "nodes_update",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "nodes": nodes
                }
            });
            socket.send(Message::Text(nodes_msg.to_string().into())).await?;
            info!("✅ 发送节点列表: {}个节点", nodes.len());
        }
        Err(e) => {
            warn!("获取节点列表失败: {}", e);
        }
    }
    
    // 发送最新监控数据
    match crate::models::NodeMetric::find_all_latest(&db.pool).await {
        Ok(metrics) => {
            let metrics_msg = json!({
                "type": "metrics_update",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "metrics": metrics
                }
            });
            socket.send(Message::Text(metrics_msg.to_string().into())).await?;
            info!("✅ 发送监控数据: {}条记录", metrics.len());
        }
        Err(e) => {
            warn!("获取监控数据失败: {}", e);
        }
    }
    
    Ok(())
}

/// 处理客户端消息
async fn handle_client_message(
    text: &str,
    socket: &mut WebSocket,
    _state: &Arc<AppState>,
    client_id: &str,
) -> Result<(), anyhow::Error> {
    info!("📨 收到客户端消息 from {}: {}", client_id, text);
    
    let msg: WebSocketMessage = match serde_json::from_str(text) {
        Ok(msg) => msg,
        Err(e) => {
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
        "ping" => {
            // 响应心跳
            let pong_msg = json!({
                "type": "pong",
                "id": msg.id,
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "received": true,
                    "client_id": client_id
                }
            });
            socket.send(Message::Text(pong_msg.to_string().into())).await?;
            info!("💓 响应客户端心跳: {}", client_id);
        }
        _ => {
            let error_msg = json!({
                "type": "error",
                "id": Uuid::new_v4().to_string(),
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "data": {
                    "error_code": "UNKNOWN_MESSAGE_TYPE",
                    "message": format!("未知的消息类型: {}", msg.message_type),
                    "details": "支持的消息类型: ping"
                }
            });
            socket.send(Message::Text(error_msg.to_string().into())).await?;
        }
    }
    
    Ok(())
}
