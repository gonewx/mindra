#!/bin/bash

# Mindra 版本管理脚本
# 用于管理应用版本号和构建号

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
    echo "Mindra 版本管理脚本"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  show                    显示当前版本信息"
    echo "  set VERSION             设置指定版本号"
    echo "  bump TYPE               递增版本号"
    echo "  build-bump              仅递增构建号"
    echo "  tag                     创建 Git 标签"
    echo "  history                 显示版本历史"
    echo ""
    echo "递增类型 (TYPE):"
    echo "  major                   主版本号 (1.0.0 -> 2.0.0)"
    echo "  minor                   次版本号 (1.0.0 -> 1.1.0)"
    echo "  patch                   补丁版本号 (1.0.0 -> 1.0.1)"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  --dry-run               模拟运行，不实际修改"
    echo "  --no-git                不创建 Git 提交"
    echo ""
    echo "示例:"
    echo "  $0 show                 显示当前版本"
    echo "  $0 set 1.2.0+5          设置版本为 1.2.0 构建号 5"
    echo "  $0 bump patch           递增补丁版本号"
    echo "  $0 build-bump           仅递增构建号"
    echo "  $0 tag                  为当前版本创建 Git 标签"
}

# 默认参数
COMMAND=""
VERSION=""
DRY_RUN=false
NO_GIT=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-git)
            NO_GIT=true
            shift
            ;;
        show|set|bump|build-bump|tag|history)
            COMMAND="$1"
            shift
            ;;
        major|minor|patch)
            if [ "$COMMAND" = "bump" ]; then
                VERSION="$1"
            else
                log_error "版本类型只能在 bump 命令中使用"
                exit 1
            fi
            shift
            ;;
        *)
            if [ "$COMMAND" = "set" ] && [ -z "$VERSION" ]; then
                VERSION="$1"
            else
                log_error "未知参数: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查命令
if [ -z "$COMMAND" ]; then
    log_error "请指定命令"
    show_help
    exit 1
fi

# 获取当前版本信息
get_current_version() {
    if [ ! -f "pubspec.yaml" ]; then
        log_error "pubspec.yaml 文件不存在"
        exit 1
    fi
    
    local version_line=$(grep "^version:" pubspec.yaml | head -n 1)
    if [ -z "$version_line" ]; then
        log_error "无法在 pubspec.yaml 中找到版本信息"
        exit 1
    fi
    
    echo $(echo "$version_line" | cut -d' ' -f2)
}

# 解析版本号
parse_version() {
    local version_full="$1"
    
    if [[ "$version_full" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
        BUILD=${BASH_REMATCH[4]}
    elif [[ "$version_full" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
        BUILD=1
    else
        log_error "无效的版本格式: $version_full"
        log_info "正确格式: 1.0.0 或 1.0.0+1"
        exit 1
    fi
}

# 显示版本信息
show_version() {
    local current_version=$(get_current_version)
    parse_version "$current_version"
    
    echo "=========================================="
    echo "           Mindra 版本信息"
    echo "=========================================="
    echo "当前版本: $current_version"
    echo "主版本号: $MAJOR"
    echo "次版本号: $MINOR"
    echo "补丁版本: $PATCH"
    echo "构建号:   $BUILD"
    echo ""
    
    # 显示平台特定信息
    echo "平台版本信息:"
    
    # Android 版本信息
    if [ -f "android/app/build.gradle.kts" ]; then
        echo "  Android:"
        echo "    versionName: $MAJOR.$MINOR.$PATCH"
        echo "    versionCode: $BUILD"
    fi
    
    # iOS 版本信息
    if [ -f "ios/Runner/Info.plist" ]; then
        echo "  iOS:"
        echo "    CFBundleShortVersionString: $MAJOR.$MINOR.$PATCH"
        echo "    CFBundleVersion: $BUILD"
    fi
    
    echo ""
    echo "=========================================="
}

# 设置版本号
set_version() {
    local new_version="$1"
    parse_version "$new_version"
    
    local current_version=$(get_current_version)
    
    log_info "设置版本号: $current_version -> $new_version"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "模拟运行: 将更新版本号到 $new_version"
        return
    fi
    
    # 备份原始文件
    cp pubspec.yaml pubspec.yaml.backup
    
    # 更新 pubspec.yaml
    sed -i.tmp "s/^version:.*/version: $new_version/" pubspec.yaml
    rm pubspec.yaml.tmp
    
    # 更新 iOS Info.plist
    if [ -f "ios/Runner/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MAJOR.$MINOR.$PATCH" ios/Runner/Info.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" ios/Runner/Info.plist 2>/dev/null || true
        log_info "已更新 iOS Info.plist"
    fi
    
    log_success "版本号已更新到: $new_version"
    
    # 创建 Git 提交
    if [ "$NO_GIT" = false ] && command -v git &> /dev/null; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            git add pubspec.yaml ios/Runner/Info.plist 2>/dev/null || true
            git commit -m "chore: bump version to $new_version" 2>/dev/null || true
            log_info "已创建 Git 提交"
        fi
    fi
}

# 递增版本号
bump_version() {
    local bump_type="$1"
    local current_version=$(get_current_version)
    parse_version "$current_version"
    
    local new_major=$MAJOR
    local new_minor=$MINOR
    local new_patch=$PATCH
    local new_build=$BUILD
    
    case $bump_type in
        major)
            ((new_major++))
            new_minor=0
            new_patch=0
            ((new_build++))
            ;;
        minor)
            ((new_minor++))
            new_patch=0
            ((new_build++))
            ;;
        patch)
            ((new_patch++))
            ((new_build++))
            ;;
        *)
            log_error "无效的递增类型: $bump_type"
            log_info "支持的类型: major, minor, patch"
            exit 1
            ;;
    esac
    
    local new_version="$new_major.$new_minor.$new_patch+$new_build"
    set_version "$new_version"
}

# 仅递增构建号
bump_build() {
    local current_version=$(get_current_version)
    parse_version "$current_version"
    
    local new_build=$((BUILD + 1))
    local new_version="$MAJOR.$MINOR.$PATCH+$new_build"
    
    set_version "$new_version"
}

# 创建 Git 标签
create_tag() {
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装"
        exit 1
    fi
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    local current_version=$(get_current_version)
    parse_version "$current_version"
    
    local tag_name="v$MAJOR.$MINOR.$PATCH"
    local tag_message="Release version $MAJOR.$MINOR.$PATCH (build $BUILD)"
    
    log_info "创建 Git 标签: $tag_name"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "模拟运行: 将创建标签 $tag_name"
        return
    fi
    
    # 检查标签是否已存在
    if git tag -l | grep -q "^$tag_name$"; then
        log_warning "标签 $tag_name 已存在"
        read -p "是否要删除现有标签并重新创建？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$tag_name"
            log_info "已删除现有标签"
        else
            log_info "取消创建标签"
            return
        fi
    fi
    
    # 创建标签
    git tag -a "$tag_name" -m "$tag_message"
    log_success "已创建标签: $tag_name"
    
    # 询问是否推送标签
    read -p "是否要推送标签到远程仓库？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "$tag_name"
        log_success "已推送标签到远程仓库"
    fi
}

# 显示版本历史
show_history() {
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装，无法显示版本历史"
        exit 1
    fi
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    echo "=========================================="
    echo "           Mindra 版本历史"
    echo "=========================================="
    echo ""
    
    # 显示 Git 标签历史
    if git tag -l | grep -q "^v"; then
        echo "Git 标签:"
        git tag -l --sort=-version:refname | grep "^v" | head -10 | while read tag; do
            local tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
            echo "  $tag ($tag_date)"
        done
        echo ""
    fi
    
    # 显示版本相关的提交历史
    echo "最近的版本提交:"
    git log --oneline --grep="version\|bump\|release" -10 | while read commit; do
        echo "  $commit"
    done
    
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    case $COMMAND in
        show)
            show_version
            ;;
        set)
            if [ -z "$VERSION" ]; then
                log_error "请指定版本号"
                show_help
                exit 1
            fi
            set_version "$VERSION"
            ;;
        bump)
            if [ -z "$VERSION" ]; then
                log_error "请指定递增类型 (major/minor/patch)"
                show_help
                exit 1
            fi
            bump_version "$VERSION"
            ;;
        build-bump)
            bump_build
            ;;
        tag)
            create_tag
            ;;
        history)
            show_history
            ;;
        *)
            log_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
