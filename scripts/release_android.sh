#!/bin/bash

# Mindra Android 发布脚本
# 用于将构建好的 AAB 包发布到 Google Play Store

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
    echo "Mindra Android 发布脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -t, --track TRACK       发布轨道 (internal/alpha/beta/production)"
    echo "  -f, --file FILE         指定 AAB 文件路径"
    echo "  --dry-run               模拟运行，不实际上传"
    echo "  --skip-validation       跳过预发布验证"
    echo ""
    echo "发布轨道说明:"
    echo "  internal     - 内部测试 (最多100个测试者)"
    echo "  alpha        - 封闭测试 (邀请制)"
    echo "  beta         - 开放测试 (公开但需要加入)"
    echo "  production   - 正式发布"
    echo ""
    echo "示例:"
    echo "  $0 -t internal          发布到内部测试轨道"
    echo "  $0 -t beta --dry-run    模拟发布到测试轨道"
}

# 默认参数
TRACK="internal"
AAB_FILE=""
DRY_RUN=false
SKIP_VALIDATION=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--track)
            TRACK="$2"
            shift 2
            ;;
        -f|--file)
            AAB_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证发布轨道
validate_track() {
    case $TRACK in
        internal|alpha|beta|production)
            log_info "发布轨道: $TRACK"
            ;;
        *)
            log_error "无效的发布轨道: $TRACK"
            log_info "支持的轨道: internal, alpha, beta, production"
            exit 1
            ;;
    esac
}

# 查找 AAB 文件
find_aab_file() {
    if [ -z "$AAB_FILE" ]; then
        AAB_FILE="build/app/outputs/bundle/release/app-release.aab"
    fi
    
    if [ ! -f "$AAB_FILE" ]; then
        log_error "AAB 文件不存在: $AAB_FILE"
        log_info "请先运行构建脚本: ./scripts/build_android.sh -b"
        exit 1
    fi
    
    log_info "AAB 文件: $AAB_FILE"
    local size=$(du -h "$AAB_FILE" | cut -f1)
    log_info "文件大小: $size"
}

# 预发布验证
pre_release_validation() {
    if [ "$SKIP_VALIDATION" = true ]; then
        log_warning "跳过预发布验证"
        return
    fi
    
    log_info "执行预发布验证..."
    
    # 验证 AAB 签名
    log_info "验证 AAB 签名..."
    if jarsigner -verify "$AAB_FILE" > /dev/null 2>&1; then
        log_success "AAB 签名验证成功"
    else
        log_error "AAB 签名验证失败"
        exit 1
    fi
    
    # 检查应用 ID（从 build.gradle.kts 读取）
    log_info "验证应用 ID..."
    local expected_app_id="com.mindra.app"
    local gradle_file="android/app/build.gradle.kts"
    
    if [ -f "$gradle_file" ]; then
        local app_id=$(grep "applicationId" "$gradle_file" | sed 's/.*applicationId = "\([^"]*\)".*/\1/')
        if [ "$app_id" = "$expected_app_id" ]; then
            log_success "应用 ID 验证成功: $app_id"
        else
            log_error "应用 ID 不匹配，期望: $expected_app_id，实际: $app_id"
            exit 1
        fi
    else
        log_warning "无法找到 build.gradle.kts 文件，跳过应用 ID 验证"
    fi
    
    # 检查版本信息（从 pubspec.yaml 读取）
    log_info "验证版本信息..."
    local pubspec_file="pubspec.yaml"
    
    if [ -f "$pubspec_file" ]; then
        local version_line=$(grep "^version:" "$pubspec_file")
        local version_name=$(echo "$version_line" | sed 's/version: \([^+]*\).*/\1/')
        local version_code=$(echo "$version_line" | sed 's/.*+\([0-9]*\).*/\1/')
        
        log_info "版本名称: $version_name"
        log_info "版本代码: $version_code"
    else
        log_warning "无法找到 pubspec.yaml 文件，跳过版本信息验证"
    fi
    
    # AAB 文件格式验证
    log_info "验证 AAB 文件格式..."
    if file "$AAB_FILE" | grep -q "Zip archive"; then
        log_success "AAB 文件格式验证成功"
    else
        log_error "AAB 文件格式不正确"
        exit 1
    fi
    
    log_success "预发布验证完成"
}

# 检查 Google Play Console API 配置
check_api_config() {
    log_info "检查 Google Play Console API 配置..."
    
    # 检查服务账号密钥文件
    local service_account_file="android/play-console-service-account.json"
    if [ ! -f "$service_account_file" ]; then
        log_error "Google Play Console 服务账号密钥文件不存在: $service_account_file"
        log_info "请按照以下步骤配置:"
        log_info "1. 在 Google Play Console 中创建服务账号"
        log_info "2. 下载服务账号密钥文件"
        log_info "3. 将文件保存为: $service_account_file"
        exit 1
    fi
    
    # 检查 fastlane 配置
    if [ ! -f "android/fastlane/Fastfile" ]; then
        log_warning "Fastlane 配置不存在，将使用手动上传流程"
        return 1
    fi
    
    log_success "API 配置检查完成"
    return 0
}

# 使用 Fastlane 上传
upload_with_fastlane() {
    log_info "使用 Fastlane 上传到 Google Play Store..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "模拟运行: bundle exec fastlane android deploy track:$TRACK"
        log_success "模拟上传完成"
        return
    fi
    
    cd android
    if bundle exec fastlane deploy track:$TRACK; then
        log_success "Fastlane 上传成功"
    else
        log_error "Fastlane 上传失败"
        exit 1
    fi
    cd ..
}

# 手动上传指导
manual_upload_guide() {
    log_info "手动上传指导:"
    echo ""
    echo "=========================================="
    echo "           手动上传到 Google Play Store"
    echo "=========================================="
    echo ""
    echo "1. 打开 Google Play Console: https://play.google.com/console"
    echo "2. 选择 Mindra 应用"
    echo "3. 进入 '发布' > '应用版本'"
    echo "4. 选择发布轨道: $TRACK"
    echo "5. 点击 '创建新版本'"
    echo "6. 上传 AAB 文件: $AAB_FILE"
    echo "7. 填写版本说明"
    echo "8. 检查并发布"
    echo ""
    echo "发布轨道说明:"
    case $TRACK in
        internal)
            echo "  - 内部测试: 最多100个内部测试者"
            echo "  - 审核时间: 几分钟内"
            echo "  - 适用于: 开发团队内部测试"
            ;;
        alpha)
            echo "  - 封闭测试: 邀请制测试"
            echo "  - 审核时间: 几小时内"
            echo "  - 适用于: 小范围用户测试"
            ;;
        beta)
            echo "  - 开放测试: 公开但需要加入"
            echo "  - 审核时间: 几小时内"
            echo "  - 适用于: 大范围用户测试"
            ;;
        production)
            echo "  - 正式发布: 所有用户可见"
            echo "  - 审核时间: 1-3天"
            echo "  - 适用于: 正式版本发布"
            ;;
    esac
    echo ""
    echo "=========================================="
}

# 生成发布报告
generate_release_report() {
    log_info "生成发布报告..."
    
    local report_file="release_report_android_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "           Mindra Android 发布报告"
        echo "=========================================="
        echo "发布时间: $(date)"
        echo "发布轨道: $TRACK"
        echo "AAB 文件: $AAB_FILE"
        echo "模拟运行: $DRY_RUN"
        echo ""
        
        # 应用信息
        echo "应用信息:"
        local gradle_file="android/app/build.gradle.kts"
        local pubspec_file="pubspec.yaml"
        
        if [ -f "$gradle_file" ]; then
            local app_id=$(grep "applicationId" "$gradle_file" | sed 's/.*applicationId = "\([^"]*\)".*/\1/')
            echo "  应用 ID: $app_id"
        fi
        
        if [ -f "$pubspec_file" ]; then
            local version_line=$(grep "^version:" "$pubspec_file")
            local version_name=$(echo "$version_line" | sed 's/version: \([^+]*\).*/\1/')
            local version_code=$(echo "$version_line" | sed 's/.*+\([0-9]*\).*/\1/')
            echo "  版本名称: $version_name"
            echo "  版本代码: $version_code"
        fi
        
        echo ""
        echo "文件信息:"
        local size=$(du -h "$AAB_FILE" | cut -f1)
        echo "  文件大小: $size"
        echo "  文件路径: $AAB_FILE"
        
        echo ""
        echo "下一步操作:"
        case $TRACK in
            internal)
                echo "  1. 邀请内部测试者"
                echo "  2. 收集测试反馈"
                echo "  3. 修复问题后发布到 alpha"
                ;;
            alpha)
                echo "  1. 邀请封闭测试者"
                echo "  2. 收集用户反馈"
                echo "  3. 优化后发布到 beta"
                ;;
            beta)
                echo "  1. 监控测试反馈"
                echo "  2. 修复关键问题"
                echo "  3. 准备正式发布"
                ;;
            production)
                echo "  1. 监控发布状态"
                echo "  2. 关注用户反馈"
                echo "  3. 准备后续更新"
                ;;
        esac
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_success "发布报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra Android 发布"
    echo "=========================================="
    echo ""
    
    validate_track
    find_aab_file
    pre_release_validation
    
    if check_api_config; then
        upload_with_fastlane
    else
        manual_upload_guide
    fi
    
    generate_release_report
    
    echo ""
    echo "=========================================="
    if [ "$DRY_RUN" = true ]; then
        log_success "Android 发布模拟完成！"
    else
        log_success "Android 发布流程完成！"
    fi
    echo "=========================================="
}

# 运行主函数
main "$@"
