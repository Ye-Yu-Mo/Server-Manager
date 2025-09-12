use anyhow::Result;
use config::{Config, Environment, File};
use serde::Deserialize;
use std::path::PathBuf;
use urlencoding;

/// 节点配置
#[derive(Debug, Deserialize, Clone)]
pub struct NodeConfig {
    pub core: CoreConfig,
    pub monitoring: MonitoringConfig,
    pub system: SystemConfig,
    pub logging: LoggingConfig,
    pub advanced: AdvancedConfig,
}

/// Core服务配置
#[derive(Debug, Deserialize, Clone)]
pub struct CoreConfig {
    pub url: String,
    pub token: String,
    pub node_id: Option<String>,
}

/// 监控配置
#[derive(Debug, Deserialize, Clone)]
pub struct MonitoringConfig {
    pub heartbeat_interval: u64,
    pub metrics_interval: u64,
    pub detailed_metrics: bool,
}

/// 系统配置
#[derive(Debug, Deserialize, Clone)]
pub struct SystemConfig {
    pub hostname: Option<String>,
    pub report_system_info: bool,
}

/// 日志配置
#[derive(Debug, Deserialize, Clone)]
pub struct LoggingConfig {
    pub level: String,
    pub file_enabled: bool,
    pub file_path: String,
    pub console_enabled: bool,
}

/// 高级配置
#[derive(Debug, Deserialize, Clone)]
pub struct AdvancedConfig {
    pub reconnect_interval: u64,
    pub max_retries: u32,
    pub command_timeout: u64,
    pub metrics_retention_days: u32,
}

impl NodeConfig {
    /// 加载配置文件
    pub fn load() -> Result<Self> {
        let config_dir = Self::get_config_dir()?;
        let default_config_path = config_dir.join("default.toml");
        
        let mut builder = Config::builder();
        
        // 加载默认配置
        if default_config_path.exists() {
            builder = builder.add_source(File::from(default_config_path));
        } else {
            tracing::warn!("未找到默认配置文件，使用内置默认值");
        }
        
        // 加载环境变量覆盖配置
        builder = builder.add_source(
            Environment::with_prefix("SM_NODE")
                .separator("__")
                .try_parsing(true),
        );
        
        let config = builder.build()?;
        let node_config = config.try_deserialize()?;
        
        Ok(node_config)
    }
    
    /// 获取配置目录
    fn get_config_dir() -> Result<PathBuf> {
        let mut config_dir = std::env::current_dir()?;
        config_dir.push("config");
        
        if !config_dir.exists() {
            std::fs::create_dir_all(&config_dir)?;
        }
        
        Ok(config_dir)
    }
    
    /// 获取有效的节点ID
    pub fn get_node_id(&self) -> String {
        self.core.node_id.clone().unwrap_or_else(|| {
            use sysinfo::System;
            let mut sys = System::new();
            sys.refresh_all(); // 刷新系统信息
            
            let hostname = System::host_name()
                .unwrap_or_else(|| "unknown".to_string())
                .trim()
                .to_string();
            
            // 如果主机名为空，使用默认值
            let valid_hostname = if hostname.is_empty() {
                "unknown-host".to_string()
            } else {
                hostname
            };
            
            format!("{}-{}", valid_hostname, uuid::Uuid::new_v4().to_string()[..8].to_string())
        })
    }
    
    /// 获取WebSocket连接URL
    pub fn get_websocket_url(&self, node_id: &str) -> String {
        let mut url = self.core.url.clone();
        
        // 添加查询参数
        let mut params = vec![
            format!("token={}", urlencoding::encode(&self.core.token)),
            format!("node_id={}", urlencoding::encode(node_id)),
        ];
        
        if url.contains('?') {
            url.push_str(&format!("&{}", params.join("&")));
        } else {
            url.push_str(&format!("?{}", params.join("&")));
        }
        
        url
    }
}

/// 默认配置
impl Default for NodeConfig {
    fn default() -> Self {
        Self {
            core: CoreConfig {
                url: "ws://0.0.0.0:9999/api/v1/ws".to_string(),
                token: "default-token".to_string(),
                node_id: None,
            },
            monitoring: MonitoringConfig {
                heartbeat_interval: 30,
                metrics_interval: 10,
                detailed_metrics: false,
            },
            system: SystemConfig {
                hostname: None,
                report_system_info: true,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                file_enabled: false,
                file_path: "logs/node.log".to_string(),
                console_enabled: true,
            },
            advanced: AdvancedConfig {
                reconnect_interval: 5,
                max_retries: 10,
                command_timeout: 30,
                metrics_retention_days: 7,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = NodeConfig::default();
        assert_eq!(config.core.url, "ws://0.0.0.0:9999/api/v1/ws");
        assert_eq!(config.core.token, "default-token");
        assert!(config.core.node_id.is_none());
        assert_eq!(config.monitoring.heartbeat_interval, 30);
        assert_eq!(config.monitoring.metrics_interval, 10);
    }

    #[test]
    fn test_get_node_id() {
        let config = NodeConfig::default();
        let node_id = config.get_node_id();
        assert!(!node_id.is_empty());
        assert!(node_id.contains('-'));
    }

    #[test]
    fn test_get_websocket_url() {
        let config = NodeConfig::default();
        let url = config.get_websocket_url("test-node");
        assert!(url.contains("token=default-token"));
        assert!(url.contains("node_id=test-node"));
        assert!(url.starts_with("ws://"));
    }
}
