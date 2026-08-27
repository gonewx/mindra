#!/bin/bash
# Mindra 宿主 Linux ↔ macOS 编译机 同步脚本（在宿主上运行）
#
# 衔接位置：这是 Linux 与离线 Mac VM 之间唯一的通道。
#   去程  rsync 项目代码到 VM 的 ~/mindra
#   回程  rsync VM 产出的 IPA 回宿主 build/ios/ipa/（固定位置，
#         appuploader 每次都在这里选文件）
#   证书  把 appuploader 导出的 .p12 / .mobileprovision 送到 VM 并调
#         ios_signing_import.sh 完成导入（Team ID 由此写进 Signing.xcconfig）
#
# VM 侧安全前提：VM 已按“纯离线编译机”加固（/etc/hosts 阻断 Apple 端点）。
# 本脚本不往 VM 传任何需要联网的指令，所有联系 Apple 的动作都在宿主侧
# 由 appuploader 完成。

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;4m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

SSH_HOST="${MINDRA_VM_HOST:-imacvm-tahoe}"
VM_PROJECT_DIR="mindra"
LOCAL_IPA_DIR="build/ios/ipa"
# 注意：这是 VM 上的目录，相对路径以 VM 的 HOME 为基准。
# macOS 的 /home 是 autofs（auto_home）挂载点，不能 mkdir，所以绝不能把
# 宿主机的 $HOME（/home/decker）原样发给 VM 当绝对路径用。
TRANSFER_DIR="${MINDRA_TRANSFER_DIR:-mindra-transfer}"

# 给 VM 上导入脚本用的绝对路径：ssh 的 mkdir / scp 相对路径都落在远端 HOME 下，
# 但导入脚本在 `cd mindra` 之后运行，相对路径会解析错位，必须补上 ~。
vm_abs_path() {
    if [[ "$1" == /* ]]; then echo "$1"; else echo "~/$1"; fi
}

show_help() {
    cat <<EOF
Mindra 宿主 ↔ Mac 编译机 同步

用法: ./scripts/ios_sync.sh <命令> [选项]

命令:
  push        代码去程同步（宿主 → VM:~/mindra）
  pull        IPA 回程同步（VM:~/mindra/build/ios/ipa → 宿主）
  cert        递送签名资产到 VM 并导入
                -c PATH    .p12 文件
                -p PATH    .mobileprovision 文件
                --password PW   .p12 密码（或环境变量 MINDRA_P12_PASSWORD）
                --reset    让 VM 先清空旧签名资产
  status      查看 VM 编译环境状态（项目、证书、profile、磁盘）

环境变量:
  MINDRA_VM_HOST       SSH 别名（默认 imacvm-tahoe）
  MINDRA_TRANSFER_DIR  VM 中转目录（默认 ~/mindra-transfer）
EOF
}

need_ssh() {
    if ! ssh -o ConnectTimeout=8 -o BatchMode=yes "$SSH_HOST" true 2>/dev/null; then
        log_error "无法 SSH 到 $SSH_HOST（VM 没开？）"
        log_info "启动脚本: /mnt/disk0/project/mindra/mindra_cc/.build_usbmuxd/start-macos-tahoe.sh"
        exit 1
    fi
}

# ---- push：代码去程 ---------------------------------------------------------
cmd_push() {
    need_ssh
    # rsync 源是 ./，在错误目录运行会把别的目录同步过去并 --delete 掉 VM 上的项目
    if [ ! -f "pubspec.yaml" ] || [ ! -d "ios/Runner.xcodeproj" ]; then
        log_error "当前目录不是 Flutter 项目根目录（rsync 源是 ./，会同步错内容）"
        log_info "请在 mindra/ 目录下运行"
        exit 1
    fi
    log_info "同步代码到 $SSH_HOST:~/$VM_PROJECT_DIR ..."
    rsync -az --delete \
        --exclude '.git/' \
        --exclude 'build/' \
        --exclude '.dart_tool/' \
        --exclude 'ios/Pods/' \
        --exclude 'ios/.symlinks/' \
        --exclude 'ios/Flutter/Generated.xcconfig' \
        --exclude 'ios/Flutter/Signing.xcconfig' \
        --exclude 'ios/Flutter/ephemeral/' \
        --exclude 'ios/Signing.xcconfig' \
        --exclude 'macos/Flutter/ephemeral/' \
        --exclude 'android/.gradle/' \
        --exclude 'node_modules/' \
        --exclude 'coverage/' \
        --exclude '*.ipa' \
        ./ "$SSH_HOST:$VM_PROJECT_DIR/"
    log_success "代码已同步"
}

# ---- pull：IPA 回程 ---------------------------------------------------------
cmd_pull() {
    need_ssh
    log_info "从 VM 回收 IPA ..."
    mkdir -p "$LOCAL_IPA_DIR"

    local pulled=0
    # --ignore-existing 防止把本地已有的同名 IPA 覆盖掉（每次构建文件名一样时）
    if rsync -az --ignore-existing \
        "$SSH_HOST:$VM_PROJECT_DIR/build/ios/ipa/*.ipa" "$LOCAL_IPA_DIR/" 2>/dev/null; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            log_success "已回传: $f ($(du -h "$f" | cut -f1))"
            pulled=$((pulled + 1))
        done < <(find "$LOCAL_IPA_DIR" -maxdepth 1 -name '*.ipa' -mmin -60 -print)
    fi

    if [ "$pulled" -eq 0 ]; then
        log_warning "VM 上没有新 IPA（1 小时内未回传过任何文件）"
        log_info "先编译: mise run ios:vm:archive"
        exit 1
    fi

    echo ""
    log_info "给 appuploader 用的 IPA（在 appuploader 里选这个文件）:"
    find "$LOCAL_IPA_DIR" -maxdepth 1 -name '*.ipa' -printf '  %f (%k KB)\n' | sort
}

# ---- cert：签名资产递送 + VM 侧导入 ----------------------------------------
cmd_cert() {
    need_ssh
    local cert="" profile="" password="${MINDRA_P12_PASSWORD:-}" reset_flag=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c)         cert="$2"; shift 2 ;;
            -p)         profile="$2"; shift 2 ;;
            --password) password="$2"; shift 2 ;;
            --reset)    reset_flag="--reset"; shift ;;
            *) log_error "cert 子命令未知参数: $1"; show_help; exit 1 ;;
        esac
    done

    if [ -z "$cert" ] && [ -z "$profile" ]; then
        log_error "至少要 -c cert.p12 或 -p profile.mobileprovision"
        exit 1
    fi

    log_info "在中转目录放置签名资产 ..."
    ssh "$SSH_HOST" "mkdir -p '$TRANSFER_DIR'"
    local sent=()
    [ -z "$cert" ]    || { scp -q "$cert"    "$SSH_HOST:$TRANSFER_DIR/"; sent+=("$(basename "$cert")"); }
    [ -z "$profile" ] || { scp -q "$profile" "$SSH_HOST:$TRANSFER_DIR/"; sent+=("$(basename "$profile")"); }
    log_info "已送到 VM: ${sent[*]}"

    log_info "在 VM 上执行导入 ..."
    local vm_dir; vm_dir="$(vm_abs_path "$TRANSFER_DIR")"
    local args=("$reset_flag")
    [ -z "$cert" ]    || args+=(-c "$vm_dir/$(basename "$cert")")
    [ -z "$profile" ] || args+=(-p "$vm_dir/$(basename "$profile")")

    # 密码通过 stdin 传给远端脚本（read -s 读一行），不进进程列表与 history
    if [ -n "$password" ]; then
        printf '%s\n' "$password" | ssh -T "$SSH_HOST" \
            "cd $VM_PROJECT_DIR && MINDRA_P12_PASSWORD=\$(cat) ./scripts/ios_signing_import.sh ${args[*]}"
    else
        if [ ! -t 0 ] && [ -n "$cert" ]; then
            log_error "需要 .p12 密码，但当前 stdin 不是终端，无法交互输入"
            log_info "请加 --password PW 参数或设置 MINDRA_P12_PASSWORD 环境变量"
            exit 1
        fi
        # shellcheck disable=SC2029
        ssh -t "$SSH_HOST" "cd $VM_PROJECT_DIR && ./scripts/ios_signing_import.sh ${args[*]}"
    fi
    log_success "签名资产导入完成"
}

# ---- status ----------------------------------------------------------------
cmd_status() {
    need_ssh
    log_info "查询 VM 状态 ..."
    ssh "$SSH_HOST" bash -s <<'REMOTE'
        echo "=== 主机与 Xcode ==="
        sw_vers | head -2
        xcodebuild -version | head -2
        echo ""
        echo "=== 项目副本 ==="
        if [ -d ~/mindra/ios ]; then
            echo "✅ ~/mindra 存在"
            echo "  Flutter: $(cd ~/mindra && mise exec -- flutter --version 2>/dev/null | head -1 || echo '不可用')"
            echo "  podfile.lock: $(ls -la ~/mindra/ios/Podfile.lock 2>/dev/null | awk '{print $NF}')"
        else
            echo "❌ ~/mindra 不存在，先 mise run ios:sync:push"
        fi
        echo ""
        echo "=== 签名资产（mise run ios:vm:signing:status 可看详情）==="
        security find-identity -v -p codesigning 2>/dev/null | grep -E '^\s+[0-9]+\)' || echo "  （无签名身份）"
        echo ""
        echo "=== 最近 IPA ==="
        ls -lt ~/mindra/build/ios/ipa/*.ipa 2>/dev/null | head -3 || echo "  （无）"
        echo ""
        echo "=== 磁盘 ==="
        df -h / | tail -1 | awk '{print "  已用 " $3 " / 可用 " $4 "（" $5 "）"}'
REMOTE
}

# ---- 入口 -------------------------------------------------------------------
main() {
    if [ $# -eq 0 ]; then
        show_help; exit 1
    fi
    local cmd="$1"; shift
    case "$cmd" in
        push)   cmd_push ;;
        pull)   cmd_pull ;;
        cert)   cmd_cert "$@" ;;
        status) cmd_status ;;
        -h|--help|help) show_help ;;
        *) log_error "未知命令: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
