use anyhow::Result;
use sqlx::{sqlite::SqliteConnectOptions, SqlitePool, Row};
use std::str::FromStr;
use tracing::{info, error};

pub struct Database {
    pub pool: SqlitePool,
}


pub async fn initialize_database() -> Result<Database> {
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "sqlite:./data/server_manager.db".to_string());
    
    // 确保数据目录存在
    if let Some(parent) = std::path::Path::new(&database_url.replace("sqlite:", "")).parent() {
        std::fs::create_dir_all(parent)?;
    }
    
    let database = Database::new(&database_url).await?;
    
    // 验证数据库连接
    database.health_check().await?;
    
    Ok(database)
}

impl Database {
    /// 初始化数据库连接池
    pub async fn new(database_url: &str) -> Result<Self> {
        info!("正在连接数据库: {}", database_url);
        
        // 配置SQLite连接选项
        let options = SqliteConnectOptions::from_str(database_url)?
            .create_if_missing(true)
            .pragma("journal_mode", "WAL")  // 启用WAL模式提高并发性能
            .pragma("synchronous", "NORMAL")  // 平衡安全性和性能
            .pragma("foreign_keys", "ON");    // 启用外键约束
        
        // 创建连接池
        let pool = SqlitePool::connect_with(options).await?;
        
        let db = Database { pool };
        
        // 运行数据库迁移
        db.migrate().await?;
        
        info!("✅ 数据库连接成功建立");
        Ok(db)
    }
    
    /// 运行数据库迁移
    pub async fn migrate(&self) -> Result<()> {
        info!("正在执行数据库迁移...");
        
        // 检查是否已经初始化
        let table_count: i64 = sqlx::query("SELECT COUNT(*) as count FROM sqlite_master WHERE type='table'")
            .fetch_one(&self.pool)
            .await?
            .get("count");
            
        if table_count > 0 {
            info!("数据库已存在表结构，跳过迁移");
            return Ok(());
        }
        
        // 创建nodes表
        sqlx::query(r#"
            CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                node_id TEXT UNIQUE NOT NULL,
                hostname TEXT NOT NULL,
                ip_address TEXT NOT NULL,
                os_info TEXT,
                status TEXT DEFAULT 'offline',
                last_heartbeat DATETIME,
                registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        "#)
        .execute(&self.pool)
        .await?;
        
        // 创建node_metrics表
        sqlx::query(r#"
            CREATE TABLE IF NOT EXISTS node_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                node_id TEXT NOT NULL,
                metric_time DATETIME NOT NULL,
                cpu_usage REAL,
                memory_usage REAL,
                disk_usage REAL,
                load_average REAL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (node_id) REFERENCES nodes(node_id) ON DELETE CASCADE
            )
        "#)
        .execute(&self.pool)
        .await?;
        
        // 创建commands表  
        sqlx::query(r#"
            CREATE TABLE IF NOT EXISTS commands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                command_id TEXT UNIQUE NOT NULL,
                command_text TEXT NOT NULL,
                target_node_id TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                started_at DATETIME,
                completed_at DATETIME,
                FOREIGN KEY (target_node_id) REFERENCES nodes(node_id) ON DELETE CASCADE
            )
        "#)
        .execute(&self.pool)
        .await?;
        
        // 创建command_results表
        sqlx::query(r#"
            CREATE TABLE IF NOT EXISTS command_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                command_id TEXT NOT NULL,
                stdout TEXT,
                stderr TEXT,
                exit_code INTEGER,
                execution_time_ms INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (command_id) REFERENCES commands(command_id) ON DELETE CASCADE
            )
        "#)
        .execute(&self.pool)
        .await?;
        
        // 创建索引提高查询性能
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_node_metrics_time ON node_metrics(node_id, metric_time)")
            .execute(&self.pool)
            .await?;
            
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_commands_status ON commands(status, created_at)")
            .execute(&self.pool)
            .await?;
        
        info!("✅ 数据库迁移完成");
        Ok(())
    }
    
    /// 检查数据库连接状态
    pub async fn health_check(&self) -> Result<()> {
        sqlx::query("SELECT 1")
            .fetch_one(&self.pool)
            .await?;
        Ok(())
    }
    
    /// 获取数据库统计信息
    pub async fn get_stats(&self) -> Result<DatabaseStats> {
        let nodes_count: i64 = sqlx::query("SELECT COUNT(*) as count FROM nodes")
            .fetch_one(&self.pool)
            .await?
            .get("count");
            
        let online_nodes_count: i64 = sqlx::query("SELECT COUNT(*) as count FROM nodes WHERE status = 'online'")
            .fetch_one(&self.pool)
            .await?
            .get("count");
            
        let total_commands: i64 = sqlx::query("SELECT COUNT(*) as count FROM commands")
            .fetch_one(&self.pool)
            .await?
            .get("count");
        
        Ok(DatabaseStats {
            total_nodes: nodes_count,
            online_nodes: online_nodes_count,
            total_commands,
        })
    }
}

#[derive(Debug)]
pub struct DatabaseStats {
    pub total_nodes: i64,
    pub online_nodes: i64,
    pub total_commands: i64,
}