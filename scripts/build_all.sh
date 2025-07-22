#!/bin/bash

# Mindra 跨平台构建脚本
# 用于同时构建 Android 和 iOS 版本

set -e  # 遇到错误时退出

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

# 显示帮助信息
show_help() {
    echo "Mindra 跨平台构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -a, --android-only      仅构建 Android"
    echo "  -i, --ios-only          仅构建 iOS"
    echo "  -l, --linux-only        仅构建 Linux"
    echo "  -c, --clean             构建前清理"
    echo "  -v, --version VERSION   指定版本号 (格式: 1.0.0+1)"
    echo "  --bump-version TYPE     自动递增版本号 (major/minor/patch)"
    echo "  --skip-tests            跳过测试"
    echo "  --archive               创建发布包 (Android AAB + iOS Archive + Linux Package)"
    echo "  --parallel              并行构建 (实验性)"
    echo ""
    echo "示例:"
    echo "  $0                      构建所有平台"
    echo "  $0 -a                   仅构建 Android"
    echo "  $0 -l                   仅构建 Linux"
    echo "  $0 -c --archive         清理后创建发布包"
    echo "  $0 --bump-version patch 递增补丁版本号并构建"
}

# 默认参数
BUILD_ANDROID=true
BUILD_IOS=true
BUILD_LINUX=true
CLEAN_BUILD=false
VERSION=""
BUMP_VERSION=""
SKIP_TESTS=false
CREATE_ARCHIVE=false
PARALLEL_BUILD=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--android-only)
            BUILD_ANDROID=true
            BUILD_IOS=false
            BUILD_LINUX=false
            shift
            ;;
        -i|--ios-only)
            BUILD_ANDROID=false
            BUILD_IOS=true
            BUILD_LINUX=false
            shift
            ;;
        -l|--linux-only)
            BUILD_ANDROID=false
            BUILD_IOS=false
            BUILD_LINUX=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --bump-version)
            BUMP_VERSION="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --archive)
            CREATE_ARCHIVE=true
            shift
            ;;
        --parallel)
            PARALLEL_BUILD=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查环境
check_environment() {
    log_info "检查构建环境..."
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 Android 环境
    if [ "$BUILD_ANDROID" = true ]; then
        if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
            log_error "ANDROID_HOME 或 ANDROID_SDK_ROOT 环境变量未设置"
            exit 1
        fi
        log_success "Android 环境检查通过"
    fi
    
    # 检查 iOS 环境
    if [ "$BUILD_IOS" = true ]; then
        if [[ "$OSTYPE" != "darwin"* ]]; then
            log_error "iOS 构建需要在 macOS 上进行"
            exit 1
        fi
        
        if ! command -v xcodebuild &> /dev/null; then
            log_error "Xcode 未安装或命令行工具未配置"
            exit 1
        fi
        log_success "iOS 环境检查通过"
    fi
    
    # 检查 Linux 环境
    if [ "$BUILD_LINUX" = true ]; then
        if [[ "$OSTYPE" != "linux-gnu"* ]]; then
            log_error "Linux 构建需要在 Linux 系统上进行"
            exit 1
        fi
        
        # 检查 Linux 构建依赖
        local missing_deps=()
        
        if ! pkg-config --exists gtk+-3.0; then
            missing_deps+=("libgtk-3-dev")
        fi
        
        if ! command -v ninja &> /dev/null; then
            missing_deps+=("ninja-build")
        fi
        
        if ! command -v cmake &> /dev/null; then
            missing_deps+=("cmake")
        fi
        
        if [ ${#missing_deps[@]} -gt 0 ]; then
            log_error "缺少以下 Linux 构建依赖："
            for dep in "${missing_deps[@]}"; do
                echo "  - $dep"
            done
            log_info "请运行: sudo apt install ${missing_deps[*]}"
            exit 1
        fi
        
        log_success "Linux 环境检查通过"
    fi
    
    log_success "环境检查完成"
}

# 自动递增版本号
bump_version() {
    if [ -n "$BUMP_VERSION" ]; then
        log_info "自动递增版本号: $BUMP_VERSION"
        
        # 读取当前版本
        local current_version=$(grep "^version:" pubspec.yaml | cut -d' ' -f2)
        local version_name=$(echo $current_version | cut -d'+' -f1)
        local build_number=$(echo $current_version | cut -d'+' -f2)
        
        # 解析版本号
        IFS='.' read -ra VERSION_PARTS <<< "$version_name"
        local major=${VERSION_PARTS[0]}
        local minor=${VERSION_PARTS[1]}
        local patch=${VERSION_PARTS[2]}
        
        # 递增版本号
        case $BUMP_VERSION in
            major)
                ((major++))
                minor=0
                patch=0
                ;;
            minor)
                ((minor++))
                patch=0
                ;;
            patch)
                ((patch++))
                ;;
            *)
                log_error "无效的版本递增类型: $BUMP_VERSION"
                exit 1
                ;;
        esac
        
        # 递增构建号
        ((build_number++))
        
        # 生成新版本号
        VERSION="$major.$minor.$patch+$build_number"
        log_info "新版本号: $current_version -> $VERSION"
    fi
}

# 更新版本号
update_version() {
    if [ -n "$VERSION" ]; then
        log_info "更新版本号到: $VERSION"
        
        # 备份原始文件
        cp pubspec.yaml pubspec.yaml.backup
        
        # 更新 pubspec.yaml
        sed -i.tmp "s/^version:.*/version: $VERSION/" pubspec.yaml
        rm pubspec.yaml.tmp
        
        log_success "版本号已更新"
    fi
}

# 运行测试
run_tests() {
    if [ "$SKIP_TESTS" = false ]; then
        log_info "运行测试..."
        if flutter test; then
            log_success "所有测试通过"
        else
            log_error "测试失败"
            exit 1
        fi
    else
        log_warning "跳过测试"
    fi
}

# 构建 Android
build_android() {
    if [ "$BUILD_ANDROID" = true ]; then
        log_info "开始构建 Android..."
        
        local android_args=""
        if [ "$CLEAN_BUILD" = true ]; then
            android_args="$android_args -c"
        fi
        if [ "$CREATE_ARCHIVE" = true ]; then
            android_args="$android_args -b"  # 构建 AAB
        fi
        if [ "$SKIP_TESTS" = true ]; then
            android_args="$android_args -s"
        fi
        if [ -n "$VERSION" ]; then
            android_args="$android_args -v $VERSION"
        fi
        
        if ./scripts/build_android.sh $android_args; then
            log_success "Android 构建完成"
        else
            log_error "Android 构建失败"
            return 1
        fi
    fi
}

# 构建 iOS
build_ios() {
    if [ "$BUILD_IOS" = true ]; then
        log_info "开始构建 iOS..."
        
        local ios_args=""
        if [ "$CLEAN_BUILD" = true ]; then
            ios_args="$ios_args -c"
        fi
        if [ "$CREATE_ARCHIVE" = true ]; then
            ios_args="$ios_args -a"  # 创建 Archive
        fi
        if [ "$SKIP_TESTS" = true ]; then
            ios_args="$ios_args --skip-tests"
        fi
        if [ -n "$VERSION" ]; then
            ios_args="$ios_args -v $VERSION"
        fi
        
        if ./scripts/build_ios.sh $ios_args; then
            log_success "iOS 构建完成"
        else
            log_error "iOS 构建失败"
            return 1
        fi
    fi
}

# 构建 Linux
build_linux() {
    if [ "$BUILD_LINUX" = true ]; then
        log_info "开始构建 Linux..."
        
        local linux_args=""
        if [ "$CLEAN_BUILD" = true ]; then
            linux_args="$linux_args -c"
        fi
        if [ "$CREATE_ARCHIVE" = true ]; then
            linux_args="$linux_args -p --appimage"  # 创建AppImage
        fi
        if [ "$SKIP_TESTS" = true ]; then
            linux_args="$linux_args -s"
        fi
        if [ -n "$VERSION" ]; then
            linux_args="$linux_args -v $VERSION"
        fi
        
        if ./scripts/build_linux.sh $linux_args; then
            log_success "Linux 构建完成"
        else
            log_error "Linux 构建失败"
            return 1
        fi
    fi
}

# 并行构建
parallel_build() {
    log_info "开始并行构建..."
    
    local pids=()
    local results=()
    
    # 启动 Android 构建
    if [ "$BUILD_ANDROID" = true ]; then
        log_info "启动 Android 构建进程..."
        build_android &
        pids+=($!)
        results+=("Android")
    fi
    
    # 启动 iOS 构建
    if [ "$BUILD_IOS" = true ]; then
        log_info "启动 iOS 构建进程..."
        build_ios &
        pids+=($!)
        results+=("iOS")
    fi
    
    # 启动 Linux 构建
    if [ "$BUILD_LINUX" = true ]; then
        log_info "启动 Linux 构建进程..."
        build_linux &
        pids+=($!)
        results+=("Linux")
    fi
    
    # 等待所有构建完成
    local failed=false
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local platform=${results[$i]}
        
        if wait $pid; then
            log_success "$platform 构建完成"
        else
            log_error "$platform 构建失败"
            failed=true
        fi
    done
    
    if [ "$failed" = true ]; then
        log_error "部分构建失败"
        return 1
    fi
    
    log_success "所有平台构建完成"
}

# 顺序构建
sequential_build() {
    log_info "开始顺序构建..."
    
    # 构建 Android
    if ! build_android; then
        return 1
    fi
    
    # 构建 iOS
    if ! build_ios; then
        return 1
    fi
    
    # 构建 Linux
    if ! build_linux; then
        return 1
    fi
    
    log_success "所有平台构建完成"
}

# 生成构建摘要
generate_summary() {
    log_info "生成构建摘要..."
    
    echo ""
    echo "=========================================="
    echo "           Mindra 跨平台构建摘要"
    echo "=========================================="
    echo "构建时间: $(date)"
    echo "构建平台:"
    if [ "$BUILD_ANDROID" = true ]; then
        echo "  ✅ Android"
    fi
    if [ "$BUILD_IOS" = true ]; then
        echo "  ✅ iOS"
    fi
    if [ "$BUILD_LINUX" = true ]; then
        echo "  ✅ Linux"
    fi
    echo ""
    
    # 显示构建产物
    echo "构建产物:"
    
    # Android 产物
    if [ "$BUILD_ANDROID" = true ]; then
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            local apk_size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
            echo "  📱 Android APK: build/app/outputs/flutter-apk/app-release.apk ($apk_size)"
        fi
        
        if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
            local aab_size=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
            echo "  📦 Android AAB: build/app/outputs/bundle/release/app-release.aab ($aab_size)"
        fi
    fi
    
    # iOS 产物
    if [ "$BUILD_IOS" = true ]; then
        if [ -d "build/ios/archive/Runner.xcarchive" ]; then
            local archive_size=$(du -sh "build/ios/archive/Runner.xcarchive" | cut -f1)
            echo "  🍎 iOS Archive: build/ios/archive/Runner.xcarchive ($archive_size)"
        fi
        
        if [ -f "build/ios/ipa/Runner.ipa" ]; then
            local ipa_size=$(du -h "build/ios/ipa/Runner.ipa" | cut -f1)
            echo "  📱 iOS IPA: build/ios/ipa/Runner.ipa ($ipa_size)"
        fi
    fi
    
    # Linux 产物
    if [ "$BUILD_LINUX" = true ]; then
        if [ -d "build/linux/x64/release/bundle" ]; then
            local bundle_size=$(du -sh "build/linux/x64/release/bundle" | cut -f1)
            echo "  🐧 Linux Bundle: build/linux/x64/release/bundle ($bundle_size)"
        fi
        
        if ls build/linux/*.AppImage &>/dev/null; then
            for appimage in build/linux/*.AppImage; do
                local appimage_size=$(du -h "$appimage" | cut -f1)
                echo "  📦 Linux AppImage: $(basename "$appimage") ($appimage_size)"
            done
        else
            echo "  ⚠️ 没有找到Linux AppImage文件"
        fi
    fi
    
    echo ""
    echo "下一步操作:"
    echo "  1. 测试构建产物"
    echo "  2. 使用发布脚本上传到应用商店"
    echo "  3. 或手动上传到相应的应用商店"
    echo ""
    echo "发布命令:"
    if [ "$BUILD_ANDROID" = true ]; then
        echo "  Android: ./scripts/release_android.sh -t internal"
    fi
    if [ "$BUILD_IOS" = true ]; then
        echo "  iOS: ./scripts/release_ios.sh -t"
    fi
    if [ "$BUILD_LINUX" = true ]; then
        echo "  Linux: 手动上传 AppImage 到软件仓库或应用商店"
    fi
    echo ""
    echo "=========================================="
}

# 清理函数
cleanup() {
    if [ -f "pubspec.yaml.backup" ]; then
        log_info "恢复版本号..."
        mv pubspec.yaml.backup pubspec.yaml
    fi
}

# 设置清理陷阱
trap cleanup EXIT

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra 跨平台构建"
    echo "=========================================="
    echo ""
    
    check_environment
    bump_version
    update_version
    run_tests
    
    # 选择构建方式
    if [ "$PARALLEL_BUILD" = true ] && [ "$BUILD_ANDROID" = true ] && [ "$BUILD_IOS" = true ]; then
        parallel_build
    else
        sequential_build
    fi
    
    if [ $? -eq 0 ]; then
        generate_summary
        
        echo ""
        echo "=========================================="
        log_success "跨平台构建完成！"
        echo "=========================================="
    else
        log_error "构建失败"
        exit 1
    fi
}

# 运行主函数
main "$@"
