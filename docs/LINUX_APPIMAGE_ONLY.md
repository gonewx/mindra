# Linux Platform: AppImage Only

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](LINUX_APPIMAGE_ONLY_ZH.md)

---

## Background

Due to Linux system diversity and dependency version differences, traditional DEB and TAR.GZ package formats are prone to compatibility issues, especially GLib version conflicts causing symbol link errors (such as `g_once_init_enter_pointer` undefined).

## Why Choose AppImage

### 1. Self-contained
- AppImage contains all necessary dependency libraries
- No need to install additional system packages
- Avoids version conflict issues

### 2. Compatibility
- Supports all mainstream Linux distributions
- From Ubuntu 16.04 to latest versions
- From CentOS 7 to Rocky Linux 9
- Debian, openSUSE, Arch Linux, etc.

### 3. Portability
- Single file contains complete application
- Can run directly without installation
- Supports portable usage

### 4. Security
- Sandboxed runtime environment
- Does not modify system files
- Easy to uninstall (just delete the file)

## Usage

```bash
# 1. Download AppImage file
wget https://github.com/gonewx/mindra/releases/latest/download/Mindra-1.0.0-x86_64.AppImage

# 2. Add execute permission
chmod +x Mindra-1.0.0-x86_64.AppImage

# 3. Run application
./Mindra-1.0.0-x86_64.AppImage
```

## System Requirements

- Linux x86_64 architecture
- Kernel version >= 3.10
- FUSE support (default in most modern distributions)

## Build Method

```bash
# Build AppImage
cd mindra
./scripts/build_linux.sh -p --appimage

# Or use quick build
./scripts/quick_appimage.sh
```

## FAQ

### Q: Why not provide DEB packages?
A: DEB packages depend on system library versions and are prone to GLib and other dependency conflicts. AppImage is self-contained and avoids this issue.

### Q: What about the large AppImage file size?
A: AppImage contains all dependencies, so larger file size is normal. This trades off for better compatibility and portability.

### Q: How to integrate with desktop environment?
A: Running AppImage will automatically create desktop shortcuts, or use AppImageLauncher tool.

### Q: Does it support auto-update?
A: AppImage supports built-in update mechanism, the app will check for new versions and prompt for updates.

## Technical Details

- Created using `appimagetool`
- Based on FUSE filesystem
- Contains Flutter Linux runtime
- Auto-handles desktop integration

## Future Plans

- Consider adding Flatpak support
- Explore Snap package format
- Optimize AppImage file size

---

If you have issues, please provide feedback in GitHub Issues.