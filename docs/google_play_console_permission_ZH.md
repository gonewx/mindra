# 发布权限配置

**Language / 语言:** [🇨🇳 中文](#中文) | [🇺🇸 English](google_play_console_permission.md)

---

## API 访问设置流程如下

在 Google Cloud Console 中启用 API
您现在需要直接登录到 Google Cloud Console，选择或创建一个项目，然后在库中搜索并启用 Google Play Developer API。API 的管理已经统一到 Cloud 平台。

在 Google Cloud Console 中创建服务账户
在启用了 API 的同一个 Google Cloud 项目中，您可以进入 “凭据” (Credentials) 页面创建一个服务账户 (Service Account)，并生成用于身份验证的 JSON 密钥文件。

在 Play Console 中为服务账户授权
这是最关键的改变。您需要复制新创建的服务账户的电子邮件地址，然后回到 Google Play Console，进入 “用户和权限” 页面：

像邀请新用户一样，邀请这个服务账户。

在权限设置中，为该服务账户授予必要的权限，例如管理员(全部权限)，以确保它有足够的权限来上传和管理应用。