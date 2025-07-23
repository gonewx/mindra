# GitHub Release Guide

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](github_release_guide_ZH.md)

---

This guide details how to release Mindra application for Android and Linux platforms on GitHub.

## Table of Contents

- [Preparation](#preparation)
- [Automated Release (Recommended)](#automated-release-recommended)
- [Manual Release](#manual-release)
- [Post-Release Operations](#post-release-operations)
- [Troubleshooting](#troubleshooting)

## Preparation

### 1. Configure GitHub Secrets

Configure the following Secrets in GitHub repository settings:

#### Required for Android Release:
```
ANDROID_KEYSTORE_BASE64        # Base64 encoded release keystore
ANDROID_STORE_PASSWORD         # Keystore password
ANDROID_KEY_PASSWORD          # Key password
ANDROID_KEY_ALIAS             # Key alias
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  # Google Play service account JSON (optional)
```

#### Required for iOS Release:
```
IOS_BUILD_CERTIFICATE_BASE64   # iOS build certificate Base64 encoded
IOS_P12_PASSWORD              # P12 certificate password
IOS_BUILD_PROVISION_PROFILE_BASE64  # Provisioning profile Base64 encoded
IOS_KEYCHAIN_PASSWORD         # Keychain password
APPLE_ID                      # Apple ID
APP_SPECIFIC_PASSWORD         # App-specific password
```

### 2. Create Release Keystore (Android)

```bash
# Run in mindra directory
keytool -genkey -v -keystore android/release-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias mindra-key
```

### 3. Configure Signing File (Android)

Create `android/key.properties` file:
```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=mindra-key
storeFile=release-keystore.jks
```

## Automated Release (Recommended)

### Method 1: Tag-triggered Release

1. **Create Version Tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Automatic Build and Release**:
   - GitHub Actions will trigger automatically
   - Build Android AAB and APK
   - Build Linux DEB and TAR.GZ packages
   - Build iOS IPA (if on macOS)
   - Create GitHub Release

### Method 2: Manual Workflow Trigger

1. **On GitHub Website**:
   - Go to repository "Actions" page
   - Select "Release" workflow
   - Click "Run workflow"
   - Fill in version number and release track
   - Select target platform

2. **Parameter Description**:
   - **Version**: Version number (e.g., 1.0.0)
   - **Track**: Release track
     - `internal`: Internal testing
     - `alpha`: Closed testing  
     - `beta`: Open testing
     - `production`: Production release
   - **Platform**: Target platform
     - `android`: Android only
     - `ios`: iOS only
     - `linux`: Linux only
     - `all`: All platforms

## Manual Release

### Android Platform

1. **Build APK and AAB**:
   ```bash
   cd mindra
   ./scripts/build_android.sh -b  # Build AAB
   ./scripts/build_android.sh     # Build APK and AAB
   ```

2. **Release to Google Play**:
   ```bash
   # Release to internal testing
   ./scripts/release_android.sh -t internal
   
   # Release to beta
   ./scripts/release_android.sh -t beta
   
   # Dry run release
   ./scripts/release_android.sh -t beta --dry-run
   ```

3. **Manual Upload**:
   - Visit [Google Play Console](https://play.google.com/console)
   - Select app
   - Go to "Release" → "App bundles"
   - Upload AAB file
   - Fill release notes
   - Submit for review

### Linux Platform

1. **Build Linux Application**:
   ```bash
   cd mindra
   ./scripts/build_linux.sh -p    # Build and create packages
   ./scripts/build_linux.sh --appimage  # Create AppImage
   ```

2. **Release Options**:

   #### Option 1: GitHub Releases
   - Build artifacts automatically uploaded to GitHub Releases
   - Users can directly download DEB, TAR.GZ or AppImage files

   #### Option 2: Linux Software Repositories
   ```bash
   # Ubuntu/Debian repository
   # 1. Create GPG key
   gpg --gen-key
   
   # 2. Sign DEB package
   dpkg-sig --sign builder build/linux/*.deb
   
   # 3. Upload to repository
   # Specific steps depend on repository provider
   ```

   #### Option 3: Snap Store
   ```bash
   # Need to create snapcraft.yaml first
   snapcraft
   snapcraft upload *.snap
   ```

   #### Option 4: Flathub
   ```bash
   # Need to create Flatpak manifest
   flatpak-builder build com.mindra.app.json
   ```

### iOS Platform

1. **Build iOS Application**:
   ```bash
   cd mindra
   ./scripts/build_ios.sh -a      # Create Archive
   ```

2. **Release to TestFlight**:
   ```bash
   ./scripts/release_ios.sh -t
   ```

3. **Release to App Store**:
   ```bash
   ./scripts/release_ios.sh -s
   ```

## Post-Release Operations

### 1. Verify Release

#### Android:
- Check version status in Google Play Console
- Test internal testing version
- Monitor crash reports

#### Linux:
- Test installation packages on different distributions
- Verify desktop integration
- Check dependencies

#### iOS:
- Check TestFlight status
- Test external testing version
- Prepare App Store review

### 2. Update Documentation

- Update CHANGELOG.md
- Update version number documentation
- Prepare release announcement

### 3. Community Notification

- Publish GitHub Release notes
- Update project README
- Notify users and contributors

## Troubleshooting

### Common Issues

#### 1. Android Build Failure
```bash
# Check signing configuration
ls -la android/release-keystore.jks
cat android/key.properties

# Clean and rebuild
flutter clean
flutter pub get
./scripts/build_android.sh -c -b
```

#### 2. Linux Dependency Issues
```bash
# Install necessary dependencies
sudo apt update
sudo apt install -y libgtk-3-dev libglib2.0-dev ninja-build cmake

# Enable Linux desktop support
flutter config --enable-linux-desktop
```

#### 3. iOS Certificate Issues
```bash
# Check certificate status
security find-identity -v -p codesigning

# Reconfigure in Xcode
open ios/Runner.xcworkspace
```

#### 4. GitHub Actions Failure
- Check Secrets configuration
- Review build logs
- Verify workflow syntax
- Check permission settings

### Debugging Tips

1. **Local Testing**:
   ```bash
   # Test build scripts
   ./scripts/build_all.sh --dry-run
   
   # Verify signing
   jarsigner -verify build/app/outputs/bundle/release/app-release.aab
   ```

2. **View Detailed Logs**:
   ```bash
   # Enable verbose output
   flutter build apk --verbose
   flutter build linux --verbose
   ```

3. **Simulate Release**:
   ```bash
   # Simulate Android release
   ./scripts/release_android.sh -t beta --dry-run
   
   # Simulate iOS release  
   ./scripts/release_ios.sh -t --dry-run
   ```

## Release Track Description

| Track | Android | iOS | Linux | Purpose |
|-------|---------|-----|-------|---------|
| internal | Internal Testing | TestFlight Internal | GitHub Pre-release | Development team testing |
| alpha | Closed Testing | TestFlight External | GitHub Pre-release | Small user testing |
| beta | Open Testing | TestFlight Public | GitHub Pre-release | Large user testing |
| production | Production Release | App Store | GitHub Release | All users |

## Best Practices

1. **Version Management**:
   - Use semantic versioning (e.g., 1.0.0)
   - Create Git tags for each release
   - Maintain detailed CHANGELOG

2. **Testing Process**:
   - Release to internal testing track first
   - Collect feedback then release to testing track
   - Finally release to production environment

3. **Automation**:
   - Use GitHub Actions for automated builds
   - Configure automated testing
   - Set up notification mechanisms

4. **Documentation Maintenance**:
   - Update release notes promptly
   - Maintain user installation guides
   - Record known issues and solutions

## Related Links

- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Release Guide](https://flutter.dev/docs/deployment)
- [Linux Software Packaging Guide](https://packaging.ubuntu.com/)