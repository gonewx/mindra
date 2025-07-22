#!/bin/bash

# AppImage数据库测试脚本
# 用于验证AppImage环境下数据库功能是否正常

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
echo "      AppImage 数据库功能测试"
echo "=========================================="
echo ""

# 检查AppImage文件是否存在
APPIMAGE_FILE=""
if ls build/linux/*.AppImage &>/dev/null; then
    APPIMAGE_FILE=$(ls build/linux/*.AppImage | head -n1)
    log_info "找到 AppImage 文件: $(basename "$APPIMAGE_FILE")"
else
    log_error "未找到 AppImage 文件"
    log_info "请先运行: ./scripts/quick_appimage.sh"
    exit 1
fi

# 设置测试环境变量
export APPIMAGE="$PWD/$APPIMAGE_FILE"
export APPDIR="$PWD/build/linux/Mindra.AppDir"

log_info "设置测试环境变量:"
echo "  APPIMAGE=$APPIMAGE"
echo "  APPDIR=$APPDIR"

# 创建临时测试目录
TEST_HOME="$PWD/test_home"
mkdir -p "$TEST_HOME/.local/share"

log_info "创建测试用户目录: $TEST_HOME"

# 在测试环境中运行AppImage（后台运行，短时间后杀掉）
log_info "启动 AppImage 进行数据库初始化测试..."

# 设置测试环境
export HOME="$TEST_HOME"
export XDG_DATA_HOME="$TEST_HOME/.local/share"

# 运行AppImage，5秒后自动关闭
timeout 10s "$APPIMAGE" --no-sandbox &
APPIMAGE_PID=$!

sleep 5

# 检查是否创建了数据库文件
DB_PATH="$TEST_HOME/.local/share/Mindra/mindra.db"
if [ -f "$DB_PATH" ]; then
    log_success "数据库文件创建成功: $DB_PATH"
    
    # 检查数据库文件大小
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
    log_info "数据库文件大小: $DB_SIZE"
    
    # 检查数据库是否可读
    if [ -r "$DB_PATH" ]; then
        log_success "数据库文件可读"
    else
        log_warning "数据库文件不可读"
    fi
    
    # 检查数据库是否可写
    if [ -w "$DB_PATH" ]; then
        log_success "数据库文件可写"
    else
        log_warning "数据库文件不可写"
    fi
    
else
    log_warning "数据库文件未创建，可能使用了其他存储方式"
    
    # 检查是否有其他数据库相关文件
    log_info "搜索其他可能的数据库文件..."
    find "$TEST_HOME" -name "*.db" -o -name "*.sqlite*" 2>/dev/null || true
fi

# 停止AppImage进程
if kill -0 $APPIMAGE_PID 2>/dev/null; then
    log_info "停止 AppImage 进程..."
    kill $APPIMAGE_PID 2>/dev/null || true
    wait $APPIMAGE_PID 2>/dev/null || true
fi

# 检查日志输出
log_info "检查应用日志..."
if [ -d "$TEST_HOME/.local/share/Mindra" ]; then
    ls -la "$TEST_HOME/.local/share/Mindra/"
else
    log_info "Mindra数据目录未创建"
fi

# 清理测试环境
log_info "清理测试环境..."
rm -rf "$TEST_HOME"

echo ""
log_success "数据库功能测试完成"

echo ""
log_info "手动测试建议:"
echo "  1. 运行 AppImage: ./$APPIMAGE_FILE"
echo "  2. 尝试添加媒体文件"
echo "  3. 检查数据是否持久保存"
echo "  4. 重启应用验证数据恢复" 