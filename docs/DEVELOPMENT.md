# Mindra Development Guide

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](DEVELOPMENT_ZH.md)

---

## 🚀 Quick Start

### One-time Environment Setup
```bash
# Set up development environment (run only once)
make dev-setup
```

This command will:
- Install Flutter dependencies
- Set up Git hooks
- Configure development environment

## 📋 Daily Development Workflow

### 1. Pre-development Check
```bash
# Quick code quality check
make check

# Or use script
./scripts/dev_check.sh -q
```

### 2. After Code Changes
```bash
# Auto-fix common issues
make fix

# Or step by step
make format    # Format code
make analyze   # Static analysis
make test      # Run tests
```

### 3. Before Commit
When you run `git commit`, the pre-commit hook will automatically:
- ✅ Format code
- ✅ Run static analysis
- ✅ Run tests
- ✅ Check for sensitive information

If checks fail, the commit will be blocked and you need to fix issues before committing again.

## 🛠️ Available Commands

### Make Commands
```bash
make help          # Show all available commands
make check         # Quick check
make check-full    # Full check
make format        # Format code
make analyze       # Static analysis
make test          # Run tests
make fix           # Auto fix
make pre-commit    # Manually run pre-commit checks
make build-android # Build Android APK
make build-aab     # Build Android AAB
make run           # Run application
```

### Script Commands
```bash
# Development check script
./scripts/dev_check.sh --help    # Show help
./scripts/dev_check.sh -q        # Quick check
./scripts/dev_check.sh --fix     # Auto fix
./scripts/dev_check.sh -f        # Format only
./scripts/dev_check.sh -a        # Analyze only
./scripts/dev_check.sh -t        # Test only
./scripts/dev_check.sh --strict  # Strict mode
```

## 🎯 VS Code Integration

### Auto-format on Save
VS Code is configured to auto-format code and organize imports on save.

### Task Shortcuts
In VS Code, press `Ctrl+Shift+P`, then type "Tasks: Run Task" and select:
- **Quick Check** - Quick check
- **Full Check** - Full check
- **Format Code** - Format code
- **Auto Fix Issues** - Auto fix
- **Run Tests** - Run tests
- **Pre-commit Check** - Pre-commit check

## 🔧 Tool Configuration

### Git Hooks
- **pre-commit**: Auto-check code quality before commit
- Location: `.git/hooks/pre-commit`
- Auto install: `make install-hooks`

### VS Code Settings
- **Auto format**: Format on save
- **Auto import organize**: Organize imports on save
- **Line length limit**: 80 characters
- **Config file**: `.vscode/settings.json`

### Analysis Configuration
- **Rules file**: `analysis_options.yaml`
- **Strict mode**: All info-level issues treated as errors
- **Excluded directories**: build, .dart_tool, etc.

## 🚫 Common Issue Resolution

### 1. Format Issues
```bash
# Auto-fix format issues
make format

# Or manually
dart format .
```

### 2. Static Analysis Errors
```bash
# View detailed errors
dart analyze

# Auto-fix some issues
make fix
```

### 3. Test Failures
```bash
# Run specific test
flutter test test/specific_test.dart

# View detailed output
flutter test --reporter=expanded
```

### 4. Dependency Issues
```bash
# Clean and re-fetch dependencies
make clean
make setup

# Or manually
flutter clean
flutter pub get
```

### 5. Skip Pre-commit Check (Not Recommended)
```bash
# Use only in emergency
git commit --no-verify -m "emergency fix"
```

## 📊 Code Quality Metrics

### Target Metrics
- **Test Coverage**: ≥ 80%
- **Static Analysis**: 0 errors, 0 warnings
- **Code Format**: 100% compliant with Dart standards
- **Build**: All platforms build successfully

### Check Tools
- **Format**: `dart format`
- **Static Analysis**: `dart analyze`
- **Test**: `flutter test`
- **Build**: `flutter build`

## 🔄 CI/CD Integration

### GitHub Actions
- **Quick Check**: Quick validation on PR
- **Build and Test**: Full build on push
- **Release**: Auto release on tag

### Local-first Strategy
Most checks are done locally, CI mainly used for:
- Verify local checks are executed correctly
- Multi-platform build validation
- Auto release

## 💡 Best Practices

### 1. Before Commit
- Run `make check` to ensure code quality
- Ensure all tests pass
- Check for uncommitted formatting changes

### 2. Code Review
- Focus on business logic rather than format issues
- Automated tools handle format and basic quality issues

### 3. Continuous Improvement
- Regularly run `make deps-outdated` to check dependency updates
- Pay attention to new static analysis rules
- Maintain test coverage

## 🆘 Getting Help

If you encounter issues:
1. Check error messages and suggested fix commands
2. Run `make help` to see available commands
3. Check `./scripts/dev_check.sh --help`
4. Check VS Code problems panel
5. Contact other team members