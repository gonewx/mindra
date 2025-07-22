# Linux 平台：仅支持 AppImage 格式

## 背景

由于 Linux 系统的多样性和依赖库版本差异，传统的 DEB 和 TAR.GZ 包格式容易出现兼容性问题，特别是 GLib 版本冲突导致的符号链接错误（如 `g_once_init_enter_pointer` 未定义）。

## 为什么选择 AppImage

### 1. 自包含性
- AppImage 包含所有必要的依赖库
- 无需系统安装额外软件包
- 避免版本冲突问题

### 2. 兼容性
- 支持所有主流 Linux 发行版
- 从 Ubuntu 16.04 到最新版本
- 从 CentOS 7 到 Rocky Linux 9
- Debian、openSUSE、Arch Linux 等

### 3. 便携性
- 单个文件包含完整应用
- 可直接运行，无需安装
- 支持便携式使用

### 4. 安全性
- 沙箱运行环境
- 不修改系统文件
- 易于卸载（删除文件即可）

## 使用方法

```bash
# 1. 下载 AppImage 文件
wget https://github.com/your-org/mindra/releases/latest/download/Mindra-1.0.0-x86_64.AppImage

# 2. 添加执行权限
chmod +x Mindra-1.0.0-x86_64.AppImage

# 3. 运行应用
./Mindra-1.0.0-x86_64.AppImage
```

## 系统要求

- Linux x86_64 架构
- 内核版本 >= 3.10
- 支持 FUSE（大多数现代发行版默认支持）

## 构建方法

```bash
# 构建 AppImage
cd mindra
./scripts/build_linux.sh -p --appimage

# 或使用快速构建
./scripts/quick_appimage.sh
```

## 常见问题

### Q: 为什么不提供 DEB 包？
A: DEB 包依赖系统库版本，容易出现 GLib 等依赖冲突，AppImage 自包含避免了这个问题。

### Q: AppImage 文件很大怎么办？
A: AppImage 包含所有依赖，文件较大是正常的。这换取了更好的兼容性和便携性。

### Q: 如何集成到桌面环境？
A: 运行 AppImage 后会自动创建桌面快捷方式，或使用 AppImageLauncher 工具。

### Q: 支持自动更新吗？
A: AppImage 支持内置更新机制，应用会检查新版本并提示更新。

## 技术细节

- 使用 `appimagetool` 创建
- 基于 FUSE 文件系统
- 包含 Flutter Linux 运行时
- 自动处理桌面集成

## 未来计划

- 考虑添加 Flatpak 支持
- 探索 Snap 包格式
- 优化 AppImage 文件大小

---

如有问题，请在 GitHub Issues 中反馈。 