#!/bin/bash

# 独立的AppImage创建脚本
# 用于从已构建的Linux应用创建AppImage

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

# 默认参数
BUILD_TYPE="release"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "AppImage 创建脚本"
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -h, --help              显示帮助信息"
            echo "  -d, --debug             使用Debug构建"
            echo "  -r, --release           使用Release构建 (默认)"
            exit 0
            ;;
        -d|--debug)
            BUILD_TYPE="debug"
            shift
            ;;
        -r|--release)
            BUILD_TYPE="release"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 创建AppImage
create_appimage() {
    log_info "创建 AppImage..."
    
    # 检查 appimagetool
    if ! command -v appimagetool &> /dev/null; then
        log_error "appimagetool 未安装"
        log_info "安装方法:"
        log_info "  wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool"
        log_info "  chmod +x /tmp/appimagetool"
        log_info "  sudo mv /tmp/appimagetool /usr/local/bin/appimagetool"
        exit 1
    fi
    
    local build_dir="build/linux/x64/$BUILD_TYPE/bundle"
    local appdir="build/linux/Mindra.AppDir"
    local app_version=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
    
    # 检查构建目录
    if [ ! -d "$build_dir" ]; then
        log_error "构建目录不存在: $build_dir"
        log_info "请先运行: flutter build linux --$BUILD_TYPE"
        exit 1
    fi
    
    # 创建 AppDir 结构
    log_info "创建 AppDir 结构..."
    rm -rf "$appdir"
    mkdir -p "$appdir"/{usr/bin,usr/lib,usr/share/applications,usr/share/pixmaps}
    
    # 复制应用文件
    log_info "复制应用文件..."
    cp -r "$build_dir"/* "$appdir/usr/lib/"
    
    # 创建启动脚本
    log_info "创建启动脚本..."
    cat > "$appdir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"
cd "$HERE/usr/lib"
exec ./mindra "$@"
EOF
    chmod +x "$appdir/AppRun"
    
    # 创建 .desktop 文件
    log_info "创建 .desktop 文件..."
    cat > "$appdir/mindra.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Mindra
Comment=专业的冥想与正念应用
Comment[en]=Professional meditation and mindfulness app
Exec=mindra
Icon=mindra
Categories=AudioVideo;Audio;Player;
Keywords=meditation;mindfulness;relaxation;wellness;
StartupNotify=true
StartupWMClass=mindra
MimeType=audio/mpeg;audio/wav;audio/flac;video/mp4;
EOF
    
    # 复制desktop文件到应用目录
    cp "$appdir/mindra.desktop" "$appdir/usr/share/applications/"
    
    # 复制图标文件
    log_info "复制图标文件..."
    if [ -f "$build_dir/data/flutter_assets/assets/images/app_icon_512.png" ]; then
        cp "$build_dir/data/flutter_assets/assets/images/app_icon_512.png" "$appdir/mindra.png"
        cp "$build_dir/data/flutter_assets/assets/images/app_icon_512.png" "$appdir/usr/share/pixmaps/mindra.png"
        log_success "使用 512x512 图标"
    elif [ -f "$build_dir/data/flutter_assets/assets/images/app_icon_1024.png" ]; then
        cp "$build_dir/data/flutter_assets/assets/images/app_icon_1024.png" "$appdir/mindra.png"
        cp "$build_dir/data/flutter_assets/assets/images/app_icon_1024.png" "$appdir/usr/share/pixmaps/mindra.png"
        log_success "使用 1024x1024 图标"
    else
        log_warning "未找到应用图标，AppImage 可能显示默认图标"
    fi
    
    # 构建 AppImage
    log_info "构建 AppImage..."
    local appimage_file="build/linux/Mindra-${app_version}-x86_64.AppImage"
    
    # 删除已存在的AppImage
    [ -f "$appimage_file" ] && rm -f "$appimage_file"
    
    # 运行appimagetool
    if appimagetool "$appdir" "$appimage_file"; then
        chmod +x "$appimage_file"
        local size=$(du -h "$appimage_file" | cut -f1)
        log_success "AppImage 创建完成: $appimage_file ($size)"
        
        # 显示使用说明
        echo ""
        log_info "使用方法:"
        echo "  chmod +x $appimage_file"
        echo "  ./$appimage_file"
        echo ""
        log_info "或者直接运行:"
        echo "  $appimage_file"
        
    else
        log_error "AppImage 创建失败"
        exit 1
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "         Mindra AppImage 创建工具"
    echo "=========================================="
    echo ""
    
    log_info "构建类型: $BUILD_TYPE"
    create_appimage
    
    echo ""
    log_success "AppImage 创建完成！"
}

# 执行主函数
main "$@" 