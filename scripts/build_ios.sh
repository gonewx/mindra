#!/bin/bash

# Mindra iOS 构建脚本
# 用于构建生产环境的 iOS 应用

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
    echo "Mindra iOS 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -c, --clean             构建前清理"
    echo "  -s, --simulator         为模拟器构建"
    echo "  -d, --device            为真机构建 (默认)"
    echo "  -a, --archive           创建 Archive"
    echo "  -v, --version           指定版本号 (格式: 1.0.0+1)"
    echo "  --skip-tests            跳过测试"
    echo "  --configuration CONFIG  构建配置 (Debug/Release，默认: Release)"
    echo ""
    echo "示例:"
    echo "  $0                      构建 Release 版本"
    echo "  $0 -c -a               清理后创建 Archive"
    echo "  $0 -s                  为模拟器构建"
    echo "  $0 -v 1.0.1+2          指定版本号构建"
}

# 默认参数
CLEAN_BUILD=false
BUILD_FOR_SIMULATOR=false
CREATE_ARCHIVE=false
SKIP_TESTS=false
CONFIGURATION="Release"
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
        -s|--simulator)
            BUILD_FOR_SIMULATOR=true
            shift
            ;;
        -d|--device)
            BUILD_FOR_SIMULATOR=false
            shift
            ;;
        -a|--archive)
            CREATE_ARCHIVE=true
            BUILD_FOR_SIMULATOR=false  # Archive 必须为真机构建
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --configuration)
            CONFIGURATION="$2"
            shift 2
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
    
    # 检查操作系统
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "iOS 构建需要在 macOS 上进行"
        exit 1
    fi
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode 未安装或命令行工具未配置"
        exit 1
    fi
    
    # 检查 iOS 开发环境
    if ! flutter doctor | grep -q "iOS toolchain"; then
        log_warning "iOS 工具链可能未正确配置"
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
        
        # 解析版本号
        VERSION_NAME=$(echo $VERSION | cut -d'+' -f1)
        VERSION_CODE=$(echo $VERSION | cut -d'+' -f2)
        
        # 更新 iOS Info.plist
        if [ -f "ios/Runner/Info.plist" ]; then
            /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NAME" ios/Runner/Info.plist
            /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_CODE" ios/Runner/Info.plist
            log_info "已更新 iOS Info.plist"
        fi
        
        log_success "版本号已更新"
    fi
}

# 清理构建
clean_build() {
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "清理构建缓存..."
        flutter clean
        flutter pub get
        
        # 清理 iOS 构建缓存
        if [ -d "ios/build" ]; then
            rm -rf ios/build
        fi
        
        # 清理 Xcode DerivedData
        if [ -d "~/Library/Developer/Xcode/DerivedData" ]; then
            log_info "清理 Xcode DerivedData..."
            rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
        fi
        
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

# 检查证书和配置文件
check_certificates() {
    if [ "$CREATE_ARCHIVE" = true ] || [ "$CONFIGURATION" = "Release" ]; then
        log_info "检查 iOS 证书和配置文件..."
        
        # 检查开发者证书
        local cert_count=$(security find-identity -v -p codesigning | grep "iPhone" | wc -l)
        if [ $cert_count -eq 0 ]; then
            log_error "未找到有效的 iOS 开发者证书"
            log_info "请在 Xcode 中配置开发者账号和证书"
            exit 1
        fi
        
        log_info "找到 $cert_count 个 iOS 证书"
        log_success "证书检查通过"
    fi
}

# 构建 iOS 应用
build_ios() {
    log_info "构建 iOS 应用..."
    
    local build_args="--$CONFIGURATION"
    
    if [ "$BUILD_FOR_SIMULATOR" = true ]; then
        build_args="$build_args --simulator"
        log_info "构建目标: iOS 模拟器"
    else
        build_args="$build_args --device"
        log_info "构建目标: iOS 真机"
    fi
    
    if flutter build ios $build_args; then
        log_success "iOS 构建成功"
        
        # 显示构建产物信息
        if [ "$BUILD_FOR_SIMULATOR" = true ]; then
            local app_path="build/ios/iphonesimulator/Runner.app"
        else
            local app_path="build/ios/iphoneos/Runner.app"
        fi
        
        if [ -d "$app_path" ]; then
            local size=$(du -sh "$app_path" | cut -f1)
            log_info "应用包: $app_path ($size)"
        fi
    else
        log_error "iOS 构建失败"
        exit 1
    fi
}

# 创建 Archive
create_archive() {
    if [ "$CREATE_ARCHIVE" = true ]; then
        log_info "创建 iOS Archive..."
        
        # 确保为真机构建
        if [ "$BUILD_FOR_SIMULATOR" = true ]; then
            log_error "Archive 必须为真机构建，不能为模拟器构建"
            exit 1
        fi
        
        # 使用 xcodebuild 创建 archive
        local archive_path="build/ios/archive/Runner.xcarchive"
        local workspace_path="ios/Runner.xcworkspace"
        
        # 创建 archive 目录
        mkdir -p build/ios/archive
        
        log_info "正在创建 Archive，这可能需要几分钟..."
        
        if xcodebuild -workspace "$workspace_path" \
                      -scheme Runner \
                      -configuration Release \
                      -destination generic/platform=iOS \
                      -archivePath "$archive_path" \
                      archive; then
            log_success "Archive 创建成功"
            log_info "Archive 路径: $archive_path"
            
            # 显示 Archive 信息
            if [ -d "$archive_path" ]; then
                local size=$(du -sh "$archive_path" | cut -f1)
                log_info "Archive 大小: $size"
            fi
        else
            log_error "Archive 创建失败"
            exit 1
        fi
    fi
}

# 验证构建产物
verify_build() {
    log_info "验证构建产物..."
    
    if [ "$CREATE_ARCHIVE" = true ]; then
        local archive_path="build/ios/archive/Runner.xcarchive"
        if [ -d "$archive_path" ]; then
            log_success "Archive 验证成功"
            
            # 检查 Archive 中的应用信息
            local info_plist="$archive_path/Info.plist"
            if [ -f "$info_plist" ]; then
                local app_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$info_plist" 2>/dev/null || echo "未知")
                local build_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$info_plist" 2>/dev/null || echo "未知")
                log_info "Archive 版本: $app_version ($build_version)"
            fi
        else
            log_error "Archive 验证失败"
            exit 1
        fi
    else
        # 验证普通构建
        if [ "$BUILD_FOR_SIMULATOR" = true ]; then
            local app_path="build/ios/iphonesimulator/Runner.app"
        else
            local app_path="build/ios/iphoneos/Runner.app"
        fi
        
        if [ -d "$app_path" ]; then
            log_success "应用包验证成功"
        else
            log_error "应用包验证失败"
            exit 1
        fi
    fi
}

# 生成构建报告
generate_report() {
    log_info "生成构建报告..."
    
    local report_file="build_report_ios_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "           Mindra iOS 构建报告"
        echo "=========================================="
        echo "构建时间: $(date)"
        echo "构建参数:"
        echo "  - 清理构建: $CLEAN_BUILD"
        echo "  - 构建目标: $([ "$BUILD_FOR_SIMULATOR" = true ] && echo "模拟器" || echo "真机")"
        echo "  - 创建 Archive: $CREATE_ARCHIVE"
        echo "  - 构建配置: $CONFIGURATION"
        echo "  - 跳过测试: $SKIP_TESTS"
        if [ -n "$VERSION" ]; then
            echo "  - 版本号: $VERSION"
        fi
        echo ""
        
        # Flutter 版本信息
        echo "Flutter 版本信息:"
        flutter --version
        echo ""
        
        # Xcode 版本信息
        echo "Xcode 版本信息:"
        xcodebuild -version
        echo ""
        
        # 构建产物
        echo "构建产物:"
        if [ "$CREATE_ARCHIVE" = true ]; then
            local archive_path="build/ios/archive/Runner.xcarchive"
            if [ -d "$archive_path" ]; then
                local size=$(du -sh "$archive_path" | cut -f1)
                echo "  ✅ Archive: $archive_path ($size)"
            fi
        else
            if [ "$BUILD_FOR_SIMULATOR" = true ]; then
                local app_path="build/ios/iphonesimulator/Runner.app"
            else
                local app_path="build/ios/iphoneos/Runner.app"
            fi
            
            if [ -d "$app_path" ]; then
                local size=$(du -sh "$app_path" | cut -f1)
                echo "  ✅ 应用包: $app_path ($size)"
            fi
        fi
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_success "构建报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra iOS 构建"
    echo "=========================================="
    echo ""
    
    check_environment
    update_version
    clean_build
    run_tests
    check_certificates
    build_ios
    create_archive
    verify_build
    generate_report
    
    echo ""
    echo "=========================================="
    log_success "iOS 构建完成！"
    echo "=========================================="
    
    # 显示下一步操作
    if [ "$CREATE_ARCHIVE" = true ]; then
        echo ""
        log_info "下一步操作:"
        echo "1. 在 Xcode 中打开 Archive"
        echo "2. 验证应用并上传到 App Store Connect"
        echo "3. 或使用 Fastlane 自动上传"
    fi
}

# 运行主函数
main "$@"
