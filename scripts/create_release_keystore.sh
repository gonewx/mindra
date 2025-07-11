#!/bin/bash

# 创建Android发布密钥库的脚本
# 请在运行前确保已安装Java JDK

echo "创建Android发布密钥库..."
echo "请注意：密钥库密码和密钥密码请妥善保管，丢失后无法恢复！"
echo ""

# 检查是否已存在密钥库
if [ -f "../android/release-keystore.jks" ]; then
    echo "警告：发布密钥库已存在！"
    read -p "是否要覆盖现有密钥库？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消。"
        exit 1
    fi
fi

# 生成密钥库
keytool -genkey -v -keystore ../android/release-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias mindra-release-key \
    -dname "CN=Mindra, OU=Development, O=Mindra, L=City, S=State, C=CN"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 密钥库创建成功！"
    echo "📁 位置：../android/release-keystore.jks"
    echo ""
    echo "⚠️  重要提醒："
    echo "1. 请将密钥库文件备份到安全位置"
    echo "2. 请更新 android/key.properties 文件中的密码信息"
    echo "3. 密钥库密码和密钥密码必须妥善保管"
    echo "4. 发布到Google Play后，密钥库不能更改"
else
    echo "❌ 密钥库创建失败！"
    exit 1
fi
