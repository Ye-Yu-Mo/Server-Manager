use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, SqlitePool};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Command {
    pub id: i64,
    pub command_id: String,
    pub command_text: String,
    pub target_node_id: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub started_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct CommandResult {
    pub id: i64,
    pub command_id: String,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
    pub exit_code: Option<i32>,
    pub execution_time_ms: Option<i64>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandCreate {
    pub command_id: String,
    pub command_text: String,
    pub target_node_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandResultCreate {
    pub command_id: String,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
    pub exit_code: Option<i32>,
    pub execution_time_ms: Option<i64>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandWithResult {
    pub command: Command,
    pub result: Option<CommandResult>,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum CommandStatus {
    Pending,
    Running,
    Success,
    Failed,
    Timeout,
}

impl ToString for CommandStatus {
    fn to_string(&self) -> String {
        match self {
            CommandStatus::Pending => "pending".to_string(),
            CommandStatus::Running => "running".to_string(),
            CommandStatus::Success => "success".to_string(),
            CommandStatus::Failed => "failed".to_string(),
            CommandStatus::Timeout => "timeout".to_string(),
        }
    }
}

impl Command {
    /// 创建新命令
    pub async fn create(pool: &SqlitePool, command_data: CommandCreate) -> Result<Command> {
        let command = sqlx::query_as::<_, Command>(r#"
            INSERT INTO commands (command_id, command_text, target_node_id)
            VALUES (?, ?, ?)
            RETURNING *
        "#)
        .bind(&command_data.command_id)
        .bind(&command_data.command_text)
        .bind(&command_data.target_node_id)
        .fetch_one(pool)
        .await?;
        
        Ok(command)
    }
    
    /// 根据command_id查找命令
    pub async fn find_by_id(pool: &SqlitePool, command_id: &str) -> Result<Option<Command>> {
        let command = sqlx::query_as::<_, Command>("SELECT * FROM commands WHERE command_id = ?")
            .bind(command_id)
            .fetch_optional(pool)
            .await?;
            
        Ok(command)
    }
    
    /// 获取待执行的命令
    pub async fn find_pending(pool: &SqlitePool, node_id: &str) -> Result<Vec<Command>> {
        let commands = sqlx::query_as::<_, Command>(
            "SELECT * FROM commands WHERE target_node_id = ? AND status = 'pending' ORDER BY created_at ASC"
        )
        .bind(node_id)
        .fetch_all(pool)
        .await?;
        
        Ok(commands)
    }
    
    /// 获取指定节点的命令历史
    pub async fn find_by_node(pool: &SqlitePool, node_id: &str, limit: Option<i64>) -> Result<Vec<Command>> {
        let mut sql = "SELECT * FROM commands WHERE target_node_id = ? ORDER BY created_at DESC".to_string();
        
        if limit.is_some() {
            sql.push_str(" LIMIT ?");
        }
        
        let mut query_builder = sqlx::query_as::<_, Command>(&sql).bind(node_id);
        
        if let Some(limit) = limit {
            query_builder = query_builder.bind(limit);
        }
        
        let commands = query_builder.fetch_all(pool).await?;
        Ok(commands)
    }
    
    /// 更新命令状态
    pub async fn update_status(
        pool: &SqlitePool, 
        command_id: &str, 
        status: CommandStatus
    ) -> Result<()> {
        let status_str = status.to_string();
        
        let sql = match status {
            CommandStatus::Running => {
                "UPDATE commands SET status = ?, started_at = CURRENT_TIMESTAMP WHERE command_id = ?"
            }
            CommandStatus::Success | CommandStatus::Failed | CommandStatus::Timeout => {
                "UPDATE commands SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE command_id = ?"
            }
            CommandStatus::Pending => {
                "UPDATE commands SET status = ? WHERE command_id = ?"
            }
        };
        
        sqlx::query(sql)
            .bind(status_str)
            .bind(command_id)
            .execute(pool)
            .await?;
        
        Ok(())
    }
    
    /// 获取所有命令 (分页)
    pub async fn find_all(pool: &SqlitePool, offset: i64, limit: i64) -> Result<Vec<Command>> {
        let commands = sqlx::query_as::<_, Command>(
            "SELECT * FROM commands ORDER BY created_at DESC LIMIT ? OFFSET ?"
        )
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await?;
        
        Ok(commands)
    }
    
    /// 删除命令
    pub async fn delete(pool: &SqlitePool, command_id: &str) -> Result<bool> {
        let result = sqlx::query("DELETE FROM commands WHERE command_id = ?")
            .bind(command_id)
            .execute(pool)
            .await?;
            
        Ok(result.rows_affected() > 0)
    }
    
    /// 清理过期命令
    pub async fn cleanup_old_commands(pool: &SqlitePool, days_to_keep: i64) -> Result<u64> {
        let result = sqlx::query(
            "DELETE FROM commands WHERE created_at < datetime('now', '-' || ? || ' days')"
        )
        .bind(days_to_keep)
        .execute(pool)
        .await?;
        
        Ok(result.rows_affected())
    }
}

impl CommandResult {
    /// 创建命令执行结果
    pub async fn create(pool: &SqlitePool, result_data: CommandResultCreate) -> Result<CommandResult> {
        let result = sqlx::query_as::<_, CommandResult>(r#"
            INSERT INTO command_results (command_id, stdout, stderr, exit_code, execution_time_ms)
            VALUES (?, ?, ?, ?, ?)
            RETURNING *
        "#)
        .bind(&result_data.command_id)
        .bind(&result_data.stdout)
        .bind(&result_data.stderr)
        .bind(result_data.exit_code)
        .bind(result_data.execution_time_ms)
        .fetch_one(pool)
        .await?;
        
        Ok(result)
    }
    
    /// 根据command_id查找执行结果
    pub async fn find_by_command_id(pool: &SqlitePool, command_id: &str) -> Result<Option<CommandResult>> {
        let result = sqlx::query_as::<_, CommandResult>("SELECT * FROM command_results WHERE command_id = ?")
            .bind(command_id)
            .fetch_optional(pool)
            .await?;
            
        Ok(result)
    }
    
    /// 获取命令和结果的组合信息
    pub async fn get_command_with_result(pool: &SqlitePool, command_id: &str) -> Result<Option<CommandWithResult>> {
        let command = Command::find_by_id(pool, command_id).await?;
        
        if let Some(cmd) = command {
            let result = Self::find_by_command_id(pool, command_id).await?;
            Ok(Some(CommandWithResult {
                command: cmd,
                result,
            }))
        } else {
            Ok(None)
        }
    }
    
    /// 获取节点的命令历史（包含结果）
    pub async fn get_node_command_history(pool: &SqlitePool, node_id: &str, limit: Option<i64>) -> Result<Vec<CommandWithResult>> {
        let commands = Command::find_by_node(pool, node_id, limit).await?;
        let mut results = Vec::new();
        
        for command in commands {
            let result = Self::find_by_command_id(pool, &command.command_id).await?;
            results.push(CommandWithResult {
                command,
                result,
            });
        }
        
        Ok(results)
    }
}