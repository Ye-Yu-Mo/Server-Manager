use anyhow::Result;
use futures_util::{SinkExt, StreamExt};
use serde::Serialize;
use std::net::{IpAddr, UdpSocket};
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message, MaybeTlsStream, WebSocketStream};
use tracing::{error, info, warn};
use uuid::Uuid;

use crate::config::NodeConfig;
use crate::monitor::{SystemMetrics, SystemMonitor};

/// WebSocket客户端
pub struct WebSocketClient {
    stream: Option<WebSocketStream<MaybeTlsStream<TcpStream>>>,
    config: NodeConfig,
    node_id: String,
}

/// WebSocket消息格式（与Core服务保持一致）
#[derive(Debug, Serialize)]
pub struct WebSocketMessage {
    #[serde(rename = "type")]
    pub message_type: String,
    pub id: String,
    pub timestamp: String,
    pub data: serde_json::Value,
}

impl WebSocketClient {
    /// 创建新的WebSocket客户端
    pub fn new(config: NodeConfig, node_id: String) -> Self {
        Self {
            stream: None,
            config,
            node_id,
        }
    }

    /// 连接到Core服务的WebSocket服务器
    pub async fn connect(&mut self) -> Result<()> {
        let url = self.config.get_websocket_url(&self.node_id);
        info!("🔗 连接到WebSocket服务器: {}", url);

        match connect_async(&url).await {
            Ok((ws_stream, response)) => {
                info!("✅ WebSocket连接成功");
                info!("📡 服务器响应: {:?}", response.status());
                
                self.stream = Some(ws_stream);
                Ok(())
            }
            Err(e) => {
                error!("❌ WebSocket连接失败: {}", e);
                Err(anyhow::anyhow!("WebSocket连接失败: {}", e))
            }
        }
    }

    /// 发送节点注册消息
    pub async fn send_register_message(&mut self, monitor: &SystemMonitor) -> Result<()> {
        let system_info = monitor.get_system_info();
        
        // 获取本机IP地址
        let ip_address = get_local_ip().unwrap_or_else(|| "127.0.0.1".to_string());
        
        let message = WebSocketMessage {
            message_type: "node_register".to_string(),
            id: Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
            data: serde_json::json!({
                "node_id": self.node_id,
                "hostname": system_info.hostname,
                "ip_address": ip_address,
                "os_info": format!("{} {}", system_info.os_name, system_info.os_version),
                "cpu_count": system_info.cpu_count,
                "total_memory": system_info.total_memory,
            }),
        };

        self.send_message(message).await
    }

    /// 发送心跳消息（包含监控数据）
    pub async fn send_heartbeat(&mut self, metrics: &SystemMetrics) -> Result<()> {
        let message = WebSocketMessage {
            message_type: "heartbeat".to_string(),
            id: Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
            data: serde_json::json!({
                "node_id": self.node_id,
                "status": "online",
                "metrics": {
                    "cpu_usage": metrics.cpu_usage,
                    "memory_usage": metrics.memory_usage,
                    "memory_total": metrics.memory_total,
                    "memory_available": metrics.memory_available,
                    "uptime": metrics.uptime,
                }
            }),
        };

        self.send_message(message).await
    }

    /// 发送WebSocket消息
    async fn send_message(&mut self, message: WebSocketMessage) -> Result<()> {
        if let Some(stream) = &mut self.stream {
            let json_message = serde_json::to_string(&message)?;
            
            match stream.send(Message::Text(json_message.into())).await {
                Ok(_) => {
                    info!("📤 消息发送成功: {}", message.message_type);
                    Ok(())
                }
                Err(e) => {
                    error!("❌ 消息发送失败: {}", e);
                    Err(anyhow::anyhow!("消息发送失败: {}", e))
                }
            }
        } else {
            Err(anyhow::anyhow!("WebSocket连接未建立"))
        }
    }

    /// 接收消息（用于处理服务器响应）
    pub async fn receive_message(&mut self) -> Result<Option<String>> {
        if let Some(stream) = &mut self.stream {
            match stream.next().await {
                Some(Ok(message)) => {
                    match message {
                        Message::Text(text) => {
                            info!("📥 收到消息: {}", text);
                            Ok(Some(text.to_string()))
                        }
                        Message::Close(_) => {
                            info!("🔌 收到关闭消息");
                            Ok(None)
                        }
                        _ => {
                            warn!("⚠️ 收到未知类型的消息");
                            Ok(None)
                        }
                    }
                }
                Some(Err(e)) => {
                    error!("❌ 接收消息错误: {}", e);
                    Err(anyhow::anyhow!("接收消息错误: {}", e))
                }
                None => {
                    info!("📭 连接已关闭");
                    Ok(None)
                }
            }
        } else {
            Err(anyhow::anyhow!("WebSocket连接未建立"))
        }
    }

    /// 关闭WebSocket连接
    pub async fn close(&mut self) -> Result<()> {
        if let Some(stream) = &mut self.stream {
            match stream.close(None).await {
                Ok(_) => {
                    info!("👋 WebSocket连接已关闭");
                    Ok(())
                }
                Err(e) => {
                    error!("❌ 关闭连接失败: {}", e);
                    Err(anyhow::anyhow!("关闭连接失败: {}", e))
                }
            }
        } else {
            Ok(())
        }
    }

    /// 检查连接状态
    pub fn is_connected(&self) -> bool {
        self.stream.is_some()
    }

    /// 获取节点ID
    pub fn get_node_id(&self) -> &str {
        &self.node_id
    }
}

/// WebSocket错误处理
#[derive(Debug)]
pub enum WebSocketError {
    ConnectionError(String),
    SendError(String),
    ReceiveError(String),
}

impl std::fmt::Display for WebSocketError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WebSocketError::ConnectionError(msg) => write!(f, "连接错误: {}", msg),
            WebSocketError::SendError(msg) => write!(f, "发送错误: {}", msg),
            WebSocketError::ReceiveError(msg) => write!(f, "接收错误: {}", msg),
        }
    }
}

impl std::error::Error for WebSocketError {}


/// 获取本地IP地址
fn get_local_ip() -> Option<String> {
    // 尝试连接到外部地址来获取本地IP
    let socket = match UdpSocket::bind("0.0.0.0:0") {
        Ok(s) => s,
        Err(_) => return None,
    };
    
    match socket.connect("8.8.8.8:80") {
        Ok(()) => (),
        Err(_) => return None,
    };
    
    match socket.local_addr() {
        Ok(addr) => Some(addr.ip().to_string()),
        Err(_) => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_serialization() {
        let message = WebSocketMessage {
            message_type: "test".to_string(),
            id: "test-id".to_string(),
            timestamp: "2025-01-01T00:00:00Z".to_string(),
            data: serde_json::json!({"test": "data"}),
        };

        let json = serde_json::to_string(&message).unwrap();
        assert!(json.contains("test"));
        assert!(json.contains("test-id"));
        assert!(json.contains("type")); // 确保序列化后是"type"字段
    }

    #[test]
    fn test_get_local_ip() {
        let ip = get_local_ip();
        assert!(ip.is_some());
        // IP地址应该不是回环地址
        if let Some(ip_str) = ip {
            assert_ne!(ip_str, "127.0.0.1");
        }
    }
}
