use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, SqlitePool};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct NodeMetric {
    pub id: i64,
    pub node_id: String,
    pub metric_time: DateTime<Utc>,
    pub cpu_usage: Option<f64>,
    pub memory_usage: Option<f64>,
    pub disk_usage: Option<f64>,
    pub load_average: Option<f64>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MetricCreate {
    pub node_id: String,
    pub cpu_usage: Option<f64>,
    pub memory_usage: Option<f64>,
    pub disk_usage: Option<f64>,
    pub load_average: Option<f64>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MetricQuery {
    pub node_id: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct MetricSummary {
    pub node_id: String,
    pub avg_cpu_usage: Option<f64>,
    pub max_cpu_usage: Option<f64>,
    pub avg_memory_usage: Option<f64>,
    pub max_memory_usage: Option<f64>,
    pub avg_disk_usage: Option<f64>,
    pub max_disk_usage: Option<f64>,
    pub avg_load_average: Option<f64>,
    pub max_load_average: Option<f64>,
    pub sample_count: i64,
}

impl NodeMetric {
    /// 创建新的监控记录
    pub async fn create(pool: &SqlitePool, metric_data: MetricCreate) -> Result<NodeMetric> {
        let metric = sqlx::query_as::<_, NodeMetric>(r#"
            INSERT INTO node_metrics (node_id, metric_time, cpu_usage, memory_usage, disk_usage, load_average)
            VALUES (?, CURRENT_TIMESTAMP, ?, ?, ?, ?)
            RETURNING *
        "#)
        .bind(&metric_data.node_id)
        .bind(metric_data.cpu_usage)
        .bind(metric_data.memory_usage)
        .bind(metric_data.disk_usage)
        .bind(metric_data.load_average)
        .fetch_one(pool)
        .await?;
        
        Ok(metric)
    }
    
    /// 批量创建监控记录
    pub async fn create_batch(pool: &SqlitePool, metrics: Vec<MetricCreate>) -> Result<()> {
        let mut tx = pool.begin().await?;
        
        for metric_data in metrics {
            sqlx::query(r#"
                INSERT INTO node_metrics (node_id, metric_time, cpu_usage, memory_usage, disk_usage, load_average)
                VALUES (?, CURRENT_TIMESTAMP, ?, ?, ?, ?)
            "#)
            .bind(&metric_data.node_id)
            .bind(metric_data.cpu_usage)
            .bind(metric_data.memory_usage)
            .bind(metric_data.disk_usage)
            .bind(metric_data.load_average)
            .execute(&mut *tx)
            .await?;
        }
        
        tx.commit().await?;
        Ok(())
    }
    
    /// 查询监控数据
    pub async fn find_by_query(pool: &SqlitePool, query: MetricQuery) -> Result<Vec<NodeMetric>> {
        let mut sql = String::from("SELECT * FROM node_metrics WHERE 1=1");
        let mut conditions = Vec::new();
        
        if query.node_id.is_some() {
            sql.push_str(" AND node_id = ?");
            conditions.push("node_id");
        }
        
        if query.start_time.is_some() {
            sql.push_str(" AND metric_time >= ?");
            conditions.push("start_time");
        }
        
        if query.end_time.is_some() {
            sql.push_str(" AND metric_time <= ?");
            conditions.push("end_time");
        }
        
        sql.push_str(" ORDER BY metric_time DESC");
        
        if query.limit.is_some() {
            sql.push_str(" LIMIT ?");
            conditions.push("limit");
        }
        
        let mut query_builder = sqlx::query_as::<_, NodeMetric>(&sql);
        
        if let Some(ref node_id) = query.node_id {
            query_builder = query_builder.bind(node_id);
        }
        
        if let Some(start_time) = query.start_time {
            query_builder = query_builder.bind(start_time);
        }
        
        if let Some(end_time) = query.end_time {
            query_builder = query_builder.bind(end_time);
        }
        
        if let Some(limit) = query.limit {
            query_builder = query_builder.bind(limit);
        }
        
        let metrics = query_builder.fetch_all(pool).await?;
        Ok(metrics)
    }
    
    /// 获取节点最新监控数据
    pub async fn get_latest_by_node(pool: &SqlitePool, node_id: &str) -> Result<Option<NodeMetric>> {
        let metric = sqlx::query_as::<_, NodeMetric>(
            "SELECT * FROM node_metrics WHERE node_id = ? ORDER BY metric_time DESC LIMIT 1"
        )
        .bind(node_id)
        .fetch_optional(pool)
        .await?;
        
        Ok(metric)
    }
    
    /// 获取所有节点的最新监控数据
    pub async fn get_latest_all_nodes(pool: &SqlitePool) -> Result<Vec<NodeMetric>> {
        let metrics = sqlx::query_as::<_, NodeMetric>(r#"
            SELECT nm1.* FROM node_metrics nm1
            INNER JOIN (
                SELECT node_id, MAX(metric_time) as max_time
                FROM node_metrics
                GROUP BY node_id
            ) nm2 ON nm1.node_id = nm2.node_id AND nm1.metric_time = nm2.max_time
            ORDER BY nm1.metric_time DESC
        "#)
        .fetch_all(pool)
        .await?;
        
        Ok(metrics)
    }
    
    /// 获取监控数据统计摘要
    pub async fn get_summary(
        pool: &SqlitePool, 
        node_id: &str, 
        start_time: DateTime<Utc>, 
        end_time: DateTime<Utc>
    ) -> Result<Option<MetricSummary>> {
        let summary = sqlx::query_as::<_, MetricSummary>(r#"
            SELECT 
                node_id,
                AVG(cpu_usage) as avg_cpu_usage,
                MAX(cpu_usage) as max_cpu_usage,
                AVG(memory_usage) as avg_memory_usage,
                MAX(memory_usage) as max_memory_usage,
                AVG(disk_usage) as avg_disk_usage,
                MAX(disk_usage) as max_disk_usage,
                AVG(load_average) as avg_load_average,
                MAX(load_average) as max_load_average,
                COUNT(*) as sample_count
            FROM node_metrics
            WHERE node_id = ? AND metric_time BETWEEN ? AND ?
            GROUP BY node_id
        "#)
        .bind(node_id)
        .bind(start_time)
        .bind(end_time)
        .fetch_optional(pool)
        .await?;
        
        Ok(summary)
    }
    
    /// 清理过期监控数据
    pub async fn cleanup_old_metrics(pool: &SqlitePool, days_to_keep: i64) -> Result<u64> {
        let result = sqlx::query(
            "DELETE FROM node_metrics WHERE metric_time < datetime('now', '-' || ? || ' days')"
        )
        .bind(days_to_keep)
        .execute(pool)
        .await?;
        
        Ok(result.rows_affected())
    }
}