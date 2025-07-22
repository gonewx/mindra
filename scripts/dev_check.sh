#!/bin/bash

# Mindra 开发环境代码检查脚本
# 用于在开发过程中快速检查代码质量

set -e

# 检查是否支持颜色输出
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 日志函数
log_info() {
    printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"
}

log_success() {
    printf "%b[SUCCESS]%b %s\n" "$GREEN" "$NC" "$1"
}

log_warning() {
    printf "%b[WARNING]%b %s\n" "$YELLOW" "$NC" "$1"
}

log_error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"
}

# 显示帮助信息
show_help() {
    echo "Mindra 开发检查脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -f, --format        仅运行代码格式化"
    echo "  -a, --analyze       仅运行静态分析"
    echo "  -t, --test          仅运行测试"
    echo "  -q, --quick         快速检查 (格式化 + 分析)"
    echo "  --fix               自动修复可修复的问题"
    echo "  --strict            严格模式，任何问题都会失败"
    echo ""
    echo "示例:"
    echo "  $0                  运行完整检查"
    echo "  $0 -q               快速检查"
    echo "  $0 --fix            自动修复问题"
    echo "  $0 -f               仅格式化代码"
}

# 默认参数
FORMAT_ONLY=false
ANALYZE_ONLY=false
TEST_ONLY=false
QUICK_CHECK=false
AUTO_FIX=false
STRICT_MODE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--format)
            FORMAT_ONLY=true
            shift
            ;;
        -a|--analyze)
            ANALYZE_ONLY=true
            shift
            ;;
        -t|--test)
            TEST_ONLY=true
            shift
            ;;
        -q|--quick)
            QUICK_CHECK=true
            shift
            ;;
        --fix)
            AUTO_FIX=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
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
    log_info "检查开发环境..."
    
    if [ ! -f "pubspec.yaml" ]; then
        log_error "不在Flutter项目根目录"
        exit 1
    fi
    
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 代码格式化
format_code() {
    log_info "格式化Dart代码..."
    
    if dart format . > /tmp/format_output.txt 2>&1; then
        FORMATTED_FILES=$(cat /tmp/format_output.txt | grep "^Changed" | wc -l)
        if [ $FORMATTED_FILES -gt 0 ]; then
            log_warning "格式化了 $FORMATTED_FILES 个文件"
            if [ "$AUTO_FIX" = true ]; then
                log_info "已自动修复格式问题"
            else
                log_info "请检查格式化的更改"
            fi
        else
            log_success "代码格式正确"
        fi
    else
        log_error "代码格式化失败"
        cat /tmp/format_output.txt
        return 1
    fi
    
    rm -f /tmp/format_output.txt
}

# 静态分析
analyze_code() {
    log_info "运行静态分析..."
    
    if [ "$STRICT_MODE" = true ]; then
        # 严格模式：所有问题都视为错误
        if dart analyze --fatal-infos > /tmp/analyze_output.txt 2>&1; then
            log_success "静态分析通过（严格模式）"
        else
            log_error "静态分析发现问题（严格模式）:"
            cat /tmp/analyze_output.txt
            echo ""
            
            if [ "$AUTO_FIX" = true ]; then
                log_info "尝试自动修复一些问题..."
                fix_common_issues
                
                # 重新检查
                log_info "重新运行静态分析..."
                if dart analyze --fatal-infos > /tmp/analyze_recheck.txt 2>&1; then
                    log_success "自动修复后静态分析通过"
                    rm -f /tmp/analyze_recheck.txt
                else
                    log_error "自动修复后仍有问题:"
                    cat /tmp/analyze_recheck.txt
                    rm -f /tmp/analyze_recheck.txt
                    return 1
                fi
            else
                return 1
            fi
        fi
    else
        # 普通模式：只有错误才失败
        if dart analyze --no-fatal-warnings > /tmp/analyze_output.txt 2>&1; then
            # 检查是否有警告或信息
            if grep -q "warning\|info" /tmp/analyze_output.txt 2>/dev/null; then
                log_warning "静态分析发现警告/信息:"
                grep "warning\|info" /tmp/analyze_output.txt | head -5
                log_warning "建议修复这些问题"
            fi
            log_success "静态分析通过（无错误）"
        else
            log_error "静态分析发现错误:"
            cat /tmp/analyze_output.txt
            echo ""
            
            if [ "$AUTO_FIX" = true ]; then
                log_info "尝试自动修复一些问题..."
                fix_common_issues
            fi
            
            return 1
        fi
    fi
    
    rm -f /tmp/analyze_output.txt
}

# 自动修复常见问题
fix_common_issues() {
    log_info "自动修复常见问题..."
    
    # 移除未使用的导入
    if command -v dart &> /dev/null; then
        log_info "尝试修复导入问题..."
        dart fix --apply > /dev/null 2>&1 || true
    fi
    
    # 再次格式化
    dart format . > /dev/null 2>&1 || true
    
    log_info "自动修复完成，请重新检查"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    if [ ! -d "test" ] || [ "$(find test -name "*.dart" | wc -l)" -eq 0 ]; then
        log_warning "未找到测试文件"
        return 0
    fi
    
    if [ "$QUICK_CHECK" = true ]; then
        # 快速测试，只运行不生成覆盖率
        if flutter test --reporter=compact > /tmp/test_output.txt 2>&1; then
            log_success "所有测试通过"
        else
            log_error "部分测试失败:"
            tail -20 /tmp/test_output.txt
            return 1
        fi
    else
        # 完整测试，包含覆盖率
        if flutter test --coverage --reporter=expanded > /tmp/test_output.txt 2>&1; then
            log_success "所有测试通过"
            
            # 显示覆盖率信息
            if [ -f "coverage/lcov.info" ]; then
                if command -v lcov &> /dev/null; then
                    COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}' | sed 's/%//' || echo "unknown")
                    log_info "测试覆盖率: $COVERAGE%"
                else
                    log_info "测试覆盖率文件已生成: coverage/lcov.info"
                fi
            fi
        else
            log_error "部分测试失败:"
            tail -20 /tmp/test_output.txt
            return 1
        fi
    fi
    
    rm -f /tmp/test_output.txt
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if flutter pub get > /dev/null 2>&1; then
        log_success "依赖检查通过"
    else
        log_warning "依赖获取有问题"
    fi
    
    # 检查过期依赖
    if flutter pub outdated > /tmp/outdated.txt 2>&1; then
        OUTDATED_COUNT=$(grep -c "^  " /tmp/outdated.txt || echo "0")
        if [ $OUTDATED_COUNT -gt 0 ]; then
            log_warning "发现 $OUTDATED_COUNT 个过期依赖"
            log_info "运行 'flutter pub outdated' 查看详情"
        fi
    fi
    
    rm -f /tmp/outdated.txt
}

# 主函数
main() {
    echo "=========================================="
    echo "         Mindra 开发环境检查"
    echo "=========================================="
    echo ""
    
    check_environment
    
    local exit_code=0
    
    if [ "$FORMAT_ONLY" = true ]; then
        format_code || exit_code=1
    elif [ "$ANALYZE_ONLY" = true ]; then
        analyze_code || exit_code=1
    elif [ "$TEST_ONLY" = true ]; then
        run_tests || exit_code=1
    elif [ "$QUICK_CHECK" = true ]; then
        format_code || exit_code=1
        analyze_code || exit_code=1
    else
        # 完整检查
        check_dependencies
        if [ "$AUTO_FIX" = true ]; then
            # 在自动修复模式下，格式化失败不阻止后续步骤
            format_code || true
        else
            format_code || exit_code=1
        fi
        analyze_code || exit_code=1
        run_tests || exit_code=1
    fi
    
    echo ""
    echo "=========================================="
    if [ $exit_code -eq 0 ]; then
        log_success "✅ 所有检查通过！"
        log_info "代码已准备好提交"
    else
        log_error "❌ 检查发现问题"
        log_info "请修复上述问题后重新检查"
    fi
    echo "=========================================="
    
    exit $exit_code
}

# 执行主函数
main "$@" 