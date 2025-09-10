use anyhow::Result;
use sqlx::{SqlitePool, Row};
use tracing::info;

/// 数据库迁移版本管理
pub struct MigrationManager {
    pool: SqlitePool,
}

impl MigrationManager {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
    
    /// 获取当前数据库版本
    pub async fn get_current_version(&self) -> Result<i32> {
        // 创建版本表如果不存在
        sqlx::query(r#"
            CREATE TABLE IF NOT EXISTS schema_version (
                id INTEGER PRIMARY KEY,
                version INTEGER NOT NULL,
                applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        "#)
        .execute(&self.pool)
        .await?;
        
        // 获取最新版本
        let result = sqlx::query("SELECT MAX(version) as version FROM schema_version")
            .fetch_one(&self.pool)
            .await?;
            
        let version: Option<i32> = result.get("version");
        Ok(version.unwrap_or(0))
    }
    
    /// 应用迁移到指定版本
    pub async fn migrate_to_version(&self, target_version: i32) -> Result<()> {
        let current_version = self.get_current_version().await?;
        
        if current_version >= target_version {
            info!("数据库已是最新版本 v{}", current_version);
            return Ok(());
        }
        
        for version in (current_version + 1)..=target_version {
            info!("应用迁移 v{}", version);
            self.apply_migration(version).await?;
        }
        
        Ok(())
    }
    
    /// 应用单个迁移
    async fn apply_migration(&self, version: i32) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        
        match version {
            1 => {
                // v1: 基础表结构 (已在connection.rs中创建)
                info!("v1: 基础表结构已创建");
            }
            2 => {
                // v2: 添加节点标签字段 (示例未来迁移)
                sqlx::query("ALTER TABLE nodes ADD COLUMN tags TEXT")
                    .execute(&mut *tx)
                    .await?;
                info!("v2: 添加节点标签字段");
            }
            _ => {
                return Err(anyhow::anyhow!("未知的迁移版本: {}", version));
            }
        }
        
        // 记录迁移版本
        sqlx::query("INSERT INTO schema_version (version) VALUES (?)")
            .bind(version)
            .execute(&mut *tx)
            .await?;
            
        tx.commit().await?;
        Ok(())
    }
    
    /// 回滚到指定版本 (谨慎使用)
    pub async fn rollback_to_version(&self, target_version: i32) -> Result<()> {
        let current_version = self.get_current_version().await?;
        
        if current_version <= target_version {
            return Ok(());
        }
        
        // 这里只是示例，实际回滚需要更复杂的逻辑
        sqlx::query("DELETE FROM schema_version WHERE version > ?")
            .bind(target_version)
            .execute(&self.pool)
            .await?;
            
        info!("回滚到版本 v{}", target_version);
        Ok(())
    }
}