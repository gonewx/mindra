# Mindra 开发指南

**Language / 语言:** [🇨🇳 中文](#中文) | [🇺🇸 English](DEVELOPMENT.md)

---

## 🚀 快速开始

### 一次性环境设置
```bash
# 设置开发环境（只需运行一次）
make dev-setup
```

这个命令会：
- 安装Flutter依赖
- 设置Git hooks
- 配置开发环境

## 📋 日常开发工作流

### 1. 开发前检查
```bash
# 快速检查代码质量
make check

# 或者使用脚本
./scripts/dev_check.sh -q
```

### 2. 代码修改后
```bash
# 自动修复常见问题
make fix

# 或者分步骤
make format    # 格式化代码
make analyze   # 静态分析
make test      # 运行测试
```

### 3. 提交前
当你运行 `git commit` 时，pre-commit hook会自动：
- ✅ 格式化代码
- ✅ 运行静态分析
- ✅ 运行测试
- ✅ 检查敏感信息

如果检查失败，提交会被阻止，你需要修复问题后重新提交。

## 🛠️ 可用命令

### Make 命令
```bash
make help          # 显示所有可用命令
make check         # 快速检查
make check-full    # 完整检查
make format        # 格式化代码
make analyze       # 静态分析
make test          # 运行测试
make fix           # 自动修复
make pre-commit    # 手动运行提交前检查
make build-android # 构建Android APK
make build-aab     # 构建Android AAB
make run           # 运行应用
```

### 脚本命令
```bash
# 开发检查脚本
./scripts/dev_check.sh --help    # 显示帮助
./scripts/dev_check.sh -q        # 快速检查
./scripts/dev_check.sh --fix     # 自动修复
./scripts/dev_check.sh -f        # 仅格式化
./scripts/dev_check.sh -a        # 仅分析
./scripts/dev_check.sh -t        # 仅测试
./scripts/dev_check.sh --strict  # 严格模式
```

## 🎯 VS Code 集成

### 自动保存时格式化
VS Code已配置为保存时自动格式化代码和整理导入。

### 任务快捷键
在VS Code中按 `Ctrl+Shift+P`，然后输入 "Tasks: Run Task"，选择：
- **Quick Check** - 快速检查
- **Full Check** - 完整检查
- **Format Code** - 格式化代码
- **Auto Fix Issues** - 自动修复
- **Run Tests** - 运行测试
- **Pre-commit Check** - 提交前检查

## 🔧 工具配置

### Git Hooks
- **pre-commit**: 提交前自动检查代码质量
- 位置: `.git/hooks/pre-commit`
- 自动安装: `make install-hooks`

### VS Code 设置
- **自动格式化**: 保存时自动格式化
- **自动导入整理**: 保存时整理导入
- **代码长度限制**: 80字符
- **配置文件**: `.vscode/settings.json`

### 分析配置
- **规则文件**: `analysis_options.yaml`
- **严格模式**: 所有info级别问题都视为错误
- **排除目录**: build, .dart_tool 等

## 🚫 常见问题解决

### 1. 格式化问题
```bash
# 自动修复格式问题
make format

# 或手动
dart format .
```

### 2. 静态分析错误
```bash
# 查看详细错误
dart analyze

# 自动修复部分问题
make fix
```

### 3. 测试失败
```bash
# 运行特定测试
flutter test test/specific_test.dart

# 查看详细输出
flutter test --reporter=expanded
```

### 4. 依赖问题
```bash
# 清理并重新获取依赖
make clean
make setup

# 或手动
flutter clean
flutter pub get
```

### 5. 跳过pre-commit检查（不推荐）
```bash
# 仅在紧急情况下使用
git commit --no-verify -m "emergency fix"
```

## 📊 代码质量指标

### 目标指标
- **测试覆盖率**: ≥ 80%
- **静态分析**: 0 errors, 0 warnings
- **代码格式**: 100% 符合Dart标准
- **构建**: 所有平台构建成功

### 检查工具
- **格式化**: `dart format`
- **静态分析**: `dart analyze`
- **测试**: `flutter test`
- **构建**: `flutter build`

## 🔄 CI/CD 集成

### GitHub Actions
- **Quick Check**: PR时快速验证
- **Build and Test**: push时完整构建
- **Release**: tag时自动发布

### 本地优先策略
大部分检查在本地完成，CI主要用于：
- 验证本地检查是否正确执行
- 多平台构建验证
- 自动发布

## 💡 最佳实践

### 1. 提交前
- 运行 `make check` 确保代码质量
- 确保所有测试通过
- 检查是否有未提交的格式化更改

### 2. 代码审查
- 关注业务逻辑而非格式问题
- 自动化工具已处理格式和基本质量问题

### 3. 持续改进
- 定期运行 `make deps-outdated` 检查依赖更新
- 关注静态分析新规则
- 保持测试覆盖率

## 🆘 获取帮助

如果遇到问题：
1. 查看错误信息和建议的修复命令
2. 运行 `make help` 查看可用命令
3. 查看 `./scripts/dev_check.sh --help`
4. 检查VS Code问题面板
5. 联系团队其他成员 