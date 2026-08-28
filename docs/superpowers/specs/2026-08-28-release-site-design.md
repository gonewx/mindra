# Mindra 发布静态站点设计（mindra.gonewx.com）

**日期**: 2026-08-28
**状态**: 已获用户批准

## 背景与目标

Mindra 上架 App Store / Google Play 需要「营销网址」「支持网址」「隐私政策网址」等商店元数据 URL 真实可访问（隐私政策为审核硬性要求，Guideline 5.1.1）。当前状态：

- `docs/app_store_release_guide_ZH.md:209-212` 写的 `https://mindra.gonewx.com` 系列地址是占位符，域名 NXDOMAIN（不存在）。
- 应用内隐私政策实际从阿里云 OSS 拉取 markdown（`lib/core/config/app_config_service.dart` 默认配置），可用但属临时方案。
- 服务条款 URL 指向不存在的 GitHub 仓库（404），应用内无入口。

参照 mantra 项目的做法（`/mnt/disk0/project/newx/mantra-sites/mantra-docs`）：独立仓库的 VitePress 站点，法律页面放在 `about/` 目录，中英双语，构建产物部署到 Cloudflare Pages，域名挂在 gonewx.com 下。

## 总体架构

```
GitHub: gonewx/mindra-site（新仓库）
  └─ VitePress 站点（参考 mantra-docs 结构）
       ├─ index.md                → 营销首页（/）
       ├─ about/
       │   ├─ privacy-policy.md   → /about/privacy-policy（隐私政策）
       │   ├─ terms-of-service.md → /about/terms-of-service（服务条款）
       │   └─ faq.md              → /about/faq（支持/FAQ 页）
       ├─ en/…                    → 英文镜像（同结构）
       └─ public/policy/
           ├─ privacy_policy_zh.md → /policy/privacy_policy_zh.md（App 内拉取）
           └─ privacy_policy_en.md → /policy/privacy_policy_en.md（App 内拉取）

部署: 本地 vitepress build → wrangler pages deploy
域名: mindra.gonewx.com（Cloudflare DNS CNAME → mindra-site.pages.dev）
```

## 商店 URL 对应关系

| 商店字段 | URL |
|---------|-----|
| 营销网址 | `https://mindra.gonewx.com/` |
| 支持网址 | `https://mindra.gonewx.com/about/faq` |
| 隐私政策 | `https://mindra.gonewx.com/about/privacy-policy` |
| 服务条款 | `https://mindra.gonewx.com/about/terms-of-service` |

联系邮箱统一为 `support@mindra.gonewx.com`（需在 Cloudflare 配 Email Routing 转发到真实邮箱，不阻塞站点上线）。

## 页面内容来源

- **隐私政策**：以 OSS 上现行的 `privacy_policy_zh.md` / `privacy_policy_en.md`（生效日期 2025-01-01，内容真实在用）为底本迁移。
- **服务条款**：参照 mantra-docs 的 `terms-of-service.md` 模板新写。
- **FAQ/支持页**：参照 mantra-docs 的 `faq.md` 模板新写，含联系邮箱。
- **营销首页**：简单介绍 Mindra（冥想应用）、平台下载入口，后续可扩展。

## 应用内隐私政策切换（方案 A：public/ 放 markdown 副本）

VitePress 约定 `public/` 目录文件原样复制进构建产物。隐私政策 markdown 同步一份到 `public/policy/`，线上同时存在：

- `https://mindra.gonewx.com/about/privacy-policy` — HTML 页面（商店/浏览器用户）
- `https://mindra.gonewx.com/policy/privacy_policy_zh.md` — markdown 原文（App 内拉取）

应用侧改动仅 `lib/core/config/app_config_service.dart` 的 `_defaultConfig` 三处 URL：

```
privacy_policy_url     → https://mindra.gonewx.com/policy/privacy_policy_en.md
privacy_policy_url_zh  → https://mindra.gonewx.com/policy/privacy_policy_zh.md
privacy_policy_url_en  → https://mindra.gonewx.com/policy/privacy_policy_en.md
```

渲染逻辑零改动：`PrivacyPolicyPage` 继续用 flutter_markdown 渲染；`_generateOssUrls` 的 OSS 特判对新 URL 无副作用（不含 `aliyuncs.com` 直接用原 URL）。

被否决的方案 B（WebView 加载 HTML 页面）：需引入 webview_flutter 依赖、处理平台差异、改动面大、离线体验更差。

**同源更新约束**：修改法律文案时，`about/privacy-policy.md`（HTML 源）和 `public/policy/privacy_policy_zh.md`（App 拉取副本）必须一起改。实施时用同步脚本（构建前把 `about/` 的 md 复制到 `public/policy/` 并加语言后缀）避免两份漂移。

## 部署与 DNS

1. **Cloudflare Pages**：`wrangler pages create mindra-site`（或 Dashboard 手建）；`wrangler.toml` 写 `name = "mindra-site"`、`pages_build_output_dir = ".vitepress/dist"`。
2. **DNS**：gonewx.com 已托管在 Cloudflare，Dashboard 加 CNAME：`mindra.gonewx.com → mindra-site.pages.dev`。
3. **发布流程**：本地 `pnpm docs:build && wrangler pages deploy`（与 mantra-docs 一致，无 CI）。
4. **邮箱**：Cloudflare Email Routing 为 `support@mindra.gonewx.com` 配置转发（用户在 Dashboard 操作，实施时给出步骤）。

## 主仓库（mindra）同步改动

- `docs/app_store_release_guide_ZH.md` / `app_store_release_guide.md`：占位 URL（`mindra.gonewx.com/support` 等）改为上表真实路径。
- `docs/ios_release_pipeline.md:342`：「营销/支持/隐私政策 URL」一行同步更新。

## 错误处理

- 站点构建失败：本地 `vitepress build` 即时暴露，无 CI 延迟。
- App 拉取 md 失败：现有 `PrivacyPolicyPage` 错误兜底不变（细分离线/404/403/5xx + 重试按钮）。切换即替换默认 URL，不保留 OSS 旧地址作为回退。
- DNS 未生效：`nslookup mindra.gonewx.com` 验证解析到 Cloudflare IP 后才算完成。

## 验收标准

1. 站点 4 类页面（首页/隐私/条款/FAQ × 中英）线上全部返回 200。
2. `/policy/privacy_policy_zh.md` 与 `/policy/privacy_policy_en.md` 直链 200，内容与 HTML 版一致。
3. 应用内隐私政策页改 URL 后真机/模拟器正常加载渲染（中文/英文各验一次）。
4. `nslookup mindra.gonewx.com` 解析到 Cloudflare。
5. 主仓库文档中不再有指向不存在地址的链接。
6. `wrangler pages deploy` 成功，`mindra-site.pages.dev` 可访问。

## 范围外（明确不做）

- 完整文档站（用户指南等）——首页之外只做发布要求的 4 类页面。
- 邮箱服务的实际收信配置（Email Routing 由用户在 Dashboard 手动完成）。
- 应用内服务条款入口（当前无入口，本次不新增）。
- OSS 旧地址下线（保留但不再是 App 引用地址）。
