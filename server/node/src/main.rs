use anyhow::Result;
use tracing::{error, info, warn};
use tracing_subscriber;
use std::time::Duration;

mod config;
mod monitor;
mod websocket;

use crate::config::NodeConfig;
use crate::monitor::{SystemMonitor, SystemMetrics};
use crate::websocket::WebSocketClient;

#[tokio::main]
async fn main() -> Result<()> {
    // 加载配置
    let config = match NodeConfig::load() {
        Ok(config) => config,
        Err(e) => {
            eprintln!("❌ 加载配置失败: {}", e);
            std::process::exit(1);
        }
    };

    // 初始化日志
    init_logging(&config)?;
    
    info!("🤖 Server Manager Node 启动中...");
    info!("📋 配置加载成功");
    
    // 获取节点ID
    let node_id = config.get_node_id();
    info!("🆔 节点ID: {}", node_id);
    
    // 创建监控采集器
    let mut monitor = SystemMonitor::new();
    
    // 显示系统信息
    let system_info = monitor.get_system_info();
    info!("💻 系统信息:");
    info!("  - 主机名: {}", system_info.hostname);
    info!("  - 操作系统: {} {}", system_info.os_name, system_info.os_version);
    info!("  - 内核版本: {}", system_info.kernel_version);
    info!("  - CPU: {} ({}核心)", system_info.cpu_name, system_info.cpu_count);
    info!("  - 总内存: {:.1} GB", system_info.total_memory as f64 / 1024.0 / 1024.0 / 1024.0);
    
    // 磁盘监控功能暂未实现
    info!("💾 磁盘监控: 功能开发中");
    
    // 测试监控数据采集
    info!("📊 测试监控数据采集...");
    let metrics = monitor.get_metrics();
    log_metrics(&metrics);
    
    info!("✅ Node代理启动成功");
    
    // 启动监控循环
    start_monitoring_loop(config, node_id, monitor).await?;
    
    Ok(())
}

/// 初始化日志系统
fn init_logging(config: &NodeConfig) -> Result<()> {
    let log_level = match config.logging.level.as_str() {
        "trace" => tracing::Level::TRACE,
        "debug" => tracing::Level::DEBUG,
        "info" => tracing::Level::INFO,
        "warn" => tracing::Level::WARN,
        "error" => tracing::Level::ERROR,
        _ => tracing::Level::INFO,
    };
    
    let subscriber = tracing_subscriber::fmt()
        .with_max_level(log_level)
        .with_target(false)
        .with_thread_ids(false)
        .with_thread_names(false);
    
    if config.logging.console_enabled {
        subscriber.init();
    }
    
    // TODO: 实现文件日志输出
    if config.logging.file_enabled {
        warn!("文件日志功能尚未实现");
    }
    
    Ok(())
}

/// 记录监控指标
fn log_metrics(metrics: &SystemMetrics) {
    info!("📈 监控指标:");
    info!("  - CPU使用率: {:.1}%", metrics.cpu_usage);
    info!("  - 内存使用率: {:.1}%", metrics.memory_usage);
    info!("  - 内存总量: {:.1} GB", metrics.memory_total as f64 / 1024.0 / 1024.0 / 1024.0);
    info!("  - 可用内存: {:.1} GB", metrics.memory_available as f64 / 1024.0 / 1024.0 / 1024.0);
    
    if let Some(disk_usage) = metrics.disk_usage {
        info!("  - 磁盘使用率: {:.1}%", disk_usage);
    }
    
    info!("  - 系统运行时间: {} 小时", metrics.uptime / 3600);
}

/// 启动监控循环（集成WebSocket功能）
async fn start_monitoring_loop(
    config: NodeConfig,
    node_id: String,
    mut monitor: SystemMonitor,
) -> Result<()> {
    let metrics_interval = Duration::from_secs(config.monitoring.metrics_interval);
    let heartbeat_interval = Duration::from_secs(config.monitoring.heartbeat_interval);
    let reconnect_interval = Duration::from_secs(config.advanced.reconnect_interval);
    
    info!("🔄 启动监控循环:");
    info!("  - 监控采集间隔: {}秒", config.monitoring.metrics_interval);
    info!("  - 心跳间隔: {}秒", config.monitoring.heartbeat_interval);
    info!("  - 重连间隔: {}秒", config.advanced.reconnect_interval);
    
    let mut metrics_interval = tokio::time::interval(metrics_interval);
    let mut heartbeat_interval = tokio::time::interval(heartbeat_interval);
    
    let mut metrics_count = 0;
    let mut retry_count = 0;
    let mut ws_client = WebSocketClient::new(config.clone(), node_id.clone());
    
    // 初始连接尝试
    if let Err(e) = ws_client.connect().await {
        error!("❌ 初始WebSocket连接失败: {}", e);
    } else {
        // 发送注册消息
        if let Err(e) = ws_client.send_register_message(&monitor).await {
            error!("❌ 发送注册消息失败: {}", e);
        }
    }
    
    loop {
        tokio::select! {
            _ = metrics_interval.tick() => {
                // 采集监控数据
                let metrics = monitor.get_metrics();
                metrics_count += 1;
                
                if metrics_count % 10 == 0 {
                    // 每10次采集记录一次详细日志
                    log_metrics(&metrics);
                } else {
                    // 简要日志
                    info!("📊 监控数据 - CPU: {:.1}%, 内存: {:.1}%", 
                        metrics.cpu_usage,
                        metrics.memory_usage
                    );
                }
                
                // 如果WebSocket连接正常，发送监控数据
                if ws_client.is_connected() {
                    if let Err(e) = ws_client.send_heartbeat(&metrics).await {
                        error!("❌ 发送监控数据失败: {}", e);
                        ws_client.close().await.ok();
                    }
                } else {
                    // 尝试重连
                    if retry_count < config.advanced.max_retries {
                        retry_count += 1;
                        info!("🔄 尝试重连 ({}/{})", retry_count, config.advanced.max_retries);
                        
                        if let Err(e) = ws_client.connect().await {
                            error!("❌ 重连失败: {}", e);
                            tokio::time::sleep(reconnect_interval).await;
                        } else {
                            retry_count = 0;
                            info!("✅ 重连成功");
                            
                            // 重新发送注册消息
                            if let Err(e) = ws_client.send_register_message(&monitor).await {
                                error!("❌ 重新发送注册消息失败: {}", e);
                            }
                        }
                    } else {
                        error!("❌ 达到最大重试次数，停止重连");
                    }
                }
            }
            
            _ = heartbeat_interval.tick() => {
                // 发送心跳信号
                info!("💓 心跳信号");
                
                // 如果WebSocket连接正常，处理服务器消息
                if ws_client.is_connected() {
                    match ws_client.receive_message().await {
                        Ok(Some(message)) => {
                            info!("📥 收到服务器消息: {}", message);
                        }
                        Ok(None) => {
                            info!("📭 连接已关闭");
                            ws_client.close().await.ok();
                        }
                        Err(e) => {
                            error!("❌ 接收消息错误: {}", e);
                        }
                    }
                }
            }
            
            _ = tokio::signal::ctrl_c() => {
                info!("👋 Node代理正在关闭...");
                // 关闭WebSocket连接
                ws_client.close().await.ok();
                break Ok(());
            }
        }
    }
}
