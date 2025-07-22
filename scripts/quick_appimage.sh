#!/bin/bash

# 快速AppImage构建脚本 - 用于测试和快速部署
# 跳过测试和复杂验证，专注于AppImage创建

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "      Mindra AppImage 构建（唯一支持）"
echo "=========================================="
echo ""

# 检查是否在正确的目录
if [ ! -f "pubspec.yaml" ]; then
    log_error "请在Flutter项目根目录运行此脚本"
    exit 1
fi

# 1. 构建Linux应用
log_info "构建 Linux 应用..."
if flutter build linux --release; then
    log_success "Linux 应用构建完成"
else
    log_error "Linux 应用构建失败"
    exit 1
fi

# 2. 创建AppImage
log_info "创建 AppImage..."
if [ -f "scripts/create_appimage.sh" ]; then
    if ./scripts/create_appimage.sh; then
        log_success "AppImage 创建完成"
        
        # 显示结果
        echo ""
        log_info "构建结果:"
                 if ls build/linux/*.AppImage &>/dev/null; then
             for appimage in build/linux/*.AppImage; do
                 size=$(du -h "$appimage" | cut -f1)
                 echo "  📦 AppImage: $(basename "$appimage") ($size)"
             done
         fi
        
        echo ""
        log_info "测试运行:"
        echo "  ./build/linux/*.AppImage"
        
    else
        log_error "AppImage 创建失败"
        exit 1
    fi
else
    log_error "AppImage 创建脚本不存在: scripts/create_appimage.sh"
    exit 1
fi

echo ""
log_success "快速构建完成！" 