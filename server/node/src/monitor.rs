use serde::Serialize;
use sysinfo::{System, Disks};

/// 系统监控数据
#[derive(Debug, Serialize, Clone)]
pub struct SystemMetrics {
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub memory_total: u64,
    pub memory_available: u64,
    pub disk_usage: Option<f64>,
    pub disk_total: Option<u64>,
    pub disk_available: Option<u64>,
    pub uptime: u64,
}

/// 系统信息
#[derive(Debug, Serialize, Clone)]
pub struct SystemInfo {
    pub hostname: String,
    pub os_name: String,
    pub os_version: String,
    pub kernel_version: String,
    pub cpu_count: usize,
    pub cpu_name: String,
    pub total_memory: u64,
}

/// 磁盘信息
#[derive(Debug, Serialize, Clone)]
pub struct DiskInfo {
    pub name: String,
    pub mount_point: String,
    pub total_space: u64,
    pub available_space: u64,
    pub file_system: String,
}

/// 监控采集器
pub struct SystemMonitor {
    sys: System,
    disks: Disks,
}

impl SystemMonitor {
    /// 创建新的监控采集器
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        let disks = Disks::new_with_refreshed_list();
        
        Self { sys, disks }
    }
    
    /// 刷新系统信息
    pub fn refresh(&mut self) {
        self.sys.refresh_cpu_all();
        self.sys.refresh_memory();
        self.disks.refresh(true);
    }
    
    /// 获取系统信息
    pub fn get_system_info(&self) -> SystemInfo {
        SystemInfo {
            hostname: System::host_name().unwrap_or_else(|| "unknown".to_string()),
            os_name: System::name().unwrap_or_else(|| "unknown".to_string()),
            os_version: System::os_version().unwrap_or_else(|| "unknown".to_string()),
            kernel_version: System::kernel_version().unwrap_or_else(|| "unknown".to_string()),
            cpu_count: self.sys.cpus().len(),
            cpu_name: if let Some(cpu) = self.sys.cpus().first() {
                cpu.brand().to_string()
            } else {
                "unknown".to_string()
            },
            total_memory: self.sys.total_memory(),
        }
    }
    
    /// 获取监控指标
    pub fn get_metrics(&mut self) -> SystemMetrics {
        self.refresh();
        
        // CPU使用率
        let cpu_usage = self.calculate_cpu_usage();
        
        // 内存使用率
        let memory_usage = self.calculate_memory_usage();
        
        // 磁盘使用率（使用根分区）
        let disk_usage = self.calculate_disk_usage();
        
        SystemMetrics {
            cpu_usage,
            memory_usage,
            memory_total: self.sys.total_memory(),
            memory_available: self.calculate_available_memory(),
            disk_usage: disk_usage.map(|(usage, _, _)| usage),
            disk_total: disk_usage.map(|(_, total, _)| total),
            disk_available: disk_usage.map(|(_, _, available)| available),
            uptime: System::uptime(),
        }
    }
    
    /// 计算CPU使用率
    fn calculate_cpu_usage(&self) -> f64 {
        let cpus = self.sys.cpus();
        if cpus.is_empty() {
            return 0.0;
        }
        
        let total_usage: f32 = cpus.iter().map(|cpu| cpu.cpu_usage()).sum();
        (total_usage / cpus.len() as f32) as f64
    }
    
    /// 计算内存使用率
    fn calculate_memory_usage(&self) -> f64 {
        let total_memory = self.sys.total_memory() as f64;
        if total_memory == 0.0 {
            return 0.0;
        }
        
        (self.sys.used_memory() as f64 / total_memory) * 100.0
    }
    
    /// 计算可用内存
    fn calculate_available_memory(&self) -> u64 {
        let available = self.sys.available_memory();
        if available > 0 {
            available
        } else {
            // 如果 available_memory() 返回0，则用 total - used 计算
            let total = self.sys.total_memory();
            let used = self.sys.used_memory();
            if total > used {
                total - used
            } else {
                0
            }
        }
    }
    
    /// 计算磁盘使用率（返回根分区）
    fn calculate_disk_usage(&self) -> Option<(f64, u64, u64)> {
        // 获取磁盘信息
        for disk in &self.disks {
            let mount_point = disk.mount_point().to_string_lossy();
            
            // 查找根分区或主要分区
            if mount_point == "/" || mount_point == "C:\\" || mount_point.starts_with("/System/Volumes/Data") {
                let total_space = disk.total_space();
                let available_space = disk.available_space();
                
                if total_space > 0 {
                    let used_space = total_space - available_space;
                    let usage_percentage = (used_space as f64 / total_space as f64) * 100.0;
                    
                    return Some((usage_percentage, total_space, available_space));
                }
            }
        }
        
        None
    }
    
    /// 获取所有磁盘信息
    pub fn get_all_disks(&self) -> Vec<DiskInfo> {
        self.disks.iter().map(|disk| {
            DiskInfo {
                name: disk.name().to_string_lossy().to_string(),
                mount_point: disk.mount_point().to_string_lossy().to_string(),
                total_space: disk.total_space(),
                available_space: disk.available_space(),
                file_system: disk.file_system().to_string_lossy().to_string(),
            }
        }).collect()
    }
}

impl Default for SystemMonitor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_monitor_creation() {
        let monitor = SystemMonitor::new();
        assert!(monitor.sys.cpus().len() > 0);
    }

    #[test]
    fn test_system_info() {
        let monitor = SystemMonitor::new();
        let info = monitor.get_system_info();
        
        assert!(!info.hostname.is_empty());
        assert!(info.cpu_count > 0);
        assert!(info.total_memory > 0);
    }

    #[test]
    fn test_metrics_collection() {
        let mut monitor = SystemMonitor::new();
        let metrics = monitor.get_metrics();
        
        // 基本指标应该都有值
        assert!(metrics.cpu_usage >= 0.0 && metrics.cpu_usage <= 100.0);
        assert!(metrics.memory_usage >= 0.0 && metrics.memory_usage <= 100.0);
        assert!(metrics.memory_total > 0);
    }
}
