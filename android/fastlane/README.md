fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android internal

```sh
[bundle exec] fastlane android internal
```

发布到内部测试轨道

### android alpha

```sh
[bundle exec] fastlane android alpha
```

发布到 Alpha 测试轨道

### android beta

```sh
[bundle exec] fastlane android beta
```

发布到 Beta 测试轨道

### android production

```sh
[bundle exec] fastlane android production
```

发布到生产环境

### android deploy

```sh
[bundle exec] fastlane android deploy
```

发布到指定轨道

### android validate_aab

```sh
[bundle exec] fastlane android validate_aab
```

验证 AAB 文件

### android get_version_name

```sh
[bundle exec] fastlane android get_version_name
```

获取版本名称

### android get_version_code

```sh
[bundle exec] fastlane android get_version_code
```

获取版本代码

### android get_release_status

```sh
[bundle exec] fastlane android get_release_status
```

获取发布状态

### android send_notification

```sh
[bundle exec] fastlane android send_notification
```

发送发布通知

### android build_and_deploy

```sh
[bundle exec] fastlane android build_and_deploy
```

构建并发布

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
