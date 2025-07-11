#!/bin/bash

# Mindra 快速部署脚本
# 一键构建、测试和发布应用

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
    echo "Mindra 快速部署脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -e, --env ENV           部署环境 (dev/staging/prod)"
    echo "  -p, --platform PLATFORM 目标平台 (android/ios/all)"
    echo "  -t, --track TRACK       发布轨道 (internal/alpha/beta/production)"
    echo "  --bump-version TYPE     自动递增版本号 (major/minor/patch)"
    echo "  --skip-tests            跳过测试"
    echo "  --skip-build            跳过构建（使用现有构建产物）"
    echo "  --dry-run               模拟运行，不实际发布"
    echo ""
    echo "环境说明:"
    echo "  dev        - 开发环境（内部测试）"
    echo "  staging    - 预发布环境（测试版本）"
    echo "  prod       - 生产环境（正式发布）"
    echo ""
    echo "示例:"
    echo "  $0 -e dev               部署到开发环境"
    echo "  $0 -e staging -p android 部署 Android 到预发布环境"
    echo "  $0 -e prod --bump-version patch 递增版本并部署到生产环境"
}

# 默认参数
ENVIRONMENT="dev"
PLATFORM="all"
TRACK=""
BUMP_VERSION=""
SKIP_TESTS=false
SKIP_BUILD=false
DRY_RUN=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--track)
            TRACK="$2"
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
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证参数
validate_params() {
    # 验证环境
    case $ENVIRONMENT in
        dev|staging|prod)
            ;;
        *)
            log_error "无效的环境: $ENVIRONMENT"
            log_info "支持的环境: dev, staging, prod"
            exit 1
            ;;
    esac
    
    # 验证平台
    case $PLATFORM in
        android|ios|all)
            ;;
        *)
            log_error "无效的平台: $PLATFORM"
            log_info "支持的平台: android, ios, all"
            exit 1
            ;;
    esac
    
    # 根据环境设置默认发布轨道
    if [ -z "$TRACK" ]; then
        case $ENVIRONMENT in
            dev)
                TRACK="internal"
                ;;
            staging)
                TRACK="beta"
                ;;
            prod)
                TRACK="production"
                ;;
        esac
    fi
    
    log_info "部署配置:"
    log_info "  环境: $ENVIRONMENT"
    log_info "  平台: $PLATFORM"
    log_info "  发布轨道: $TRACK"
    if [ -n "$BUMP_VERSION" ]; then
        log_info "  版本递增: $BUMP_VERSION"
    fi
    if [ "$DRY_RUN" = true ]; then
        log_warning "  模拟运行模式"
    fi
}

# 预检查
pre_check() {
    log_info "执行预检查..."
    
    # 检查 Git 状态
    if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
        if [ "$ENVIRONMENT" = "prod" ] && ! git diff-index --quiet HEAD --; then
            log_error "生产环境部署要求工作目录干净"
            log_info "请提交或暂存所有更改"
            exit 1
        fi
    fi
    
    # 检查必要文件
    local required_files=(
        "pubspec.yaml"
        "scripts/build_all.sh"
        "scripts/version_manager.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "必要文件不存在: $file"
            exit 1
        fi
    done
    
    # 检查平台特定文件
    if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
        if [ ! -f "scripts/build_android.sh" ] || [ ! -f "scripts/release_android.sh" ]; then
            log_error "Android 构建/发布脚本不存在"
            exit 1
        fi
    fi
    
    if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
        if [ ! -f "scripts/build_ios.sh" ] || [ ! -f "scripts/release_ios.sh" ]; then
            log_error "iOS 构建/发布脚本不存在"
            exit 1
        fi
    fi
    
    log_success "预检查通过"
}

# 版本管理
manage_version() {
    if [ -n "$BUMP_VERSION" ]; then
        log_info "递增版本号..."
        
        if [ "$DRY_RUN" = true ]; then
            ./scripts/version_manager.sh bump "$BUMP_VERSION" --dry-run
        else
            ./scripts/version_manager.sh bump "$BUMP_VERSION"
        fi
        
        log_success "版本号已更新"
    fi
    
    # 显示当前版本
    ./scripts/version_manager.sh show
}

# 运行测试
run_tests() {
    if [ "$SKIP_TESTS" = false ]; then
        log_info "运行测试..."
        
        if flutter test; then
            log_success "所有测试通过"
        else
            log_error "测试失败，停止部署"
            exit 1
        fi
    else
        log_warning "跳过测试"
    fi
}

# 构建应用
build_app() {
    if [ "$SKIP_BUILD" = false ]; then
        log_info "构建应用..."
        
        local build_args="--archive"
        
        # 根据平台设置构建参数
        case $PLATFORM in
            android)
                build_args="$build_args -a"
                ;;
            ios)
                build_args="$build_args -i"
                ;;
            all)
                # 默认构建所有平台
                ;;
        esac
        
        if [ "$SKIP_TESTS" = true ]; then
            build_args="$build_args --skip-tests"
        fi
        
        if ./scripts/build_all.sh $build_args; then
            log_success "应用构建完成"
        else
            log_error "应用构建失败"
            exit 1
        fi
    else
        log_warning "跳过构建，使用现有构建产物"
    fi
}

# 发布应用
deploy_app() {
    log_info "发布应用..."
    
    local deploy_success=true
    
    # 发布 Android
    if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
        log_info "发布 Android 应用..."
        
        local android_args="-t $TRACK"
        if [ "$DRY_RUN" = true ]; then
            android_args="$android_args --dry-run"
        fi
        
        if ./scripts/release_android.sh $android_args; then
            log_success "Android 应用发布成功"
        else
            log_error "Android 应用发布失败"
            deploy_success=false
        fi
    fi
    
    # 发布 iOS
    if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
        log_info "发布 iOS 应用..."
        
        local ios_args=""
        case $TRACK in
            internal|alpha|beta)
                ios_args="-t"  # TestFlight
                ;;
            production)
                ios_args="-s"  # App Store
                ;;
        esac
        
        if [ "$DRY_RUN" = true ]; then
            ios_args="$ios_args --dry-run"
        fi
        
        if ./scripts/release_ios.sh $ios_args; then
            log_success "iOS 应用发布成功"
        else
            log_error "iOS 应用发布失败"
            deploy_success=false
        fi
    fi
    
    if [ "$deploy_success" = false ]; then
        log_error "部分应用发布失败"
        exit 1
    fi
    
    log_success "所有应用发布完成"
}

# 发布后操作
post_deploy() {
    log_info "执行发布后操作..."
    
    # 创建 Git 标签（仅生产环境）
    if [ "$ENVIRONMENT" = "prod" ] && [ "$DRY_RUN" = false ]; then
        if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
            log_info "创建 Git 标签..."
            ./scripts/version_manager.sh tag
        fi
    fi
    
    # 生成部署报告
    generate_deploy_report
    
    log_success "发布后操作完成"
}

# 生成部署报告
generate_deploy_report() {
    local report_file="deploy_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "           Mindra 部署报告"
        echo "=========================================="
        echo "部署时间: $(date)"
        echo "环境: $ENVIRONMENT"
        echo "平台: $PLATFORM"
        echo "发布轨道: $TRACK"
        echo "模拟运行: $DRY_RUN"
        if [ -n "$BUMP_VERSION" ]; then
            echo "版本递增: $BUMP_VERSION"
        fi
        echo ""
        
        # 当前版本信息
        echo "版本信息:"
        ./scripts/version_manager.sh show | grep -E "(当前版本|主版本号|次版本号|补丁版本|构建号)"
        echo ""
        
        # 构建产物
        echo "构建产物:"
        if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
            if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
                local aab_size=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
                echo "  ✅ Android AAB: $aab_size"
            fi
        fi
        
        if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
            if [ -d "build/ios/archive/Runner.xcarchive" ]; then
                local archive_size=$(du -sh "build/ios/archive/Runner.xcarchive" | cut -f1)
                echo "  ✅ iOS Archive: $archive_size"
            fi
        fi
        
        echo ""
        echo "下一步操作:"
        case $ENVIRONMENT in
            dev)
                echo "  1. 通知团队进行内部测试"
                echo "  2. 收集测试反馈"
                echo "  3. 修复问题后部署到 staging"
                ;;
            staging)
                echo "  1. 邀请外部测试者"
                echo "  2. 进行全面测试"
                echo "  3. 准备生产发布"
                ;;
            prod)
                echo "  1. 监控应用表现"
                echo "  2. 关注用户反馈"
                echo "  3. 准备下一版本"
                ;;
        esac
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_success "部署报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra 快速部署"
    echo "=========================================="
    echo ""
    
    validate_params
    pre_check
    manage_version
    run_tests
    build_app
    deploy_app
    post_deploy
    
    echo ""
    echo "=========================================="
    if [ "$DRY_RUN" = true ]; then
        log_success "部署模拟完成！"
    else
        log_success "部署完成！"
    fi
    echo "=========================================="
}

# 运行主函数
main "$@"
