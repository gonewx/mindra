#!/bin/bash
# Mindra iOS 签名资产导入（在 macOS 编译机上运行）
#
# 衔接位置：appuploader 在宿主 Linux 上产出 .p12 和 .mobileprovision，
# 这个脚本把它们装进编译机，让 xcodebuild 能用上，并把 Team ID 与
# profile 名写进 ios/Flutter/Signing.xcconfig。
#
# 设计取舍：证书装进**专用 keychain**（mindra-signing.keychain-db）而不是
# login keychain。好处有三个：
#   1. 不需要用户的登录密码，keychain 密码由脚本自己管
#   2. 签名资产与日常钥匙串隔离，--reset 可以整体删掉重来
#   3. 不会因为 login keychain 自动锁定导致 codesign 中途弹密码框
#      （SSH 里看不到那个弹窗，表现为编译莫名卡死）

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

KEYCHAIN_NAME="mindra-signing.keychain-db"
KEYCHAIN_PATH="$HOME/Library/Keychains/$KEYCHAIN_NAME"
KEYCHAIN_PW_FILE="$HOME/.mindra-signing-keychain-password"
SIGNING_XCCONFIG="ios/Flutter/Signing.xcconfig"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.gonewx.mindra.app}"

# Apple WWDR 中间证书（G3-G6，官网公开下载，随仓库同步）。
# 分发证书链向 WWDR，而这台离线编译机的 login keychain 里没有它 ——
# 缺了它 security find-identity 会报 "0 valid identities"（证书和私钥
# 都在，只是链条验证不过），codesign 也会找不到身份。
WWDR_CERT_DIR="scripts/apple-certs"

# Xcode 16 起 profile 目录搬到了 Developer/Xcode/UserData 下，旧位置有些工具还在读，
# 两边都写一份，成本只有几十 KB。
PROFILE_DIRS=(
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
    "$HOME/Library/MobileDevice/Provisioning Profiles"
)

show_help() {
    cat <<'EOF'
Mindra iOS 签名资产导入

用法: ./scripts/ios_signing_import.sh [选项]

选项:
  -h, --help              显示此帮助
  -c, --cert PATH         .p12 证书路径（appuploader 导出）
  -p, --profile PATH      .mobileprovision 路径（appuploader 下载）
  --password PW           .p12 密码；不传则交互输入
  --no-apply              只导入，不改写 Signing.xcconfig
  --reset                 删除专用 keychain 与已装 profile 后重新导入
  --status                只显示当前签名资产状态，不做改动
  --unlock                只解锁 keychain（含 GUI session），不做其他改动

密码也可以用环境变量 MINDRA_P12_PASSWORD 传入，避免落进 shell history。

示例:
  ./scripts/ios_signing_import.sh --status
  ./scripts/ios_signing_import.sh -c ~/transfer/dist.p12 -p ~/transfer/mindra.mobileprovision
EOF
}

CERT_PATH=""; PROFILE_PATH=""; P12_PASSWORD="${MINDRA_P12_PASSWORD:-}"
APPLY_XCCONFIG=true; DO_RESET=false; STATUS_ONLY=false; UNLOCK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)    show_help; exit 0 ;;
        -c|--cert)    CERT_PATH="$2"; shift 2 ;;
        -p|--profile) PROFILE_PATH="$2"; shift 2 ;;
        --password)   P12_PASSWORD="$2"; shift 2 ;;
        --no-apply)   APPLY_XCCONFIG=false; shift ;;
        --reset)      DO_RESET=true; shift ;;
        --status)     STATUS_ONLY=true; shift ;;
        --unlock)     UNLOCK_ONLY=true; shift ;;
        *) log_error "未知参数: $1"; show_help; exit 1 ;;
    esac
done

check_environment() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "本脚本必须在 macOS 编译机上运行（当前: ${OSTYPE}）"
        log_info "宿主 Linux 上请改用: mise run ios:vm:signing:import"
        exit 1
    fi
    if [ ! -d "ios/Runner.xcodeproj" ]; then
        log_error "请在 Flutter 项目根目录运行（找不到 ios/Runner.xcodeproj）"
        exit 1
    fi
}

# ---- keychain 密码：本地随机生成一次，之后复用 ------------------------------
ensure_keychain_password() {
    if [ ! -f "$KEYCHAIN_PW_FILE" ]; then
        log_info "首次运行，生成专用 keychain 密码: $KEYCHAIN_PW_FILE"
        umask 077
        LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 > "$KEYCHAIN_PW_FILE"
        chmod 600 "$KEYCHAIN_PW_FILE"
    fi
    KEYCHAIN_PASSWORD="$(cat "$KEYCHAIN_PW_FILE")"
}

# ---- 解锁 keychain（含 GUI session）-----------------------------------------
# macOS 按 audit session 隔离 keychain 的锁定状态：SSH 登录是独立 session，
# 在 SSH 里解的锁对 GUI(Aqua) session 里的 Xcode / appuploader 完全无效，反之
# 亦然。而专用 keychain 不像 login keychain 会随图形登录自动解锁 —— 只要 VM
# 挂起恢复、注销重登或 securityd 重启，它就回到锁定状态。此时 codesign 访问
# 私钥：SSH 里报 errSecInternalComponent / "User interaction is not allowed"，
# GUI 里则弹出 "codesign wants to use the mindra-signing keychain" 密码框。
# 注意：set-key-partition-list 授权的是「已解锁钥匙串内私钥的免授权访问」，
# 它不能替代解锁本身，所以那步做对了也照样会弹。
unlock_signing_keychain() {
    [ -f "$KEYCHAIN_PATH" ] || return 0
    ensure_keychain_password

    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME" \
        || { log_error "解锁 $KEYCHAIN_NAME 失败（密码文件可能与 keychain 不匹配）"; return 1; }
    log_success "已解锁当前 session 的 $KEYCHAIN_NAME"

    # 再把解锁注入 GUI 登录用户的 session，这样 Xcode / appuploader 也不弹框。
    local console_user uid
    console_user=$(stat -f "%Su" /dev/console 2>/dev/null || true)
    if [ -z "$console_user" ] || [ "$console_user" = "root" ]; then
        log_info "无图形界面登录用户，跳过 GUI session 解锁"
        return 0
    fi
    uid=$(id -u "$console_user" 2>/dev/null) || return 0

    # launchctl asuser 需要 root。没有免密 sudo 时不让整条链路失败，只给指引。
    if ! sudo -n true 2>/dev/null; then
        log_warning "无免密 sudo，无法解锁 GUI session —— Xcode 里可能仍会弹密码框"
        log_info "如遇弹框，在编译机图形界面的终端里执行："
        log_info "  security unlock-keychain -p \"\$(cat $KEYCHAIN_PW_FILE)\" $KEYCHAIN_NAME"
        return 0
    fi

    if sudo -n launchctl asuser "$uid" \
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>/dev/null; then
        # 变量名后紧跟全角括号必须写成 ${}：macOS 自带 bash 3.2 会把多字节字符的
        # 首字节并进变量名，配合 set -u 直接报 unbound variable。
        log_success "已解锁 GUI session（用户 ${console_user}）的 keychain，Xcode / appuploader 可用"
    else
        log_warning "GUI session 解锁失败，Xcode 里可能仍会弹密码框"
    fi
}

reset_signing_assets() {
    log_warning "重置签名资产..."
    if security list-keychains -d user | grep -q "$KEYCHAIN_NAME"; then
        # 先从搜索列表摘掉，再删文件，否则残留条目会让后续 security 命令报错
        local remaining
        remaining=$(security list-keychains -d user | tr -d '"' | grep -v "$KEYCHAIN_NAME" || true)
        # shellcheck disable=SC2086
        security list-keychains -d user -s $remaining
    fi
    security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
    rm -f "$KEYCHAIN_PATH"
    for dir in "${PROFILE_DIRS[@]}"; do
        rm -f "$dir"/*.mobileprovision 2>/dev/null || true
    done
    log_success "已清除专用 keychain 与所有已装 profile"
}

# ---- 导入 .p12 --------------------------------------------------------------
import_certificate() {
    [ -n "$CERT_PATH" ] || return 0

    if [ ! -f "$CERT_PATH" ]; then
        log_error ".p12 文件不存在: $CERT_PATH"
        exit 1
    fi

    if [ -z "$P12_PASSWORD" ]; then
        # mise/CI 环境下 stdin 不是终端，read -s 会失败并被 set -e 静默吞掉，
        # 表现为脚本无声退出。这里显式检测并报可诊断的错误。
        if [ ! -t 0 ]; then
            log_error "stdin 不是终端，无法交互输入 .p12 密码"
            log_info "请用 --password PW 参数或 MINDRA_P12_PASSWORD 环境变量传入"
            exit 1
        fi
        read -r -s -p "请输入 .p12 密码: " P12_PASSWORD; echo
    fi

    ensure_keychain_password

    if [ ! -f "$KEYCHAIN_PATH" ]; then
        log_info "创建专用 keychain: $KEYCHAIN_NAME"
        security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    fi

    # 无参数的 set-keychain-settings = 关闭超时自动锁定。
    # 漏了这步，长时间编译中途 keychain 会锁，codesign 卡在看不见的密码框上。
    # 注意顺序必须先 unlock 再 set-keychain-settings：keychain 锁定时改设置
    # 会想弹 UI，SSH 会话里没有窗口服务，报 "User interaction is not allowed"。
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    security set-keychain-settings "$KEYCHAIN_NAME"

    # 把专用 keychain 加进用户搜索列表，同时保留原有条目（-s 是替换语义，
    # 不带上 login.keychain-db 会让其他工具突然找不到钥匙串）
    if ! security list-keychains -d user | grep -q "$KEYCHAIN_NAME"; then
        local existing
        existing=$(security list-keychains -d user | tr -d '"')
        # shellcheck disable=SC2086
        security list-keychains -d user -s $existing "$KEYCHAIN_PATH"
    fi

    log_info "导入证书..."
    security import "$CERT_PATH" \
        -k "$KEYCHAIN_PATH" \
        -P "$P12_PASSWORD" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        -T /usr/bin/productsign

    # 授权 codesign 非交互读取私钥。-k 这里要的是 keychain 密码，不是 .p12 密码 ——
    # 这两个搞混是本环节最常见的失败原因。
    security set-key-partition-list \
        -S apple-tool:,apple:,codesign: \
        -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

    log_success "证书已导入 $KEYCHAIN_NAME"
}

# ---- 导入 WWDR 中间证书 ------------------------------------------------------
import_wwdr_certs() {
    [ -f "$KEYCHAIN_PATH" ] || return 0
    # 每个 SSH 会话的 keychain 锁定状态独立，这里要自己解锁
    ensure_keychain_password
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    local n=0
    for cer in "$WWDR_CERT_DIR"/AppleWWDRCAG*.cer; do
        [ -f "$cer" ] || continue
        # 重复导入已存在的证书会报错，属预期，忽略即可
        security import "$cer" -k "$KEYCHAIN_PATH" 2>/dev/null || true
        n=$((n + 1))
    done
    if [ "$n" -gt 0 ]; then
        log_info "已确保 $n 个 WWDR 中间证书在 keychain 里（链条验证用）"
    fi
}

# ---- 导入 .mobileprovision -------------------------------------------------
PROFILE_NAME=""; PROFILE_UUID=""; PROFILE_TEAM=""; PROFILE_EXPIRY=""; PROFILE_APPID=""
PROFILE_TYPE="appstore"   # development | adhoc | appstore，由 parse_profile 按 profile 内容判断

parse_profile() {
    local path="$1" plist
    plist=$(mktemp /tmp/mindra-profile.XXXXXX.plist)
    # .mobileprovision 是 CMS 签名过的 plist，得先解出明文
    security cms -D -i "$path" -o "$plist" 2>/dev/null || {
        log_error "无法解析 profile（不是有效的 .mobileprovision？）: $path"
        rm -f "$plist"; exit 1
    }
    PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" "$plist" 2>/dev/null || echo "")
    PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print :UUID" "$plist" 2>/dev/null || echo "")
    PROFILE_TEAM=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$plist" 2>/dev/null || echo "")
    PROFILE_EXPIRY=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$plist" 2>/dev/null || echo "")
    PROFILE_APPID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$plist" 2>/dev/null || echo "")
    # 类型判断：get-task-allow=true 是开发签名（真机调试）；带设备列表的是 AdHoc 分发；
    # 其余是 App Store 分发。
    local gta
    gta=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:get-task-allow" "$plist" 2>/dev/null || echo "")
    if [ "$gta" = "true" ]; then
        PROFILE_TYPE="development"
    elif /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$plist" >/dev/null 2>&1; then
        PROFILE_TYPE="adhoc"
    else
        PROFILE_TYPE="appstore"
    fi
    rm -f "$plist"
}

import_profile() {
    [ -n "$PROFILE_PATH" ] || return 0

    if [ ! -f "$PROFILE_PATH" ]; then
        log_error "profile 文件不存在: $PROFILE_PATH"
        exit 1
    fi

    parse_profile "$PROFILE_PATH"

    log_info "Profile 名称: $PROFILE_NAME"
    log_info "Profile UUID: $PROFILE_UUID"
    log_info "Profile 类型: $PROFILE_TYPE"
    log_info "Team ID:      $PROFILE_TEAM"
    log_info "过期时间:     $PROFILE_EXPIRY"
    log_info "App ID:       $PROFILE_APPID"

    # Bundle ID 校验：application-identifier 形如 TEAMID.com.gonewx.mindra.app
    if [ -n "$PROFILE_APPID" ] && [[ "$PROFILE_APPID" != *".$BUNDLE_ID" ]]; then
        log_error "profile 的 App ID 与项目 Bundle ID 不匹配"
        log_error "  profile: $PROFILE_APPID"
        log_error "  期望后缀: .$BUNDLE_ID"
        exit 1
    fi

    # 有效期能反推账号类型：7 天说明是免费账号签的，做不了 App Store 分发
    if [ -n "$PROFILE_EXPIRY" ]; then
        local expiry_epoch now_epoch days_left
        expiry_epoch=$(date -j -f "%a %b %d %T %Z %Y" "$PROFILE_EXPIRY" "+%s" 2>/dev/null || echo "")
        if [ -n "$expiry_epoch" ]; then
            now_epoch=$(date "+%s")
            days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            if [ "$days_left" -lt 0 ]; then
                log_error "profile 已过期（${PROFILE_EXPIRY}），请在 appuploader 里重新创建"
                exit 1
            elif [ "$days_left" -le 14 ]; then
                log_warning "profile 仅剩 $days_left 天有效 —— 这通常意味着它由免费账号签发，"
                log_warning "免费账号无法做 App Store 分发。请确认用的是付费账号的 Team Key。"
            else
                log_info "剩余有效期: $days_left 天"
            fi
        fi
    fi

    for dir in "${PROFILE_DIRS[@]}"; do
        mkdir -p "$dir"
        # 必须用 UUID 当文件名，Xcode 是按 UUID 查找 profile 的
        cp "$PROFILE_PATH" "$dir/$PROFILE_UUID.mobileprovision"
    done
    log_success "profile 已安装（UUID 命名，共 ${#PROFILE_DIRS[@]} 个位置）"
}

# ---- 写回 Signing.xcconfig -------------------------------------------------
apply_xcconfig() {
    if [ "$APPLY_XCCONFIG" = false ] || [ -z "$PROFILE_NAME" ]; then
        return 0
    fi

    # profile 类型 → 目标签名 xcconfig（Debug 开发 / AdHoc 安装 / App Store 上架三者互不干扰）
    local target identity
    case "$PROFILE_TYPE" in
        development)
            target="ios/Flutter/Signing.debug.xcconfig"
            identity=$(signing_identity_name development)
            if [ -z "$identity" ]; then
                identity="Apple Development"
                log_warning "keychain 里没找到开发证书，Signing.debug.xcconfig 暂填默认值 $identity"
            fi
            ;;
        appstore)
            target="ios/Flutter/Signing.release.xcconfig"
            identity=$(signing_identity_name distribution)
            if [ -z "$identity" ]; then
                identity="Apple Distribution"
                log_warning "keychain 里没找到分发证书，Signing.release.xcconfig 暂填默认值 $identity"
            fi
            ;;
        *)
            target="ios/Flutter/Signing.xcconfig"
            identity=$(signing_identity_name distribution)
            if [ -z "$identity" ]; then
                identity="iPhone Distribution"
                log_warning "keychain 里没找到分发证书，Signing.xcconfig 暂填默认值 $identity"
            fi
            ;;
    esac

    log_info "写入 ${target}（profile 类型: ${PROFILE_TYPE}）"
    cat > "$target" <<EOF
// 由 scripts/ios_signing_import.sh 自动生成，请勿手工编辑。
// 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
// 来源 profile: $PROFILE_NAME ($PROFILE_UUID)
// 类型: $PROFILE_TYPE
// 本文件已被 .gitignore 排除。

MINDRA_CODE_SIGN_IDENTITY = $identity
MINDRA_DEVELOPMENT_TEAM = $PROFILE_TEAM
MINDRA_PROVISIONING_PROFILE = $PROFILE_NAME
EOF
    log_success "签名参数已写入（${PROFILE_TYPE} → ${target}）"
}

# ---- 安装「登录自动解锁」LaunchAgent -----------------------------------------
# 专用 keychain 不像 login keychain 那样登录时自动解锁，于是 Xcode（GUI 会话）里
# 每次 codesign 都因 keychain 锁定而弹密码框。这里在 ~/Library/LaunchAgents 生成一个
# 登录即解锁的 agent 并立即加载（RunAtLoad 当前也生效）。幂等：重复执行先卸载旧的再重装。
# 注意：SSH 与 GUI 是独立 audit session，本 agent 装在 gui/UID 域，只覆盖 Xcode/GUI；
# CLI 链路（flutter build ipa）由 --unlock 在 SSH 会话解锁，不需要它。
install_unlock_agent() {
    [ -f "$KEYCHAIN_PW_FILE" ] || return 0
    local agent_dir="$HOME/Library/LaunchAgents"
    local label="com.mindra.signing-unlock"
    local script="$agent_dir/$label.sh"
    local plist="$agent_dir/$label.plist"

    mkdir -p "$agent_dir"

    cat > "$script" <<'EOF'
#!/bin/bash
# Mindra: 登录时自动解锁签名 keychain，避免 Xcode codesign 反复弹密码框。
# 由 scripts/ios_signing_import.sh 自动安装。改动请同时改那个脚本。
PW_FILE="$HOME/.mindra-signing-keychain-password"
KEYCHAIN="mindra-signing.keychain-db"
[ -f "$PW_FILE" ] || exit 0
PW="$(cat "$PW_FILE")"
/usr/bin/security unlock-keychain -p "$PW" "$KEYCHAIN" 2>/dev/null \
  || /usr/bin/security unlock-keychain -p "$PW" "$HOME/Library/Keychains/$KEYCHAIN" 2>/dev/null \
  || true
EOF
    chmod +x "$script"

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$script</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/$label.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/$label.log</string>
</dict>
</plist>
EOF

    # 装载到 GUI 会话（RunAtLoad 立即解锁一次）；老系统退回 load。幂等，先 bootout。
    local console_user uid
    console_user=$(stat -f "%Su" /dev/console 2>/dev/null || true)
    if [ -z "$console_user" ] || [ "$console_user" = "root" ]; then
        log_warning "无图形登录用户，跳过 LaunchAgent 装载（不影响 CLI 链路解锁）"
        return 0
    fi
    uid=$(id -u "$console_user" 2>/dev/null) || return 0
    launchctl bootout "gui/$uid/$label" 2>/dev/null || true
    if ! launchctl bootstrap "gui/$uid" "$plist" 2>/dev/null; then
        launchctl load -w "$plist" 2>/dev/null || true
    fi
    log_success "已安装登录解锁 agent（${label}）"
    log_info "Xcode 的 codesign 弹框应已消失；若 VM 挂起恢复后又锁，再跑一次 unlock 即可"
}

# 从 keychain 里取证书的完整名称，例如 "Apple Distribution: Some Name (TEAMID)"。
# ExportOptions 的 signingCertificate 用 "Apple Distribution" 这个前缀即可，
# 但要先确认证书真的在。development=Apple Development 证书；其他=分发证书。
signing_identity_name() {
    local kind="${1:-distribution}"
    local pattern
    if [ "$kind" = "development" ]; then
        pattern='(Apple Development|iPhone Developer)[^"]*'
    else
        pattern='(Apple Distribution|iPhone Distribution)[^"]*'
    fi
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -oE "\"${pattern}\"" \
        | head -n 1 | tr -d '"' | cut -d: -f1 || true
}

show_status() {
    echo ""
    echo "=========================================="
    echo "        Mindra iOS 签名资产状态"
    echo "=========================================="

    echo ""
    echo "[专用 keychain]"
    if [ -f "$KEYCHAIN_PATH" ]; then
        echo "  ✅ $KEYCHAIN_PATH"
        if security list-keychains -d user | grep -q "$KEYCHAIN_NAME"; then
            echo "  ✅ 已在用户搜索列表中"
        else
            echo "  ⚠️  不在搜索列表中，xcodebuild 找不到里面的证书"
        fi
    else
        echo "  ❌ 未创建"
    fi

    echo ""
    echo "[代码签名身份]"
    local identities
    identities=$(security find-identity -v -p codesigning 2>/dev/null | grep -E '^\s+[0-9]+\)' || true)
    if [ -n "$identities" ]; then
        echo "$identities" | sed 's/^/  /'
    else
        echo "  ❌ 没有任何可用签名身份"
    fi

    echo ""
    echo "[已安装 profile]"
    local found=0
    for dir in "${PROFILE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r p; do
                [ -n "$p" ] || continue
                parse_profile "$p"
                echo "  • $PROFILE_NAME"
                echo "      UUID: $PROFILE_UUID  Team: $PROFILE_TEAM"
                echo "      过期: $PROFILE_EXPIRY"
                echo "      位置: $dir"
                found=$((found + 1))
            done < <(find "$dir" -maxdepth 1 -name '*.mobileprovision' 2>/dev/null)
        fi
    done
    [ "$found" -gt 0 ] || echo "  ❌ 未安装任何 profile"

    echo ""
    echo "[Signing.xcconfig]"
    if [ -f "$SIGNING_XCCONFIG" ]; then
        grep -E '^MINDRA_' "$SIGNING_XCCONFIG" | sed 's/^/  /'
        if grep -qE '^MINDRA_DEVELOPMENT_TEAM\s*=\s*$' "$SIGNING_XCCONFIG"; then
            echo "  ⚠️  Team ID 为空，archive 会失败"
        fi
    else
        echo "  ❌ 不存在（从 Signing.xcconfig.example 复制或跑一次导入）"
    fi
    echo ""
    echo "=========================================="
}

main() {
    check_environment

    if [ "$UNLOCK_ONLY" = true ]; then
        if [ ! -f "$KEYCHAIN_PATH" ]; then
            log_error "专用 keychain 不存在，先跑一次导入：--cert/--profile"
            exit 1
        fi
        # 这里不能落到 ensure_keychain_password 的"随机生成"分支上 —— 新密码
        # 解不开已有 keychain，只会得到一个更难懂的失败。
        if [ ! -f "$KEYCHAIN_PW_FILE" ]; then
            log_error "keychain 密码文件丢失: $KEYCHAIN_PW_FILE"
            log_info "无法解锁已有 keychain，需要重新导入：--reset -c <p12> -p <profile>"
            exit 1
        fi
        unlock_signing_keychain
        install_unlock_agent
        exit 0
    fi

    if [ "$STATUS_ONLY" = true ]; then
        show_status; exit 0
    fi

    [ "$DO_RESET" = false ] || reset_signing_assets

    if [ -z "$CERT_PATH" ] && [ -z "$PROFILE_PATH" ] && [ "$DO_RESET" = false ]; then
        log_error "至少要指定 --cert 或 --profile"
        echo ""
        show_help
        exit 1
    fi

    import_certificate
    import_wwdr_certs
    import_profile
    apply_xcconfig
    install_unlock_agent
    show_status
}

main "$@"
