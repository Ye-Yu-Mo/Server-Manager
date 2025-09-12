use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::Row;
use tracing::{debug, error, info};

use crate::database::Database;
use crate::models::NodeMetric;
use crate::services::nodes::{AppState, NodeServiceResponse};

/// 监控数据查询参数
#[derive(Debug, Deserialize)]
pub struct MetricsQuery {
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 监控数据统计查询参数
#[derive(Debug, Deserialize)]
pub struct MetricsSummaryQuery {
    pub start_time: String,
    pub end_time: String,
}

/// 获取节点最新监控数据
pub async fn get_latest_metrics(
    State(state): State<Arc<AppState>>,
    Path(node_id): Path<String>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    match NodeMetric::find_latest_by_node_id(&db.pool, &node_id).await {
        Ok(Some(metric)) => {
            Json(NodeServiceResponse::success(metric, "获取最新监控数据成功"))
        }
        Ok(None) => {
            Json(NodeServiceResponse::error("该节点暂无监控数据"))
        }
        Err(e) => {
            error!("获取最新监控数据失败: {}", e);
            Json(NodeServiceResponse::error("获取监控数据失败"))
        }
    }
}

/// 获取节点监控历史数据
pub async fn get_node_metrics(
    State(state): State<Arc<AppState>>,
    Path(node_id): Path<String>,
    Query(query): Query<MetricsQuery>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    // 解析时间参数
    let start_time = query.start_time.as_ref()
        .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        .map(|dt| dt.with_timezone(&Utc));
    
    let end_time = query.end_time.as_ref()
        .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        .map(|dt| dt.with_timezone(&Utc));
    
    let limit = query.limit.unwrap_or(100);
    let offset = query.offset.unwrap_or(0);
    
    match NodeMetric::find_by_node_id_with_range(
        &db.pool, 
        &node_id, 
        start_time, 
        end_time, 
        limit, 
        offset
    ).await {
        Ok((metrics, total)) => {
            let response_data = json!({
                "metrics": metrics,
                "total": total,
                "limit": limit,
                "offset": offset
            });
            
            Json(NodeServiceResponse::success(response_data, "获取监控历史数据成功"))
        }
        Err(e) => {
            error!("获取监控历史数据失败: {}", e);
            Json(NodeServiceResponse::error("获取监控数据失败"))
        }
    }
}

/// 获取所有节点最新监控数据
pub async fn get_all_latest_metrics(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    match NodeMetric::find_all_latest(&db.pool).await {
        Ok(metrics) => {
            let response_data = json!({
                "metrics": metrics
            });
            Json(NodeServiceResponse::success(response_data, "获取所有节点最新监控数据成功"))
        }
        Err(e) => {
            error!("获取所有节点最新监控数据失败: {}", e);
            Json(NodeServiceResponse::error("获取监控数据失败"))
        }
    }
}

/// 获取监控数据统计摘要
pub async fn get_metrics_summary(
    State(state): State<Arc<AppState>>,
    Path(node_id): Path<String>,
    Query(query): Query<MetricsSummaryQuery>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    // 解析时间参数
    let start_time = match DateTime::parse_from_rfc3339(&query.start_time) {
        Ok(dt) => dt.with_timezone(&Utc),
        Err(e) => {
            error!("解析开始时间失败: {}", e);
            return Json(NodeServiceResponse::error("开始时间格式错误，请使用RFC 3339格式"));
        }
    };
    
    let end_time = match DateTime::parse_from_rfc3339(&query.end_time) {
        Ok(dt) => dt.with_timezone(&Utc),
        Err(e) => {
            error!("解析结束时间失败: {}", e);
            return Json(NodeServiceResponse::error("结束时间格式错误，请使用RFC 3339格式"));
        }
    };
    
    if start_time >= end_time {
        return Json(NodeServiceResponse::error("开始时间必须早于结束时间"));
    }
    
    match NodeMetric::get_summary(&db.pool, &node_id, start_time, end_time).await {
        Ok(summary) => {
            Json(NodeServiceResponse::success(summary, "获取监控数据统计摘要成功"))
        }
        Err(e) => {
            error!("获取监控数据统计摘要失败: {}", e);
            Json(NodeServiceResponse::error("获取统计摘要失败"))
        }
    }
}

/// 获取系统监控统计信息
pub async fn get_system_metrics_stats(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let db = state.database.lock().await;
    
    // 获取总监控数据数量
    let total_metrics: i64 = match sqlx::query("SELECT COUNT(*) as count FROM node_metrics")
        .fetch_one(&db.pool)
        .await
    {
        Ok(row) => row.get("count"),
        Err(e) => {
            error!("获取总监控数据数量失败: {}", e);
            return Json(NodeServiceResponse::error("获取统计信息失败"));
        }
    };
    
    // 获取最近24小时的数据量
    let last_24h_count: i64 = match sqlx::query(
        "SELECT COUNT(*) as count FROM node_metrics WHERE created_at > datetime('now', '-1 day')"
    )
        .fetch_one(&db.pool)
        .await
    {
        Ok(row) => row.get("count"),
        Err(e) => {
            error!("获取最近24小时数据量失败: {}", e);
            return Json(NodeServiceResponse::error("获取统计信息失败"));
        }
    };
    
    // 获取最早和最晚的数据时间
    let time_range = match sqlx::query(
        "SELECT MIN(created_at) as min_time, MAX(created_at) as max_time FROM node_metrics"
    )
        .fetch_one(&db.pool)
        .await
    {
        Ok(row) => {
            let min_time: Option<String> = row.get("min_time");
            let max_time: Option<String> = row.get("max_time");
            (min_time, max_time)
        }
        Err(e) => {
            error!("获取数据时间范围失败: {}", e);
            (None, None)
        }
    };
    
    let stats = json!({
        "total_metrics": total_metrics,
        "last_24h_count": last_24h_count,
        "earliest_metric_time": time_range.0,
        "latest_metric_time": time_range.1,
        "metrics_per_hour": if last_24h_count > 0 {
            last_24h_count as f64 / 24.0
        } else {
            0.0
        }
    });
    
    Json(NodeServiceResponse::success(stats, "获取系统监控统计信息成功"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;
    use std::sync::Arc;

    #[tokio::test]
    async fn test_metrics_query_validation() {
        // 测试有效的时间格式
        let valid_query = MetricsQuery {
            start_time: Some("2025-01-21T10:00:00Z".to_string()),
            end_time: Some("2025-01-21T11:00:00Z".to_string()),
            limit: Some(100),
            offset: Some(0),
        };
        
        assert!(valid_query.start_time.is_some());
        assert!(valid_query.end_time.is_some());
        
        // 测试无效的时间格式
        let invalid_query = MetricsQuery {
            start_time: Some("invalid-date".to_string()),
            end_time: Some("2025-01-21T11:00:00Z".to_string()),
            limit: Some(100),
            offset: Some(0),
        };
        
        // 验证时间解析会失败
        let parsed_time = invalid_query.start_time.as_ref()
            .and_then(|s| DateTime::parse_from_rfc3339(s).ok());
        assert!(parsed_time.is_none());
    }

    #[tokio::test]
    async fn test_metrics_summary_query_validation() {
        // 测试有效的时间范围
        let valid_query = MetricsSummaryQuery {
            start_time: "2025-01-21T10:00:00Z".to_string(),
            end_time: "2025-01-21T11:00:00Z".to_string(),
        };
        
        let start_time = DateTime::parse_from_rfc3339(&valid_query.start_time).unwrap();
        let end_time = DateTime::parse_from_rfc3339(&valid_query.end_time).unwrap();
        
        assert!(start_time < end_time);
        
        // 测试无效的时间范围（开始时间晚于结束时间）
        let invalid_query = MetricsSummaryQuery {
            start_time: "2025-01-21T11:00:00Z".to_string(),
            end_time: "2025-01-21T10:00:00Z".to_string(),
        };
        
        let start_time = DateTime::parse_from_rfc3339(&invalid_query.start_time).unwrap();
        let end_time = DateTime::parse_from_rfc3339(&invalid_query.end_time).unwrap();
        
        assert!(start_time > end_time);
    }
}
