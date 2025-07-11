#!/bin/bash

# Mindra iOS 发布脚本
# 用于将构建好的 Archive 发布到 App Store Connect

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
    echo "Mindra iOS 发布脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -a, --archive PATH      指定 Archive 路径"
    echo "  -t, --testflight        上传到 TestFlight"
    echo "  -s, --store             上传到 App Store"
    echo "  --dry-run               模拟运行，不实际上传"
    echo "  --skip-validation       跳过预发布验证"
    echo ""
    echo "示例:"
    echo "  $0 -t                   上传到 TestFlight"
    echo "  $0 -s --dry-run         模拟上传到 App Store"
}

# 默认参数
ARCHIVE_PATH=""
UPLOAD_TO_TESTFLIGHT=false
UPLOAD_TO_STORE=false
DRY_RUN=false
SKIP_VALIDATION=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        -t|--testflight)
            UPLOAD_TO_TESTFLIGHT=true
            shift
            ;;
        -s|--store)
            UPLOAD_TO_STORE=true
            shift
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

# 检查环境
check_environment() {
    log_info "检查发布环境..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "iOS 发布需要在 macOS 上进行"
        exit 1
    fi
    
    # 检查 Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode 未安装或命令行工具未配置"
        exit 1
    fi
    
    # 检查 altool (Xcode 13+)
    if ! xcrun altool --help &> /dev/null; then
        log_error "altool 不可用，请确保 Xcode 版本 >= 13"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 查找 Archive 文件
find_archive() {
    if [ -z "$ARCHIVE_PATH" ]; then
        ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
    fi
    
    if [ ! -d "$ARCHIVE_PATH" ]; then
        log_error "Archive 文件不存在: $ARCHIVE_PATH"
        log_info "请先运行构建脚本: ./scripts/build_ios.sh -a"
        exit 1
    fi
    
    log_info "Archive 路径: $ARCHIVE_PATH"
    local size=$(du -sh "$ARCHIVE_PATH" | cut -f1)
    log_info "Archive 大小: $size"
}

# 验证 Archive
validate_archive() {
    if [ "$SKIP_VALIDATION" = true ]; then
        log_warning "跳过 Archive 验证"
        return
    fi
    
    log_info "验证 Archive..."
    
    # 检查 Archive 结构
    local info_plist="$ARCHIVE_PATH/Info.plist"
    if [ ! -f "$info_plist" ]; then
        log_error "Archive Info.plist 不存在"
        exit 1
    fi
    
    # 获取应用信息
    local app_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$info_plist" 2>/dev/null || echo "未知")
    local build_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$info_plist" 2>/dev/null || echo "未知")
    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "未知")
    
    log_info "应用版本: $app_version"
    log_info "构建版本: $build_version"
    log_info "Bundle ID: $bundle_id"
    
    # 验证 Bundle ID
    if [ "$bundle_id" != "com.mindra.app" ]; then
        log_error "Bundle ID 不匹配，期望: com.mindra.app，实际: $bundle_id"
        exit 1
    fi
    
    log_success "Archive 验证通过"
}

# 检查 App Store Connect API 配置
check_api_config() {
    log_info "检查 App Store Connect API 配置..."
    
    # 检查 API 密钥文件
    local api_key_file="ios/AuthKey_*.p8"
    if ! ls $api_key_file 1> /dev/null 2>&1; then
        log_warning "App Store Connect API 密钥文件不存在"
        log_info "请按照以下步骤配置:"
        log_info "1. 在 App Store Connect 中创建 API 密钥"
        log_info "2. 下载 .p8 文件到 ios/ 目录"
        log_info "3. 设置环境变量 APP_STORE_CONNECT_API_KEY_ID 和 APP_STORE_CONNECT_ISSUER_ID"
        return 1
    fi
    
    # 检查环境变量
    if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
        log_warning "App Store Connect API 环境变量未设置"
        return 1
    fi
    
    log_success "API 配置检查完成"
    return 0
}

# 导出 IPA
export_ipa() {
    log_info "导出 IPA 文件..."
    
    local export_path="build/ios/ipa"
    local ipa_path="$export_path/Runner.ipa"
    
    # 创建导出目录
    mkdir -p "$export_path"
    
    # 创建导出选项 plist
    local export_options_plist="$export_path/ExportOptions.plist"
    cat > "$export_options_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    log_info "正在导出 IPA，这可能需要几分钟..."
    
    if xcodebuild -exportArchive \
                  -archivePath "$ARCHIVE_PATH" \
                  -exportPath "$export_path" \
                  -exportOptionsPlist "$export_options_plist"; then
        log_success "IPA 导出成功"
        
        if [ -f "$ipa_path" ]; then
            local size=$(du -sh "$ipa_path" | cut -f1)
            log_info "IPA 文件: $ipa_path ($size)"
        fi
    else
        log_error "IPA 导出失败"
        exit 1
    fi
}

# 上传到 TestFlight
upload_to_testflight() {
    if [ "$UPLOAD_TO_TESTFLIGHT" = true ]; then
        log_info "上传到 TestFlight..."
        
        local ipa_path="build/ios/ipa/Runner.ipa"
        
        if [ ! -f "$ipa_path" ]; then
            export_ipa
        fi
        
        if [ "$DRY_RUN" = true ]; then
            log_info "模拟运行: 上传 $ipa_path 到 TestFlight"
            log_success "模拟上传完成"
            return
        fi
        
        # 使用 altool 上传
        if check_api_config; then
            # 使用 API 密钥上传
            local api_key_file=$(ls ios/AuthKey_*.p8 | head -n 1)
            
            if xcrun altool --upload-app \
                           --type ios \
                           --file "$ipa_path" \
                           --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
                           --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"; then
                log_success "TestFlight 上传成功"
            else
                log_error "TestFlight 上传失败"
                exit 1
            fi
        else
            # 使用应用专用密码上传
            log_info "使用应用专用密码上传..."
            log_warning "请确保已设置 APPLE_ID 和 APP_SPECIFIC_PASSWORD 环境变量"
            
            if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
                log_error "APPLE_ID 或 APP_SPECIFIC_PASSWORD 环境变量未设置"
                exit 1
            fi
            
            if xcrun altool --upload-app \
                           --type ios \
                           --file "$ipa_path" \
                           --username "$APPLE_ID" \
                           --password "$APP_SPECIFIC_PASSWORD"; then
                log_success "TestFlight 上传成功"
            else
                log_error "TestFlight 上传失败"
                exit 1
            fi
        fi
    fi
}

# 上传到 App Store
upload_to_store() {
    if [ "$UPLOAD_TO_STORE" = true ]; then
        log_info "上传到 App Store..."
        log_warning "注意: 这将直接上传到 App Store，请确保应用已准备好发布"
        
        # 确认操作
        if [ "$DRY_RUN" = false ]; then
            read -p "确定要上传到 App Store 吗？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "取消上传"
                exit 0
            fi
        fi
        
        # 上传逻辑与 TestFlight 类似，但可能需要额外的元数据
        upload_to_testflight  # 复用上传逻辑
    fi
}

# 手动上传指导
manual_upload_guide() {
    log_info "手动上传指导:"
    echo ""
    echo "=========================================="
    echo "           手动上传到 App Store Connect"
    echo "=========================================="
    echo ""
    echo "方法一: 使用 Xcode"
    echo "1. 打开 Xcode"
    echo "2. 选择 Window > Organizer"
    echo "3. 选择 Archives 标签"
    echo "4. 找到 Mindra 应用的 Archive"
    echo "5. 点击 'Distribute App'"
    echo "6. 选择 'App Store Connect'"
    echo "7. 选择 'Upload'"
    echo "8. 按照向导完成上传"
    echo ""
    echo "方法二: 使用 Transporter 应用"
    echo "1. 从 Mac App Store 下载 Transporter"
    echo "2. 导出 IPA 文件"
    echo "3. 在 Transporter 中选择 IPA 文件"
    echo "4. 点击 'Deliver' 上传"
    echo ""
    echo "Archive 路径: $ARCHIVE_PATH"
    if [ -f "build/ios/ipa/Runner.ipa" ]; then
        echo "IPA 路径: build/ios/ipa/Runner.ipa"
    fi
    echo ""
    echo "=========================================="
}

# 生成发布报告
generate_release_report() {
    log_info "生成发布报告..."
    
    local report_file="release_report_ios_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "           Mindra iOS 发布报告"
        echo "=========================================="
        echo "发布时间: $(date)"
        echo "Archive 路径: $ARCHIVE_PATH"
        echo "上传到 TestFlight: $UPLOAD_TO_TESTFLIGHT"
        echo "上传到 App Store: $UPLOAD_TO_STORE"
        echo "模拟运行: $DRY_RUN"
        echo ""
        
        # 应用信息
        local info_plist="$ARCHIVE_PATH/Info.plist"
        if [ -f "$info_plist" ]; then
            echo "应用信息:"
            local app_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$info_plist" 2>/dev/null || echo "未知")
            local build_version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$info_plist" 2>/dev/null || echo "未知")
            local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "未知")
            
            echo "  Bundle ID: $bundle_id"
            echo "  应用版本: $app_version"
            echo "  构建版本: $build_version"
        fi
        
        echo ""
        echo "文件信息:"
        local archive_size=$(du -sh "$ARCHIVE_PATH" | cut -f1)
        echo "  Archive 大小: $archive_size"
        
        if [ -f "build/ios/ipa/Runner.ipa" ]; then
            local ipa_size=$(du -sh "build/ios/ipa/Runner.ipa" | cut -f1)
            echo "  IPA 大小: $ipa_size"
        fi
        
        echo ""
        echo "下一步操作:"
        if [ "$UPLOAD_TO_TESTFLIGHT" = true ]; then
            echo "  1. 在 App Store Connect 中查看构建状态"
            echo "  2. 等待处理完成（通常需要几分钟）"
            echo "  3. 添加测试者并开始内部测试"
            echo "  4. 收集反馈并准备正式发布"
        else
            echo "  1. 手动上传 Archive 或 IPA"
            echo "  2. 在 App Store Connect 中配置应用信息"
            echo "  3. 提交审核"
        fi
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_success "发布报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "           Mindra iOS 发布"
    echo "=========================================="
    echo ""
    
    # 如果没有指定上传目标，默认为 TestFlight
    if [ "$UPLOAD_TO_TESTFLIGHT" = false ] && [ "$UPLOAD_TO_STORE" = false ]; then
        UPLOAD_TO_TESTFLIGHT=true
        log_info "未指定上传目标，默认上传到 TestFlight"
    fi
    
    check_environment
    find_archive
    validate_archive
    upload_to_testflight
    upload_to_store
    
    # 如果没有成功上传，显示手动上传指导
    if [ "$DRY_RUN" = true ] || ! check_api_config; then
        manual_upload_guide
    fi
    
    generate_release_report
    
    echo ""
    echo "=========================================="
    if [ "$DRY_RUN" = true ]; then
        log_success "iOS 发布模拟完成！"
    else
        log_success "iOS 发布流程完成！"
    fi
    echo "=========================================="
}

# 运行主函数
main "$@"
