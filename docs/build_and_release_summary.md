# Mindra Build and Release System Summary

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](build_and_release_summary_ZH.md)

---

This document summarizes the complete build and release system created for the Mindra application.

## 📁 File Structure

```
mindra/
├── scripts/                    # Build and release scripts
│   ├── build_android.sh       # Android build script
│   ├── build_ios.sh           # iOS build script
│   ├── build_all.sh           # Cross-platform build script
│   ├── release_android.sh     # Android release script
│   ├── release_ios.sh         # iOS release script
│   ├── version_manager.sh     # Version management script
│   ├── quick_deploy.sh        # Quick deployment script
│   └── build_summary.sh       # Build summary script (existing)
├── android/fastlane/          # Android Fastlane configuration
│   ├── Fastfile              # Fastlane main config
│   └── Appfile               # App configuration
├── ios/fastlane/              # iOS Fastlane configuration
│   ├── Fastfile              # Fastlane main config
│   └── Appfile               # App configuration
├── .github/workflows/         # GitHub Actions CI/CD
│   ├── build_and_test.yml    # Build and test workflow
│   ├── release.yml           # Release workflow
│   └── code_quality.yml      # Code quality check
└── docs/                      # Documentation
    ├── app_store_release_guide.md  # App store release guide
    └── build_and_release_summary.md # This document
```

## 🛠️ Build Scripts

### 1. Android Build (`build_android.sh`)
- Supports APK and AAB builds
- Auto signing configuration
- Version number management
- Build verification

**Usage Examples:**
```bash
# Basic build
./scripts/build_android.sh

# Clean build AAB
./scripts/build_android.sh -c -b

# Build with specific version
./scripts/build_android.sh -v 1.0.1+2
```

### 2. iOS Build (`build_ios.sh`)
- Supports simulator and device builds
- Archive creation
- Certificate verification
- Version synchronization

**Usage Examples:**
```bash
# Basic build
./scripts/build_ios.sh

# Create Archive
./scripts/build_ios.sh -a

# Clean build
./scripts/build_ios.sh -c -a
```

### 3. Cross-platform Build (`build_all.sh`)
- Build Android and iOS simultaneously
- Unified version management
- Parallel build support
- Auto version increment

**Usage Examples:**
```bash
# Build all platforms
./scripts/build_all.sh

# Auto increment version and build
./scripts/build_all.sh --bump-version patch

# Build Android only
./scripts/build_all.sh -a
```

## 🚀 Release Scripts

### 1. Android Release (`release_android.sh`)
- Supports multiple release tracks
- Google Play Console integration
- Fastlane automation
- Manual upload guidance

**Usage Examples:**
```bash
# Release to internal testing
./scripts/release_android.sh -t internal

# Dry run release to beta
./scripts/release_android.sh -t beta --dry-run
```

### 2. iOS Release (`release_ios.sh`)
- TestFlight and App Store support
- Auto IPA export
- API key authentication
- Manual upload guidance

**Usage Examples:**
```bash
# Release to TestFlight
./scripts/release_ios.sh -t

# Release to App Store
./scripts/release_ios.sh -s
```

## 📋 Version Management (`version_manager.sh`)

Unified version number management tool:

```bash
# Show current version
./scripts/version_manager.sh show

# Set version number
./scripts/version_manager.sh set 1.2.0+5

# Increment version number
./scripts/version_manager.sh bump patch

# Create Git tag
./scripts/version_manager.sh tag
```

## ⚡ Quick Deployment (`quick_deploy.sh`)

One-click deployment solution:

```bash
# Deploy to development environment
./scripts/quick_deploy.sh -e dev

# Deploy to production and increment version
./scripts/quick_deploy.sh -e prod --bump-version patch

# Deploy Android only to staging
./scripts/quick_deploy.sh -e staging -p android
```

## 🤖 Automated CI/CD

### GitHub Actions Workflows

1. **Build and Test** (`build_and_test.yml`)
   - Code format check
   - Static analysis
   - Unit tests
   - Cross-platform builds

2. **Release** (`release.yml`)
   - Auto version management
   - Signed builds
   - App store deployment
   - GitHub Release creation

3. **Code Quality** (`code_quality.yml`)
   - Code analysis
   - Test coverage
   - Security checks
   - Performance checks

### Fastlane Integration

- **Android**: Automate Google Play Store release
- **iOS**: Automate TestFlight and App Store release

## 📖 Usage Guide

### Initial Setup

1. **Configure Signing**:
   ```bash
   # Android
   ./scripts/create_release_keystore.sh
   
   # iOS - Configure certificates in Xcode
   ```

2. **Set Environment Variables**:
   ```bash
   # Android
   export ANDROID_HOME=/path/to/android/sdk
   
   # iOS
   export APPLE_ID=your-apple-id@example.com
   export APP_SPECIFIC_PASSWORD=your-app-password
   ```

3. **Install Dependencies**:
   ```bash
   # Fastlane
   gem install fastlane
   
   # Flutter
   flutter doctor
   ```

### Daily Development Workflow

1. **Development Phase**:
   ```bash
   # Build and test
   ./scripts/build_all.sh --skip-tests
   
   # Deploy to internal testing
   ./scripts/quick_deploy.sh -e dev
   ```

2. **Testing Phase**:
   ```bash
   # Increment version and deploy to staging
   ./scripts/quick_deploy.sh -e staging --bump-version patch
   ```

3. **Production Release**:
   ```bash
   # Release to production
   ./scripts/quick_deploy.sh -e prod --bump-version minor
   ```

### Release Track Description

| Track | Android | iOS | Purpose |
|-------|---------|-----|---------|
| internal | Internal Testing | TestFlight Internal | Development team testing |
| alpha | Closed Testing | TestFlight External | Small user testing |
| beta | Open Testing | TestFlight Public | Large user testing |
| production | Production Release | App Store | All users |

## 🔧 Troubleshooting

### Common Issues

1. **Android Signing Failure**:
   - Check `android/key.properties` configuration
   - Verify keystore file path

2. **iOS Certificate Issues**:
   - Reconfigure certificates in Xcode
   - Check provisioning profile validity

3. **Version Number Conflicts**:
   - Use `version_manager.sh` for unified management
   - Check existing versions in app stores

4. **Build Failures**:
   - Run `flutter doctor` to check environment
   - Clean build cache: `flutter clean`

### Debugging Tips

1. **Use `--dry-run` for simulation**
2. **Check build logs and report files**
3. **Use `build_summary.sh` to view build status**

## 📚 Related Documentation

- [App Store Release Guide](app_store_release_guide_en.md)
- [iOS Build Guide](../scripts/ios_build_guide.md)
- [Project Requirements Document](prd.md)

## 🔄 Maintenance and Updates

### Regular Maintenance Tasks

1. **Update Dependencies**:
   ```bash
   flutter pub upgrade
   ```

2. **Update CI/CD Configuration**:
   - Check Flutter version
   - Update GitHub Actions

3. **Check Certificate Validity**:
   - iOS certificates and provisioning profiles
   - Android keystore

4. **Monitor Build Performance**:
   - Build time
   - App size
   - Test coverage

### Version Release Checklist

- [ ] Code review completed
- [ ] All tests pass
- [ ] Version number correctly incremented
- [ ] Changelog prepared
- [ ] App store metadata updated
- [ ] Certificates and signing valid
- [ ] Build artifacts verified

## 🎯 Best Practices

1. **Version Management**:
   - Use semantic versioning
   - Increment build number for each release
   - Create Git tags for important versions

2. **Testing Strategy**:
   - Internal testing → Closed testing → Open testing → Production release
   - Thoroughly test each phase before moving to next

3. **Automation**:
   - Use CI/CD to reduce manual operations
   - Automate testing and code quality checks
   - Auto-generate release reports

4. **Security**:
   - Properly secure signing keys
   - Use environment variables for sensitive information
   - Regularly update dependencies and tools

## 📞 Support

For issues, please refer to:
- Built-in `--help` options in scripts
- [App Store Release Guide](app_store_release_guide_en.md)
- Project Issues page

---

**Note**: Please carefully read the help information for each script before first use and adjust configurations according to your actual environment.