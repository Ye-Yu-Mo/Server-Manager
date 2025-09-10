use anyhow::Result;
use sysinfo::System;
use tracing::{info, warn};
use tracing_subscriber;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    info!("🤖 Server Manager Node 启动中...");
    
    // TODO: 读取配置文件
    // TODO: 连接到Core服务
    // TODO: 节点注册
    
    warn!("⚠️  Node代理尚未完全实现，目前仅为骨架代码");
    
    // 模拟系统信息采集
    let mut sys = System::new_all();
    sys.refresh_all();
    
    info!("📊 系统信息采集测试:");
    info!("  - CPU核心数: {}", sys.cpus().len());
    info!("  - 总内存: {} MB", sys.total_memory() / 1024 / 1024);
    info!("  - 已用内存: {} MB", sys.used_memory() / 1024 / 1024);
    
    info!("✅ Node代理启动成功 (骨架版本)");
    
    // 模拟心跳循环
    let mut interval = tokio::time::interval(Duration::from_secs(30));
    loop {
        tokio::select! {
            _ = interval.tick() => {
                sys.refresh_cpu_all();
                sys.refresh_memory();
                
                let cpu_usage: f32 = sys.cpus().iter()
                    .map(|cpu| cpu.cpu_usage())
                    .sum::<f32>() / sys.cpus().len() as f32;
                
                let memory_usage = (sys.used_memory() as f64 / sys.total_memory() as f64) * 100.0;
                
                info!("💓 心跳 - CPU: {:.1}%, 内存: {:.1}%", cpu_usage, memory_usage);
            }
            _ = tokio::signal::ctrl_c() => {
                info!("👋 Node代理正在关闭...");
                break;
            }
        }
    }
    
    Ok(())
}