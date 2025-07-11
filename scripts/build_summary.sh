#!/bin/bash

# 构建摘要脚本
echo "=========================================="
echo "           Mindra 应用构建摘要"
echo "=========================================="
echo ""

# 检查构建文件
echo "📦 构建文件检查："
echo ""

# AAB文件
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    AAB_SIZE=$(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)
    echo "✅ Android App Bundle (AAB): $AAB_SIZE"
    echo "   📁 位置: build/app/outputs/bundle/release/app-release.aab"
    echo "   🎯 用途: Google Play Store 发布"
else
    echo "❌ Android App Bundle (AAB) 未找到"
fi

echo ""

# APK文件
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
    echo "✅ Android APK: $APK_SIZE"
    echo "   📁 位置: build/app/outputs/flutter-apk/app-release.apk"
    echo "   🎯 用途: 直接安装或其他应用商店"
else
    echo "❌ Android APK 未找到"
fi

echo ""
echo "=========================================="
echo "🔐 签名验证："
echo ""

# 验证APK签名
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "正在验证APK签名..."
    if jarsigner -verify build/app/outputs/flutter-apk/app-release.apk > /dev/null 2>&1; then
        echo "✅ APK签名验证成功"
    else
        echo "❌ APK签名验证失败"
    fi
else
    echo "⚠️  无法验证签名：APK文件不存在"
fi

echo ""
echo "=========================================="
echo "📋 应用信息："
echo ""

# 从pubspec.yaml读取版本信息
if [ -f "pubspec.yaml" ]; then
    VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2)
    echo "📱 应用名称: Mindra"
    echo "🔢 版本号: $VERSION"
    echo "🆔 应用ID: com.mindra.app"
    echo "📝 描述: 专业的冥想与正念应用，帮助您找到内心的平静与专注"
fi

echo ""
echo "=========================================="
echo "🚀 发布准备状态："
echo ""

READY_COUNT=0
TOTAL_COUNT=4

# 检查各项准备状态
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ AAB包已构建"
    ((READY_COUNT++))
else
    echo "❌ AAB包未构建"
fi

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "✅ APK包已构建"
    ((READY_COUNT++))
else
    echo "❌ APK包未构建"
fi

if [ -f "android/release-keystore.jks" ]; then
    echo "✅ 发布密钥库已创建"
    ((READY_COUNT++))
else
    echo "❌ 发布密钥库未创建"
fi

if [ -f "android/key.properties" ]; then
    echo "✅ 签名配置已设置"
    ((READY_COUNT++))
else
    echo "❌ 签名配置未设置"
fi

echo ""
echo "📊 准备进度: $READY_COUNT/$TOTAL_COUNT"

if [ $READY_COUNT -eq $TOTAL_COUNT ]; then
    echo "🎉 应用已准备好发布！"
else
    echo "⚠️  还有 $((TOTAL_COUNT - READY_COUNT)) 项需要完成"
fi

echo ""
echo "=========================================="
echo "📝 下一步操作："
echo ""
echo "1. 🔐 更新密钥库密码（如果使用演示密码）"
echo "2. 📱 在真实设备上测试APK"
echo "3. 🏪 上传AAB到Google Play Console"
echo "4. 📋 准备应用商店描述和截图"
echo "5. 🎯 设置应用商店元数据"
echo ""
echo "=========================================="
