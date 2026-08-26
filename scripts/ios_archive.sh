#!/bin/bash
# Mindra iOS Archive 构建脚本（在 macOS 编译机上运行）
#
# 衔接位置：签名资产已由 ios_signing_import.sh 装好、Signing.xcconfig 已
# 填值，本脚本读这些配置生成 ExportOptions.plist，产出签名好的 IPA。
# IPA 由 scripts/ios_sync.sh 回传宿主，再由 appuploader 上传 TestFlight。
#
# 版本号方案（已与维护者确认）：
#   - marketing version 取 pubspec.yaml 的 version（当前 1.0.0）
#   - build number 独立计数，读 ios/build_number.txt，从 1 重新起算，
#     与 pubspec 的 +7 本地构建计数无关（pubspec 的 + 号部分不用于 iOS）
#   - TestFlight 要求同 version 下 build number 严格递增：发新构建前
#     跑 mise run ios:build:bump

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

SIGNING_XCCONFIG="ios/Flutter/Signing.xcconfig"
EXPORT_TEMPLATE="ios/ExportOptions.plist.template"
GENERATED_EXPORT="build/ios/ExportOptions.plist"
BUILD_NUMBER_FILE="ios/build_number.txt"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.gonewx.mindra.app}"

show_help() {
    cat <<'EOF'
Mindra iOS Archive 构建（签名 + 导出 IPA）

用法: ./scripts/ios_archive.sh [选项]

选项:
  -h, --help        显示此帮助
  -c, --clean       构建前 flutter clean
  --build N         覆盖 build number（不写回 build_number.txt）
  --skip-verify     跳过产物校验

前置条件:
  1. ios/Flutter/Signing.xcconfig 存在且三个变量非空
     （由 ios_signing_import.sh 生成，或从 .example 复制手填）
  2. mise run ios:signing:status 确认证书与 profile 已装

产物: build/ios/ipa/*.ipa
EOF
}

CLEAN=false; BUILD_OVERRIDE=""; SKIP_VERIFY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)      show_help; exit 0 ;;
        -c|--clean)     CLEAN=true; shift ;;
        --build)        BUILD_OVERRIDE="$2"; shift 2 ;;
        --skip-verify)  SKIP_VERIFY=true; shift ;;
        *) log_error "未知参数: $1"; show_help; exit 1 ;;
    esac
done

check_environment() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "本脚本必须在 macOS 编译机上运行（当前: $OSTYPE）"
        log_info "宿主 Linux 上请用: mise run ios:vm:archive"
        exit 1
    fi
    if [ ! -d "ios/Runner.xcodeproj" ]; then
        log_error "请在 Flutter 项目根目录运行"
        exit 1
    fi
    command -v flutter >/dev/null || { log_error "flutter 不在 PATH"; exit 1; }
}

# ---- 读签名配置 ------------------------------------------------------------
read_signing_config() {
    if [ ! -f "$SIGNING_XCCONFIG" ]; then
        log_error "缺少 $SIGNING_XCCONFIG"
        log_info "先在宿主 Linux 上跑: mise run ios:vm:signing:import"
        log_info "（或手动: cp ios/Flutter/Signing.xcconfig.example 并填值）"
        exit 1
    fi
    SIGN_IDENTITY=$(sed -n 's/^MINDRA_CODE_SIGN_IDENTITY *= *//p' "$SIGNING_XCCONFIG" | tr -d '[:space:]')
    SIGN_TEAM=$(sed -n 's/^MINDRA_DEVELOPMENT_TEAM *= *//p' "$SIGNING_XCCONFIG" | tr -d '[:space:]')
    SIGN_PROFILE=$(sed -n 's/^MINDRA_PROVISIONING_PROFILE *= *//p' "$SIGNING_XCCONFIG")

    local missing=()
    [ -z "$SIGN_IDENTITY" ] && missing+=("MINDRA_CODE_SIGN_IDENTITY")
    [ -z "$SIGN_TEAM" ] && missing+=("MINDRA_DEVELOPMENT_TEAM")
    [ -z "$SIGN_PROFILE" ] && missing+=("MINDRA_PROVISIONING_PROFILE")
    if [ "${#missing[@]}" -gt 0 ]; then
        log_error "Signing.xcconfig 中以下变量为空: ${missing[*]}"
        log_info "重新跑一次签名导入即可: mise run ios:vm:signing:import"
        exit 1
    fi
    log_info "签名身份:  $SIGN_IDENTITY"
    log_info "Team ID:   $SIGN_TEAM"
    log_info "Profile:   $SIGN_PROFILE"
}

# ---- 版本号 ----------------------------------------------------------------
read_versions() {
    MARKETING_VERSION=$(sed -n 's/^version: *//p' pubspec.yaml | cut -d'+' -f1 | tr -d '[:space:]')
    if [ -z "$MARKETING_VERSION" ]; then
        log_error "无法从 pubspec.yaml 解析 version"
        exit 1
    fi
    if [ -n "$BUILD_OVERRIDE" ]; then
        BUILD_NUMBER="$BUILD_OVERRIDE"
    else
        BUILD_NUMBER=$(tr -d '[:space:]' < "$BUILD_NUMBER_FILE" 2>/dev/null || true)
    fi
    if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
        log_error "build number 无效: '$BUILD_NUMBER'（$BUILD_NUMBER_FILE 内容应是纯数字）"
        exit 1
    fi
    log_info "版本: $MARKETING_VERSION (build $BUILD_NUMBER)"
}

# ---- 生成 ExportOptions.plist ----------------------------------------------
generate_export_options() {
    if [ ! -f "$EXPORT_TEMPLATE" ]; then
        log_error "缺少模板 $EXPORT_TEMPLATE"
        exit 1
    fi
    mkdir -p build/ios
    sed -e "s/__MINDRA_DEVELOPMENT_TEAM__/$SIGN_TEAM/g" \
        -e "s/__MINDRA_CODE_SIGN_IDENTITY__/$SIGN_IDENTITY/g" \
        -e "s/__MINDRA_PROVISIONING_PROFILE__/$SIGN_PROFILE/g" \
        -e "s/__MINDRA_BUNDLE_ID__/$BUNDLE_ID/g" \
        "$EXPORT_TEMPLATE" > "$GENERATED_EXPORT"

    # macOS 上 plist 可校验，坏模板早暴露早失败
    if ! plutil -lint "$GENERATED_EXPORT" >/dev/null; then
        log_error "生成的 ExportOptions.plist 不是合法 plist"
        exit 1
    fi
    log_info "已生成 $GENERATED_EXPORT"
}

# ---- 构建 ------------------------------------------------------------------
do_build() {
    if [ "$CLEAN" = true ]; then
        log_info "flutter clean..."
        flutter clean >/dev/null
        flutter pub get >/dev/null
    else
        flutter pub get >/dev/null
    fi

    log_info "开始构建 IPA（约 1-3 分钟）..."
    flutter build ipa --release \
        --build-name="$MARKETING_VERSION" \
        --build-number="$BUILD_NUMBER" \
        --export-options-plist="$GENERATED_EXPORT"

    IPA_PATH=$(find build/ios/ipa -maxdepth 1 -name '*.ipa' -print 2>/dev/null | head -n 1)
    if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
        log_error "构建命令成功但没找到 IPA，检查 build/ios/ipa/"
        exit 1
    fi
    log_success "IPA: $IPA_PATH ($(du -h "$IPA_PATH" | cut -f1))"
}

# ---- 产物校验 --------------------------------------------------------------
verify_ipa() {
    [ "$SKIP_VERIFY" = false ] || { log_warning "跳过产物校验"; return 0; }

    log_info "校验产物..."
    local app_plist
    app_plist=$(unzip -p "$IPA_PATH" "Payload/*.app/Info.plist" 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null || true)
    if [ -z "$app_plist" ]; then
        log_error "读不到 IPA 里的 Info.plist"
        exit 1
    fi

    local got_id got_ver got_build
    got_id=$(echo "$app_plist" | plutil -extract CFBundleIdentifier raw -o - - 2>/dev/null)
    got_ver=$(echo "$app_plist" | plutil -extract CFBundleShortVersionString raw -o - - 2>/dev/null)
    got_build=$(echo "$app_plist" | plutil -extract CFBundleVersion raw -o - - 2>/dev/null)

    if [ "$got_id" != "$BUNDLE_ID" ]; then
        log_error "Bundle ID 不匹配: 期望 $BUNDLE_ID，实际 $got_id"
        exit 1
    fi
    if [ "$got_ver" != "$MARKETING_VERSION" ] || [ "$got_build" != "$BUILD_NUMBER" ]; then
        log_error "版本不匹配: 期望 $MARKETING_VERSION($BUILD_NUMBER)，实际 $got_ver($got_build)"
        log_info  "TestFlight 会拒收 version+build 重复或回退的包"
        exit 1
    fi
    log_info "Bundle ID / 版本号校验通过"

    # 确认导出的 embedded.mobileprovision 是分发 profile，且属于配置里的 Team
    local prof
    prof=$(unzip -p "$IPA_PATH" "Payload/*.app/embedded.mobileprovision" 2>/dev/null \
        | security cms -D -i /dev/stdin 2>/dev/null || true)
    if [ -n "$prof" ]; then
        local p_team p_name
        p_team=$(echo "$prof" | plutil -extract TeamIdentifier.0 raw -o - - 2>/dev/null || true)
        p_name=$(echo "$prof" | plutil -extract Name raw -o - - 2>/dev/null || true)
        if [ -n "$p_team" ] && [ "$p_team" != "$SIGN_TEAM" ]; then
            log_error "IPA 内 profile 的 Team ($p_team) 与配置 ($SIGN_TEAM) 不一致"
            exit 1
        fi
        log_info "分发 profile: $p_name (Team $p_team)"
    else
        log_warning "IPA 里没有 embedded.mobileprovision，跳过 Team 校验"
    fi
    log_success "产物校验通过"
}

main() {
    check_environment
    read_signing_config
    read_versions
    generate_export_options
    do_build
    verify_ipa

    echo ""
    echo "=========================================="
    log_success "构建完成"
    echo "  IPA: $IPA_PATH"
    echo "  版本: $MARKETING_VERSION ($BUILD_NUMBER)"
    echo ""
    echo "下一步:"
    echo "  宿主回传:  mise run ios:sync:back"
    echo "  上传 TestFlight: 在 appuploader 里选择回传的 IPA"
    echo "  发下一版前递增: mise run ios:build:bump"
    echo "=========================================="
}

main "$@"
