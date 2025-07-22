# Mindra - 专业冥想与正念应用

<div align="center">
  <img src="assets/images/app_icon_1024.png" alt="Mindra Logo" width="120" height="120">
  
  <h3>🧘‍♀️ 开启你的冥想之旅，让心灵找到平静与专注</h3>
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.32.5+-02569B.svg?style=flat&logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.8.1+-0175C2.svg?style=flat&logo=dart)](https://dart.dev)
  [![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20Web%20%7C%20Desktop-lightgrey.svg)](https://flutter.dev/multi-platform)
</div>

## ✨ 项目简介

**Mindra** 是一款专业的冥想与正念应用，基于 Flutter 开发，支持多平台部署。应用名称结合了"Mind"（心灵/思维）与"Mantra"（咒语），并融入"Sandra"式女性词尾，营造亲切且神秘的氛围，暗示冥想与内在对话。

### 🎯 核心价值
- 🎵 **个性化体验** - 支持本地和网络音视频素材导入
- 🧘 **专业功能** - 完整的冥想会话管理和进度追踪
- 🎨 **精美界面** - 现代化 Material Design 3 设计语言
- 🌍 **多语言支持** - 中英文双语界面
- 📱 **跨平台** - iOS、Android、Web、Desktop 全平台支持

## 🚀 主要功能

### 📚 素材管理
- **本地导入** - 支持从设备存储导入音频/视频文件
- **网络导入** - 支持通过 URL 添加网络音视频资源
- **智能分类** - 冥想、睡眠、专注、放松等多种分类
- **元数据管理** - 自动获取或手动编辑素材信息

### 🎵 冥想播放器
- **多媒体支持** - 音频（MP3、AAC、WAV、FLAC 等）和视频（MP4、MOV 等）
- **高级播放控制** - 播放、暂停、快进、快退、循环播放
- **后台播放** - 支持音频后台播放和息屏播放
- **播放记忆** - 自动记录播放进度，断点续播
- **自然音效** - 可叠加雨声、海浪、鸟鸣等环境音效

### 📊 会话追踪
- **智能记录** - 自动记录冥想会话时长和类型
- **进度统计** - 可视化展示冥想习惯和成长轨迹
- **目标设定** - 设置每日/每周冥想目标
- **成就系统** - 徽章和成就激励持续练习

### ⏰ 智能提醒
- **定时提醒** - 自定义冥想提醒时间和频率
- **睡眠定时器** - 设置播放时长，自动停止
- **通知推送** - 本地通知提醒冥想时间

### 🎨 个性化定制
- **多主题切换** - 深色、浅色、自然等多种主题
- **界面定制** - 卡片间距、内边距等界面元素调整
- **语言切换** - 中英文界面语言切换

## 🛠️ 技术栈

### 核心框架
- **Flutter 3.8.1+** - 跨平台 UI 框架
- **Dart 3.8.1+** - 编程语言

### 状态管理
- **BLoC Pattern** - 业务逻辑组件模式
- **Provider** - 轻量级状态管理
- **HydratedBLoC** - 状态持久化

### 数据存储
- **SQLite** - 本地数据库（移动端）
- **Web Storage** - 浏览器存储（Web端）
- **SharedPreferences** - 用户偏好设置

### 音视频处理
- **AudioPlayers** - 音频播放引擎
- **VideoPlayer** - 视频播放支持
- **AudioService** - 后台音频服务

### 网络与文件
- **Dio** - HTTP 网络请求
- **FilePicker** - 文件选择器
- **YouTubeExplode** - 网络视频解析

### UI 组件
- **Material Design 3** - 现代化设计语言
- **FlutterSVG** - SVG 图像支持
- **CachedNetworkImage** - 网络图片缓存
- **Shimmer** - 加载动画效果

## 📱 支持平台

| 平台 | 状态 | 备注 |
|------|------|------|
| 🤖 Android | ✅ 已测试 | Android 5.0+ (API 21+) - 测试通过 ✓ |
| 🐧 Linux | ✅ 已测试 | Ubuntu 22.04+ - 测试通过 ✓ |
| 📱 iOS | ✅ 支持 | iOS 12.0+ |
| 🌐 Web | ✅ 支持 | 现代浏览器 |
| 🖥️ Windows | ✅ 支持 | Windows 10+ |
| 🍎 macOS | ✅ 支持 | macOS 10.14+ |

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.32.5 或更高版本
- Dart SDK 3.8.1 或更高版本
- 对应平台的开发环境（Android Studio、Xcode 等）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/gonewx/mindra.git
   cd mindra
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   # 开发模式运行
   flutter run
   
   # 指定平台运行（已测试平台）
   flutter run                  # Android - 已测试 ✓
   flutter run -d linux         # Linux - 已测试 ✓
   flutter run -d chrome        # Web
   flutter run -d macos         # macOS
   flutter run -d windows       # Windows
   ```

4. **构建发布版本**
   ```bash
   # Android APK
   flutter build apk
   
   # iOS
   flutter build ios
   
   # Web
   flutter build web
   ```

### 开发命令

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 代码格式化
dart format .

# 清理构建缓存
flutter clean
```

## 📂 项目结构

```
mindra/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── core/                        # 核心功能
│   │   ├── audio/                   # 音频播放器
│   │   ├── config/                  # 应用配置
│   │   ├── constants/               # 常量定义
│   │   ├── database/                # 数据库管理
│   │   ├── di/                      # 依赖注入
│   │   ├── localization/            # 国际化
│   │   ├── router/                  # 路由管理
│   │   ├── services/                # 核心服务
│   │   ├── theme/                   # 主题管理
│   │   └── utils/                   # 工具类
│   ├── features/                    # 功能模块
│   │   ├── home/                    # 首页
│   │   ├── media/                   # 媒体管理
│   │   ├── meditation/              # 冥想会话
│   │   ├── onboarding/              # 引导页面
│   │   ├── player/                  # 播放器
│   │   ├── settings/                # 设置
│   │   ├── splash/                  # 启动页
│   │   └── theme/                   # 主题设置
│   └── shared/                      # 共享组件
│       ├── utils/                   # 共享工具
│       └── widgets/                 # 共享组件
├── assets/                          # 资源文件
│   ├── audio/effects/               # 音效文件
│   ├── images/                      # 图片资源
│   └── translations/                # 翻译文件
├── test/                           # 测试文件
└── docs/                           # 文档
```

## 🏗️ 架构设计

### Clean Architecture
项目采用 Clean Architecture 架构模式，分为三层：

- **Presentation Layer** - UI 界面和状态管理
- **Domain Layer** - 业务逻辑和实体定义
- **Data Layer** - 数据访问和外部服务

### BLoC Pattern
使用 BLoC 模式进行状态管理：

- **Events** - 用户操作事件
- **States** - UI 状态定义
- **BLoCs** - 业务逻辑处理

### 依赖注入
使用 GetIt + Injectable 进行依赖注入管理，确保代码的可测试性和可维护性。

## 🧪 测试

项目包含完整的测试套件：

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/database_test.dart

# 测试覆盖率
flutter test --coverage
```

### 测试类型
- **单元测试** - 核心业务逻辑测试
- **组件测试** - UI 组件测试
- **集成测试** - 功能集成测试
- **本地化测试** - 多语言支持测试

## 📦 构建与发布

项目提供完整的构建和发布脚本：

### 自动化脚本
- `build_all.sh` - 跨平台构建
- `build_android.sh` - Android 构建
- `build_ios.sh` - iOS 构建
- `release_android.sh` - Android 发布
- `release_ios.sh` - iOS 发布
- `version_manager.sh` - 版本管理

### 快速部署
```bash
# 开发环境部署
./scripts/quick_deploy.sh -e dev

# 生产环境部署
./scripts/quick_deploy.sh -e prod
```

详细说明请参考 [构建发布指南](BUILD_RELEASE_README.md)。

## 🌍 国际化

应用支持多语言：

- 🇨🇳 **简体中文** - 默认语言
- 🇺🇸 **English** - 英语支持

### 添加新语言
1. 在 `lib/core/localization/app_localizations.dart` 中添加翻译
2. 更新 `supportedLocales` 配置
3. 重新构建应用

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范
- 遵循 Dart 官方代码风格
- 使用 `dart format` 格式化代码
- 通过 `flutter analyze` 静态分析
- 编写相应的测试用例

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

感谢以下开源项目：

- [Flutter](https://flutter.dev) - 跨平台 UI 框架
- [BLoC](https://bloclibrary.dev) - 状态管理库
- [AudioPlayers](https://pub.dev/packages/audioplayers) - 音频播放
- [GoRouter](https://pub.dev/packages/go_router) - 路由管理

## 📞 支持与反馈

- 📧 **邮箱**: support@mindra.app
- 🐛 **问题反馈**: [GitHub Issues](https://github.com/gonewx/mindra/issues)
- 💬 **讨论交流**: [GitHub Discussions](https://github.com/gonewx/mindra/discussions)
- 📖 **文档**: [项目文档](docs/)

## 🗺️ 路线图

### 已完成 ✅
- [x] 核心播放功能
- [x] 素材管理系统
- [x] 冥想会话追踪
- [x] 多主题支持
- [x] 国际化支持
- [x] 跨平台支持
- [x] Android 平台测试验证
- [x] Linux 平台测试验证

### 开发中 🚧
- [ ] 社区功能
- [ ] AI 推荐系统
- [ ] 云同步功能
- [ ] 高级统计分析

### 计划中 📋
- [ ] 智能语音助手
- [ ] VR/AR 冥想体验
- [ ] 专业课程内容
- [ ] 社交分享功能

---

<div align="center">
  <p>用心打造，专注冥想 🧘‍♀️</p>
  <p>Made with ❤️ by Mindra Team</p>
</div>
