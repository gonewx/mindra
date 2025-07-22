# Mindra Flutter项目 Makefile
# 提供快速开发命令

.PHONY: help setup clean check format analyze test build-android build-ios build-linux fix pre-commit

# 默认目标
.DEFAULT_GOAL := help

# 帮助信息
help: ## 显示帮助信息
	@echo "Mindra 开发命令:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "示例:"
	@echo "  make check     # 快速检查代码"
	@echo "  make fix       # 自动修复问题"
	@echo "  make test      # 运行测试"

# 环境设置
setup: ## 设置开发环境
	@echo "🔧 设置开发环境..."
	@flutter pub get
	@echo "✅ 环境设置完成"

# 清理
clean: ## 清理构建文件
	@echo "🧹 清理构建文件..."
	@flutter clean
	@rm -rf coverage/
	@echo "✅ 清理完成"

# 快速检查
check: ## 快速检查代码质量
	@./scripts/dev_check.sh -q

# 完整检查
check-full: ## 完整的代码质量检查
	@./scripts/dev_check.sh

# 代码格式化
format: ## 格式化代码
	@./scripts/dev_check.sh -f

# 静态分析
analyze: ## 运行静态分析
	@./scripts/dev_check.sh -a

# 运行测试
test: ## 运行测试
	@./scripts/dev_check.sh -t

# 自动修复
fix: ## 自动修复可修复的问题
	@./scripts/dev_check.sh --strict --fix

# 提交前检查
pre-commit: ## 运行提交前检查
	@./.git/hooks/pre-commit

# 构建Android APK
build-android: ## 构建Android APK
	@echo "📱 构建Android APK..."
	@flutter build apk --release
	@echo "✅ Android APK构建完成"

# 构建Android AAB
build-aab: ## 构建Android AAB
	@echo "📱 构建Android AAB..."
	@flutter build appbundle --release
	@echo "✅ Android AAB构建完成"

# 构建iOS
build-ios: ## 构建iOS应用
	@echo "🍎 构建iOS应用..."
	@flutter build ios --release --no-codesign
	@echo "✅ iOS构建完成"

# 构建Linux
build-linux: ## 构建Linux应用
	@echo "🐧 构建Linux应用..."
	@flutter build linux --release
	@echo "✅ Linux构建完成"

# 构建所有平台
build-all: build-android build-aab build-ios build-linux ## 构建所有平台

# 获取依赖
deps: ## 获取依赖包
	@echo "📦 获取依赖包..."
	@flutter pub get
	@echo "✅ 依赖包获取完成"

# 检查过期依赖
deps-outdated: ## 检查过期依赖
	@echo "🔍 检查过期依赖..."
	@flutter pub outdated

# 升级依赖
deps-upgrade: ## 升级依赖包
	@echo "⬆️ 升级依赖包..."
	@flutter pub upgrade
	@echo "✅ 依赖包升级完成"

# 运行应用
run: ## 运行应用
	@echo "🚀 启动应用..."
	@flutter run

# 运行应用（调试模式）
run-debug: ## 运行应用（调试模式）
	@echo "🐛 启动应用（调试模式）..."
	@flutter run --debug

# 运行应用（发布模式）
run-release: ## 运行应用（发布模式）
	@echo "🚀 启动应用（发布模式）..."
	@flutter run --release

# 生成代码
generate: ## 运行代码生成
	@echo "⚙️ 运行代码生成..."
	@flutter packages pub run build_runner build --delete-conflicting-outputs
	@echo "✅ 代码生成完成"

# 监听代码生成
generate-watch: ## 监听模式运行代码生成
	@echo "👀 监听模式运行代码生成..."
	@flutter packages pub run build_runner watch --delete-conflicting-outputs

# 创建发布版本
release: ## 创建发布版本（需要指定版本号）
	@echo "🎯 创建发布版本..."
	@echo "请使用: git tag v1.0.0 && git push origin v1.0.0"

# 安装Git hooks
install-hooks: ## 安装Git hooks
	@echo "🪝 安装Git hooks..."
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Git hooks安装完成"

# 开发者设置（一次性设置）
dev-setup: setup install-hooks ## 开发者环境一次性设置
	@echo "🎉 开发环境设置完成！"
	@echo ""
	@echo "可用命令:"
	@echo "  make check     - 快速检查"
	@echo "  make fix       - 自动修复"
	@echo "  make test      - 运行测试"
	@echo "  make run       - 运行应用" 