#!/bin/bash

# Mindra Android 构建脚本
# 用于构建生产环境的 Android APK 和 AAB 包

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
    echo "Mindra Android 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -c, --clean         构建前清理"
    echo "  -a, --apk-only      仅构建 APK"
    echo "  -b, --aab-only      仅构建 AAB"
    echo "  -v, --version       指定版本号 (格式: 1.0.0+1)"
    echo "  -s, --skip-tests    跳过测试"
    echo "  --no-obfuscate      禁用代码混淆"
    echo ""
    echo "示例:"
    echo "  $0                  构建 APK 和 AAB"
    echo "  $0 -c               清理后构建"
    echo "  $0 -a -v 1.0.1+2    仅构建 APK 并指定版本"
}

# 默认参数
CLEAN_BUILD=false
BUILD_APK=true
BUILD_AAB=true
SKIP_TESTS=false
OBFUSCATE=true
VERSION=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -a|--apk-only)
            BUILD_APK=true
            BUILD_AAB=false
            shift
            ;;
        -b|--aab-only)
            BUILD_APK=false
            BUILD_AAB=true
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --no-obfuscate)
            OBFUSCATE=false
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
    
    # 检查 Android SDK
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        log_error "ANDROID_HOME 或 ANDROID_SDK_ROOT 环境变量未设置"
        exit 1
    fi
    
    # 检查签名文件
    if [ ! -f "android/release-keystore.jks" ]; then
        log_error "发布密钥库文件不存在: android/release-keystore.jks"
        log_info "请运行 ./scripts/create_release_keystore.sh 创建密钥库"
        exit 1
    fi
    
    if [ ! -f "android/key.properties" ]; then
        log_error "签名配置文件不存在: android/key.properties"
        exit 1
    fi
    
    log_success "环境检查通过"
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

# 清理构建
clean_build() {
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "清理构建缓存..."
        flutter clean
        flutter pub get
        log_success "清理完成"
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

# 构建 APK
build_apk() {
    if [ "$BUILD_APK" = true ]; then
        log_info "构建 Android APK..."
        
        local build_args="--release"
        if [ "$OBFUSCATE" = false ]; then
            build_args="$build_args --no-obfuscate"
        fi
        
        if flutter build apk $build_args; then
            log_success "APK 构建成功"
            
            # 显示文件信息
            local apk_file="build/app/outputs/flutter-apk/app-release.apk"
            if [ -f "$apk_file" ]; then
                local size=$(du -h "$apk_file" | cut -f1)
                log_info "APK 文件: $apk_file ($size)"
            fi
        else
            log_error "APK 构建失败"
            exit 1
        fi
    fi
}

# 构建 AAB
build_aab() {
    if [ "$BUILD_AAB" = true ]; then
        log_info "构建 Android App Bundle (AAB)..."
        
        local build_args="--release"
        if [ "$OBFUSCATE" = false ]; then
            build_args="$build_args --no-obfuscate"
        fi
        
        if flutter build appbundle $build_args; then
            log_success "AAB 构建成功"
            
            # 显示文件信息
            local aab_file="build/app/outputs/bundle/release/app-release.aab"
            if [ -f "$aab_file" ]; then
                local size=$(du -h "$aab_file" | cut -f1)
                log_info "AAB 文件: $aab_file ($size)"
            fi
        else
            log_error "AAB 构建失败"
            exit 1
        fi
    fi
}

# 验证签名
verify_signatures() {
    log_info "验证应用签名..."
    
    local verified=0
    
    # 验证 APK 签名
    if [ "$BUILD_APK" = true ] && [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        if jarsigner -verify build/app/outputs/flutter-apk/app-release.apk > /dev/null 2>&1; then
            log_success "APK 签名验证成功"
            ((verified++))
        else
            log_error "APK 签名验证失败"
        fi
    fi
    
    # 验证 AAB 签名
    if [ "$BUILD_AAB" = true ] && [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        if jarsigner -verify build/app/outputs/bundle/release/app-release.aab > /dev/null 2>&1; then
            log_success "AAB 签名验证成功"
            ((verified++))
        else
            log_error "AAB 签名验证失败"
        fi
    fi
    
    if [ $verified -eq 0 ]; then
        log_error "没有成功验证任何签名"
        exit 1
    fi
}

# 生成构建报告
generate_report() {
    log_info "生成构建报告..."
    
    local report_file="build_report_android_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "           Mindra Android 构建报告"
        echo "=========================================="
        echo "构建时间: $(date)"
        echo "构建参数:"
        echo "  - 清理构建: $CLEAN_BUILD"
        echo "  - 构建 APK: $BUILD_APK"
        echo "  - 构建 AAB: $BUILD_AAB"
        echo "  - 跳过测试: $SKIP_TESTS"
        echo "  - 代码混淆: $OBFUSCATE"
        if [ -n "$VERSION" ]; then
            echo "  - 版本号: $VERSION"
        fi
        echo ""
        
        # Flutter 版本信息
        echo "Flutter 版本信息:"
        flutter --version
        echo ""
        
        # 构建产物
        echo "构建产物:"
        if [ "$BUILD_APK" = true ] && [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            local apk_size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
            echo "  ✅ APK: build/app/outputs/flutter-apk/app-release.apk ($apk_size)"
        fi
        
        if [ "$BUILD_AAB" = true ] && [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
            local aab_size=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
            echo "  ✅ AAB: build/app/outputs/bundle/release/app-release.aab ($aab_size)"
        fi
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_success "构建报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra Android 构建"
    echo "=========================================="
    echo ""
    
    check_environment
    update_version
    clean_build
    run_tests
    build_apk
    build_aab
    verify_signatures
    generate_report
    
    echo ""
    echo "=========================================="
    log_success "Android 构建完成！"
    echo "=========================================="
    
    # 运行构建摘要
    if [ -f "scripts/build_summary.sh" ]; then
        echo ""
        ./scripts/build_summary.sh
    fi
}

# 运行主函数
main "$@"
