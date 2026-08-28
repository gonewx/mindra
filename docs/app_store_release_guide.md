# Mindra App Store Release Guide

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](app_store_release_guide_ZH.md)

---

This guide provides detailed instructions on how to release the Mindra app to Google Play Store and Apple App Store.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Google Play Store Release](#google-play-store-release)
- [Apple App Store Release](#apple-app-store-release)
- [App Metadata](#app-metadata)
- [Screenshot Requirements](#screenshot-requirements)
- [Post-Release Maintenance](#post-release-maintenance)

## Prerequisites

### 1. Build the App

Before releasing, ensure you have built production versions of the app:

```bash
# Build all platforms
./scripts/build_all.sh --archive

# Or build separately
./scripts/build_android.sh -b  # Build AAB
./scripts/build_ios.sh -a      # Create Archive
```

### 2. Test the App

- Test app functionality on real devices
- Verify all core features work properly
- Check app performance and stability
- Ensure compliance with platform design guidelines

### 3. Prepare App Assets

- App icons (various sizes)
- Splash screens
- App screenshots
- Promotional images
- App description text

## Google Play Store Release

### 1. Developer Account Setup

1. Register for [Google Play Console](https://play.google.com/console) developer account
2. Pay one-time registration fee ($25)
3. Complete identity verification and tax information

### 2. Create App

1. Click "Create app" in Google Play Console
2. Fill in app information:
   - **App name**: Mindra
   - **Default language**: English (United States)
   - **App type**: App
   - **Free or paid**: Free

### 3. App Content Setup

#### App Details
- **App name**: Mindra
- **Short description**: Professional meditation and mindfulness app to help you find inner peace and focus
- **Full description**: 
```
Mindra is a professional meditation and mindfulness app dedicated to helping users find inner peace and focus in their fast-paced lives.

🧘‍♀️ Key Features:
• Rich meditation content library with guided meditations and nature sounds
• Personalized meditation plans suitable for users of all levels
• Focus timer to help build meditation habits
• Progress tracking to record your meditation journey
• Beautiful interface design creating a serene meditation atmosphere

🌟 Highlights:
• Professional meditation guidance content
• Diverse background sound effects
• Clean and intuitive user interface
• Offline usage support
• Completely free with no ads

Whether you're a meditation beginner or an experienced practitioner, Mindra provides the right meditation experience for you. Let's start this journey of inner exploration together!
```

#### App Category
- **Category**: Health & Fitness
- **Tags**: Meditation, Mindfulness, Health, Relaxation

#### Contact Details
- **Website**: https://mindra.gonewx.com
- **Email**: support@mindra.gonewx.com
- **Privacy Policy**: https://mindra.gonewx.com/about/privacy-policy

### 4. Content Rating

Fill out the content rating questionnaire based on app content:
- Target age group: All ages
- Content type: Educational/Health
- No violence, adult content, etc.

### 5. Target Audience and Content

- **Target age group**: 13+
- **Target audience**: Users interested in mental health and personal growth
- **Content appropriateness**: Suitable for all ages

### 6. App Signing

Ensure using production keystore for signing:
```bash
# Check signature
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
```

### 7. Release Tracks

#### Internal Testing
- Up to 100 testers
- For internal team testing
- Available within minutes

#### Closed Testing (Alpha)
- Invitation-only testing
- For small-scale user testing
- Available within hours

#### Open Testing (Beta)
- Public testing, users need to join
- For large-scale user testing
- Available within hours

#### Production Release
- Visible to all users
- Requires 1-3 days review time

### 8. Upload App

```bash
# Upload using script
./scripts/release_android.sh -t internal

# Or manually upload AAB file
# Upload build/app/outputs/bundle/release/app-release.aab in Google Play Console
```

## Apple App Store Release

### 1. Developer Account Setup

1. Register for [Apple Developer Program](https://developer.apple.com/programs/)
2. Pay annual fee ($99/year)
3. Complete identity verification

### 2. App Store Connect Setup

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app:
   - **Name**: Mindra
   - **Bundle ID**: com.gonewx.mindra.app
   - **SKU**: mindra-app
   - **User Access**: Full Access

### 3. App Information

#### Basic Information
- **Name**: Mindra
- **Subtitle**: Meditation & Mindfulness
- **Category**: 
  - Primary: Health & Fitness
  - Secondary: Lifestyle
- **Content Rating**: 4+

> Note: The subtitle is filled in on the App Store Connect website, where special characters like `&` are allowed.
> Do not confuse it with the Description field when registering the App ID in appuploader — that is only
> an internal label, disallows `@` `&` `*` `"`, and can simply be `Mindra` (see [ios_release_pipeline.md](ios_release_pipeline.md)).

#### App Description
```
Mindra is a professional meditation and mindfulness app dedicated to helping users find inner peace and focus in their fast-paced lives.

Key Features:
• Rich meditation content library
• Personalized meditation plans
• Focus timer
• Progress tracking
• Beautiful interface design

Highlights:
• Professional meditation guidance
• Diverse background sound effects
• Clean and intuitive interface
• Offline usage support
• Completely free

Whether you're a meditation beginner or an experienced practitioner, Mindra provides the right meditation experience for you.
```

#### Keywords
```
meditation,mindfulness,relaxation,focus,health,mental health,stress relief,sleep,yoga,breathing
```

#### Support URLs
- **Marketing URL**: https://mindra.gonewx.com
- **Support URL**: https://mindra.gonewx.com/about/faq
- **Privacy Policy URL**: https://mindra.gonewx.com/about/privacy-policy
- **Terms of Service URL**: https://mindra.gonewx.com/about/terms-of-service

### 4. Pricing and Availability

- **Price**: Free
- **Availability**: Worldwide (adjust as needed)

### 5. App Review Information

- **Contact Information**: 
  - Name: [Your Name]
  - Phone: [Your Phone]
  - Email: support@mindra.gonewx.com
- **Demo Account**: Provide test account if login required
- **Notes**: Special instructions for the app

### 6. Version Information

- **Version Number**: 1.0.0
- **What's New**: 
```
Welcome to Mindra!

This is our first release, featuring:
• Curated meditation content
• Focus timer
• Personal progress tracking
• Beautiful user interface

We'll continue updating to bring you a better meditation experience.
```

### 7. Build Upload

Builds are signed on an offline macOS build machine; upload is done by
appuploader (signing credentials never enter CI):

```bash
cd mindra/

# Build and sign the IPA (auto-syncs code to the build machine, 1-3 min)
mise run ios:vm:archive

# Fetch the IPA back to the host
mise run ios:sync:back

# Upload: open appuploader (GUI), pick the IPA under build/ios/ipa/
```

First-time setup requires importing signing assets (.p12 and
.mobileprovision exported from appuploader):

```bash
mise run ios:vm:signing:import -- -c <cert.p12> -p <profile.mobileprovision>
```

See ios_release_pipeline.md for the full pipeline. For subsequent releases,
run `mise run ios:build:bump` before building (TestFlight requires an
incrementing build number).

### 8. Submit for Review

1. Ensure all information is complete
2. Add screenshots and metadata
3. Click "Submit for Review"
4. Wait for review results (usually 1-7 days)

## App Metadata

### App Icon Requirements

#### Android
- **Adaptive Icon**: 512x512 px (PNG)
- **Legacy Icon**: 512x512 px (PNG)
- **High-res Icon**: 512x512 px (PNG)

#### iOS
- **App Store Icon**: 1024x1024 px (PNG)
- **App Icons**: Various sizes, auto-generated by Xcode

### App Screenshots

#### Android Screenshot Requirements
- **Phone Screenshots**: At least 2, maximum 8
- **Dimensions**: 16:9 or 9:16 aspect ratio
- **Resolution**: Minimum 320px, maximum 3840px
- **Format**: PNG or JPG

#### iOS Screenshot Requirements
- **iPhone Screenshots**: At least 1, maximum 10
- **Dimensions**: 
  - 6.7" Display: 1290x2796 px
  - 6.5" Display: 1242x2688 px
  - 5.5" Display: 1242x2208 px
- **Format**: PNG or JPG

### Promotional Images

#### Android
- **Feature Graphic**: 1024x500 px (optional)
- **Promo Video**: Maximum 30 seconds (optional)

#### iOS
- **App Preview**: 15-30 seconds (optional)

## Post-Release Maintenance

### 1. Monitor App Performance

- Download and install metrics
- User ratings and reviews
- Crash reports
- Performance metrics

### 2. Handle User Feedback

- Respond to user reviews promptly
- Collect user suggestions
- Fix reported issues

### 3. App Updates

- Release updates regularly
- Fix bugs and security issues
- Add new features
- Optimize performance

### 4. Compliance Maintenance

- Follow platform policy updates
- Update privacy policy
- Handle legal requirements

## Release Checklist

### Pre-Release Checklist

#### Technical Checks
- [ ] App tested on real devices
- [ ] All core features working properly
- [ ] App performance is good, no obvious lag
- [ ] Memory usage is reasonable, no memory leaks
- [ ] Network requests handled correctly
- [ ] Offline functionality works
- [ ] App startup time is reasonable
- [ ] Supports different screen sizes

#### Content Checks
- [ ] App icon is clear and beautiful
- [ ] Splash screen displays correctly
- [ ] All text content has no typos
- [ ] Image resources are high quality
- [ ] Audio files play correctly
- [ ] Multi-language support is correct (if applicable)

#### Compliance Checks
- [ ] Privacy policy prepared
- [ ] Terms of service prepared
- [ ] Complies with platform content policies
- [ ] Age rating is correct
- [ ] Permission requests are reasonable
- [ ] Data collection is transparent

#### Store Listing Checks
- [ ] App name and description are accurate
- [ ] Keywords optimization completed
- [ ] Screenshots are high quality
- [ ] Category selection is correct
- [ ] Contact information is complete
- [ ] Pricing strategy determined

### Android Release Checklist
- [ ] AAB file generated
- [ ] App signing is correct
- [ ] Google Play Console account ready
- [ ] Release track selected correctly
- [ ] Content rating completed
- [ ] Target audience set correctly

### iOS Release Checklist
- [ ] Archive created
- [ ] Certificates and provisioning profiles valid
- [ ] App Store Connect account ready
- [ ] App information complete
- [ ] Screenshots meet requirements
- [ ] Review information prepared completely

## Common Issues

### Q: What to do if app is rejected?
A: Carefully read the rejection reason, fix issues and resubmit. Common issues include:
- Incomplete functionality
- Interface issues
- Platform policy violations
- Inaccurate metadata

### Q: How to improve app visibility?
A: 
- Optimize app store description and keywords
- Get positive user reviews
- Update app regularly
- Promote the app

### Q: How often to update the app?
A: Recommended:
- Critical bug fixes: Immediately
- Minor feature updates: Monthly
- Major version updates: Quarterly

## Quick Start Guide

### For First-Time Release

1. **Setup Signing**:
   ```bash
   # Android
   ./scripts/create_release_keystore.sh

   # iOS - import assets exported from appuploader
   mise run ios:vm:signing:import -- -c <cert.p12> -p <profile.mobileprovision>
   ```

2. **Set Environment Variables**:
   ```bash
   # Android
   export ANDROID_HOME=/path/to/android/sdk
   ```

3. **Install Dependencies**:
   ```bash
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

### Release Track Descriptions

| Track | Android | iOS | Purpose |
|-------|---------|-----|---------|
| internal | Internal Testing | TestFlight Internal | Development team testing |
| alpha | Closed Testing | TestFlight External | Small-scale user testing |
| beta | Open Testing | TestFlight Public | Large-scale user testing |
| production | Production | App Store | All users |

## Troubleshooting

### Common Issues

1. **Android Signing Failure**:
   - Check `android/key.properties` configuration
   - Verify keystore file path

2. **iOS Certificate Issues**:
   - Check `mise run ios:vm:signing:status` output
   - Re-run `ios:vm:signing:import` with `--reset` to start clean

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

## Best Practices

1. **Version Management**:
   - Use semantic versioning
   - Increment build number for each release
   - Create Git tags for important versions

2. **Testing Strategy**:
   - Internal → Closed → Open → Production
   - Thoroughly test each stage before proceeding

3. **Automation**:
   - Use CI/CD to reduce manual operations
   - Automate testing and quality checks
   - Auto-generate release reports

4. **Security**:
   - Securely store signing keys
   - Use environment variables for sensitive data
   - Regularly update dependencies and tools

## Contact Support

If you encounter issues during the release process, contact:

- **Google Play Support**: [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- **Apple Support**: [App Store Connect Help](https://developer.apple.com/support/app-store-connect/)
- **Mindra Team**: support@mindra.gonewx.com

---

**Note**: Please carefully read the help information for each script before first use, and adjust configurations according to your actual environment.
