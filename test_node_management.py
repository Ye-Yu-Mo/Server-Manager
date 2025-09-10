#!/usr/bin/env python3
"""
节点连接管理功能测试脚本
用于测试新实现的节点连接管理功能
"""

import requests
import json
import time

BASE_URL = "http://localhost:9999/api/v1"

def test_health_check():
    """测试健康检查接口"""
    print("🧪 测试健康检查接口...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        data = response.json()
        print(f"✅ 健康检查响应: {data}")
        return data.get('success', False)
    except Exception as e:
        print(f"❌ 健康检查失败: {e}")
        return False

def test_get_nodes():
    """测试获取节点列表接口"""
    print("🧪 测试获取节点列表接口...")
    try:
        response = requests.get(f"{BASE_URL}/nodes")
        data = response.json()
        print(f"✅ 节点列表响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
        return data.get('success', False)
    except Exception as e:
        print(f"❌ 获取节点列表失败: {e}")
        return False

def test_get_node_stats():
    """测试获取节点统计信息接口"""
    print("🧪 测试获取节点统计信息接口...")
    try:
        response = requests.get(f"{BASE_URL}/nodes/stats")
        data = response.json()
        print(f"✅ 节点统计信息: {json.dumps(data, indent=2, ensure_ascii=False)}")
        return data.get('success', False)
    except Exception as e:
        print(f"❌ 获取节点统计信息失败: {e}")
        return False

def test_cleanup_stale_nodes():
    """测试清理过期节点接口"""
    print("🧪 测试清理过期节点接口...")
    try:
        response = requests.get(f"{BASE_URL}/nodes/cleanup")
        data = response.json()
        print(f"✅ 清理过期节点响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
        return data.get('success', False)
    except Exception as e:
        print(f"❌ 清理过期节点失败: {e}")
        return False

def main():
    """主测试函数"""
    print("🚀 开始节点连接管理功能测试")
    print("=" * 50)
    
    # 等待服务器启动
    print("⏳ 等待服务器启动...")
    time.sleep(2)
    
    tests = [
        test_health_check,
        test_get_nodes,
        test_get_node_stats,
        test_cleanup_stale_nodes,
    ]
    
    results = []
    for test in tests:
        result = test()
        results.append(result)
        print()
        time.sleep(1)
    
    # 输出测试结果
    print("=" * 50)
    print("📊 测试结果汇总:")
    passed = sum(results)
    total = len(results)
    print(f"✅ 通过: {passed}/{total}")
    print(f"❌ 失败: {total - passed}/{total}")
    
    if passed == total:
        print("🎉 所有测试通过！节点连接管理功能正常")
        return True
    else:
        print("⚠️  部分测试失败，请检查服务器状态")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
