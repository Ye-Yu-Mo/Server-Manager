#!/bin/bash

# Server Manager Flutter客户端开发启动脚本

echo "🚀 启动 Server Manager Flutter 客户端开发环境"

# 检查Flutter是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter未安装，请先安装Flutter SDK"
    exit 1
fi

# 检查Dart是否安装
if ! command -v dart &> /dev/null; then
    echo "❌ Dart未安装，请先安装Dart SDK"
    exit 1
fi

echo "✅ Flutter版本: $(flutter --version | head -n 1)"
echo "✅ Dart版本: $(dart --version | head -n 1)"

# 检查依赖
echo "📦 检查依赖包..."
flutter pub get

# 运行应用
echo "🎯 启动Flutter开发服务器..."
echo "📱 应用将在 http://localhost:9988 可用 (Web版本)"
echo "📱 或使用 flutter run 启动移动端/桌面端"

# 提示用户选择运行方式
echo ""
echo "请选择运行方式:"
echo "1. Web浏览器 (推荐开发测试)"
echo "2. Android模拟器"
echo "3. iOS模拟器"
echo "4. 桌面端 (macOS/Windows/Linux)"
echo "5. 仅检查项目结构"

read -p "请输入选项 (1-5): " choice

case $choice in
    1)
        echo "🌐 启动Web开发服务器..."
        flutter run -d chrome --web-port=9988 --web-hostname=0.0.0.0
        ;;
    2)
        echo "🤖 启动Android模拟器..."
        # 检查是否有可用的Android设备
        if flutter devices | grep -q "android"; then
            flutter run -d android
        else
            echo "❌ 未找到Android设备，请先启动模拟器或连接设备"
        fi
        ;;
    3)
        echo "🍎 启动iOS模拟器..."
        # 检查是否有可用的iOS设备
        if flutter devices | grep -q "ios"; then
            flutter run -d ios
        else
            echo "❌ 未找到iOS模拟器，请先启动模拟器"
        fi
        ;;
    4)
        echo "💻 启动桌面端..."
        # 根据当前平台选择桌面端
        if [[ "$OSTYPE" == "darwin"* ]]; then
            flutter run -d macos
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            flutter run -d linux
        elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            flutter run -d windows
        else
            echo "❌ 不支持的平台: $OSTYPE"
        fi
        ;;
    5)
        echo "🔍 检查项目结构..."
        echo "📁 项目目录结构:"
        find lib -name "*.dart" | sort
        echo ""
        echo "📊 代码统计:"
        echo "模型文件: $(find lib/data/models -name "*.dart" | wc -l)"
        echo "服务文件: $(find lib/data/services -name "*.dart" | wc -l)"
        echo "页面文件: $(find lib/presentation/pages -name "*.dart" | wc -l)"
        echo "Provider文件: $(find lib/presentation/providers -name "*.dart" | wc -l)"
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

echo ""
echo "✅ 开发环境准备完成!"
echo "📚 相关文档:"
echo "   - docs/Flutter客户端MVP开发指南.md"
echo "   - docs/开发计划.md"
echo "   - docs/API设计.md"
