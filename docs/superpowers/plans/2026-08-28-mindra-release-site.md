# Mindra 发布静态站点（mindra.gonewx.com）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立独立 VitePress 静态站点（gonewx/mindra-site）部署到 Cloudflare Pages、绑定 mindra.gonewx.com，承载 App Store / Google Play 所需的营销/支持/隐私政策/服务条款 URL，并把应用内隐私政策来源从 OSS 切换到该站点。

**Architecture:** 参照 mantra-docs 模式：仓库根即 VitePress 根（中文页面在根、英文镜像在 `en/`），`public/policy/` 放 markdown 副本供 App 内拉取（渲染逻辑零改动），构建后 `wrangler pages deploy` 手动发布。mindra 主仓库只改 `app_config_service.dart` 的默认 URL 与三份文档。

**Tech Stack:** VitePress 1.6、wrangler 4（Cloudflare Pages）、pnpm、Flutter/Dart（仅 URL 常量与测试）

**设计文档:** `docs/superpowers/specs/2026-08-28-release-site-design.md`

**环境要点（执行者必读）:**
- 站点本地路径：`/mnt/disk0/project/mindra/mindra-site`（新建，与 mindra_cc 平级）
- 主仓库路径：`/mnt/disk0/project/mindra/mindra_cc/mindra`（git 远端 `git@gonewx:gonewx/mindra.git`）
- **gh 命令必须排除代理**：`NO_PROXY="*" HTTP_PROXY="" HTTPS_PROXY="" gh ...`
- **git push 走 SSH 别名 gonewx**，不受 HTTP 代理影响，正常 `git push` 即可
- wrangler 若因代理连接失败，尝试 `NO_PROXY="*" HTTP_PROXY="" HTTPS_PROXY="" npx wrangler ...`
- node v26 / pnpm 10 已安装；wrangler 通过项目 devDependency 提供

---

## 阶段 A：站点仓库（mindra-site）

### Task 1: 初始化仓库骨架

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/package.json`
- Create: `/mnt/disk0/project/mindra/mindra-site/wrangler.toml`
- Create: `/mnt/disk0/project/mindra/mindra-site/.gitignore`
- Create: `/mnt/disk0/project/mindra/mindra-site/README.md`

- [ ] **Step 1: 创建目录与 package.json**

```bash
mkdir -p /mnt/disk0/project/mindra/mindra-site
```

写入 `/mnt/disk0/project/mindra/mindra-site/package.json`：

```json
{
  "name": "mindra-site",
  "private": true,
  "scripts": {
    "dev": "vitepress dev",
    "build": "sh scripts/sync-policy-md.sh && vitepress build",
    "preview": "vitepress preview",
    "deploy": "pnpm build && wrangler pages deploy"
  },
  "devDependencies": {
    "vitepress": "^1.6.4",
    "wrangler": "^4.59.2"
  }
}
```

- [ ] **Step 2: 写入 wrangler.toml**

```toml
name = "mindra-site"
compatibility_date = "2026-08-28"
pages_build_output_dir = ".vitepress/dist"
```

- [ ] **Step 3: 写入 .gitignore**

```
node_modules/
.vitepress/dist/
.vitepress/cache/
.wrangler/
.dev.vars
```

- [ ] **Step 4: 写入 README.md**

```markdown
# Mindra Site

Mindra 官网与发布要求页面（营销/支持/隐私政策/服务条款）。

- 技术栈：VitePress（中英双语，英文在 en/ 镜像）
- 部署：Cloudflare Pages，域名 mindra.gonewx.com
- App 内拉取的 markdown 副本在 public/policy/（由 scripts/sync-policy-md.sh 从 about/ 同步，构建时自动执行）

## 常用命令

    pnpm install     # 安装依赖
    pnpm dev         # 本地开发
    pnpm build       # 同步 policy md + 构建
    pnpm deploy      # 构建 + 部署到 Cloudflare Pages

## 修改法律文案

编辑 about/privacy-policy.md（或 en/about/privacy-policy.md 等英文版），
public/policy/ 下的副本由构建脚本自动同步，**不要手改 public/policy/ 里的文件**。
```

- [ ] **Step 5: git 初始化并首次提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git init -b main
git add package.json wrangler.toml .gitignore README.md
git commit -m "初始化 mindra-site 仓库骨架(VitePress + Cloudflare Pages)"
```

Expected: 成功创建 main 分支首个 commit

---

### Task 2: VitePress 配置

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/.vitepress/config.ts`

- [ ] **Step 1: 写入 config.ts**

```ts
import { defineConfig } from 'vitepress'

const SITE = 'https://mindra.gonewx.com'

const sidebarAboutZh = [
  {
    text: '关于 Mindra',
    items: [
      { text: '常见问题', link: '/about/faq' },
      { text: '隐私政策', link: '/about/privacy-policy' },
      { text: '服务条款', link: '/about/terms-of-service' },
    ],
  },
]

const sidebarAboutEn = [
  {
    text: 'About Mindra',
    items: [
      { text: 'FAQ', link: '/en/about/faq' },
      { text: 'Privacy Policy', link: '/en/about/privacy-policy' },
      { text: 'Terms of Service', link: '/en/about/terms-of-service' },
    ],
  },
]

export default defineConfig({
  title: 'Mindra',
  description: 'Mindra - 专业的冥想与正念应用，帮助您找到内心的平静与专注。',

  sitemap: {
    hostname: SITE,
  },

  locales: {
    root: {
      label: '简体中文',
      lang: 'zh-CN',
      themeConfig: {
        nav: [
          { text: '首页', link: '/' },
          { text: '常见问题', link: '/about/faq' },
          { text: '隐私政策', link: '/about/privacy-policy' },
          { text: '服务条款', link: '/about/terms-of-service' },
          { text: 'English', link: '/en/' },
        ],
        sidebar: {
          '/about/': sidebarAboutZh,
        },
        outline: { label: '本页目录' },
        docFooter: { prev: '上一篇', next: '下一篇' },
        returnToTopLabel: '回到顶部',
      },
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      themeConfig: {
        nav: [
          { text: 'Home', link: '/en/' },
          { text: 'FAQ', link: '/en/about/faq' },
          { text: 'Privacy Policy', link: '/en/about/privacy-policy' },
          { text: 'Terms of Service', link: '/en/about/terms-of-service' },
          { text: '中文', link: '/' },
        ],
        sidebar: {
          '/en/about/': sidebarAboutEn,
        },
      },
    },
  },
})
```

- [ ] **Step 2: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add .vitepress/config.ts
git commit -m "VitePress 站点配置:中英双语导航与 about 侧边栏"
```

---

### Task 3: 隐私政策页面（中英，迁移 OSS 现行内容）

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/about/privacy-policy.md`（中文，源=OSS zh 版）
- Create: `/mnt/disk0/project/mindra/mindra-site/en/about/privacy-policy.md`（英文，源=OSS en 版）

- [ ] **Step 1: 下载 OSS 现行内容**

```bash
cd /mnt/disk0/project/mindra/mindra-site
mkdir -p about en/about
curl -s --max-time 20 "https://ycmindra.oss-cn-shanghai.aliyuncs.com/privacy_policy_zh.md" -o about/privacy-policy.md
curl -s --max-time 20 "https://ycmindra.oss-cn-shanghai.aliyuncs.com/privacy_policy_en.md" -o en/about/privacy-policy.md
wc -l about/privacy-policy.md en/about/privacy-policy.md
```

Expected: 两个文件各约 154 行

- [ ] **Step 2: 检查并修正内容中的旧地址**

```bash
cd /mnt/disk0/project/mindra/mindra-site
grep -n -i "aliyun\|ycmindra\|gonewx\|support@" about/privacy-policy.md en/about/privacy-policy.md
```

若有联系邮箱，统一改为 `support@mindra.gonewx.com`；若有 OSS 地址字样，删除或改为 `https://mindra.gonewx.com`。其余正文（数据收集描述等）保持原样——这是现行生效内容，不要重写。

- [ ] **Step 3: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add about/ en/
git commit -m "隐私政策页面:迁移 OSS 现行中英文内容"
```

---

### Task 4: 服务条款页面（中英，新写）

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/about/terms-of-service.md`
- Create: `/mnt/disk0/project/mindra/mindra-site/en/about/terms-of-service.md`

- [ ] **Step 1: 写入中文版**

`/mnt/disk0/project/mindra/mindra-site/about/terms-of-service.md`：

```markdown
# 服务条款

**生效日期**: 2026 年 1 月 1 日

## 1. 条款接受

欢迎使用 Mindra（以下简称「本应用」或「我们」）。通过下载、安装或使用本应用，您同意受本服务条款的约束。如果您不同意这些条款，请勿使用本应用。

## 2. 服务描述

Mindra 是一款冥想与正念应用，提供以下功能：

- 从本地文件或网络地址导入、管理冥想音频与视频内容
- 音频/视频播放与后台播放支持
- 冥想练习计时与会话记录、统计数据
- 自然音效混合与环境音叠加
- 主题与界面个性化设置

## 3. 使用许可

### 3.1 许可授予

在遵守本条款的前提下，我们授予您一项有限的、非独占的、不可转让的许可，以在您的个人设备上安装和使用本应用。

### 3.2 使用限制

您同意不会：

- 将本应用用于任何非法目的
- 利用本应用传播侵犯他人版权的音视频内容
- 对本应用进行反向工程以规避技术限制
- 移除或修改本应用中的任何专有声明或标签

## 4. 用户内容

您导入到 Mindra 的所有冥想内容（音频、视频、链接）归您所有，存储在您的本地设备上。您需自行确保所导入内容的合法性，并遵守内容来源的授权条款。

## 5. 免责声明

本应用提供的冥想内容与功能仅用于辅助放松、专注与睡眠改善，**不构成任何医疗建议或治疗手段**。如您有健康方面的困扰，请咨询专业医师。本应用按「现状」提供，不对适销性或特定用途适用性作任何明示或暗示的保证。

## 6. 责任限制

在适用法律允许的最大范围内，我们对因使用或无法使用本应用造成的任何间接、附带、特殊或后果性损失不承担责任。

## 7. 条款变更

我们可能不时更新本条款。条款更新后，我们会在本页面发布新版本并更新生效日期。继续使用本应用即表示接受修订后的条款。

## 8. 联系我们

如有任何问题，请通过 [support@mindra.gonewx.com](mailto:support@mindra.gonewx.com) 联系我们。
```

- [ ] **Step 2: 写入英文版**

`/mnt/disk0/project/mindra/mindra-site/en/about/terms-of-service.md`：

```markdown
# Terms of Service

**Effective Date**: January 1, 2026

## 1. Acceptance of Terms

Welcome to Mindra ("the App" or "we"). By downloading, installing, or using the App, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the App.

## 2. Service Description

Mindra is a meditation and mindfulness app that provides:

- Importing and managing meditation audio and video content from local files or network URLs
- Audio/video playback with background playback support
- Meditation session timing, records, and statistics
- Nature sound mixing and ambient sound overlay
- Theme and interface customization

## 3. License

### 3.1 Grant of License

Subject to your compliance with these terms, we grant you a limited, non-exclusive, non-transferable license to install and use the App on your personal devices.

### 3.2 Restrictions

You agree not to:

- Use the App for any unlawful purpose
- Distribute audio or video content that infringes others' copyrights through the App
- Reverse engineer the App to circumvent technical restrictions
- Remove or modify any proprietary notices or labels in the App

## 4. User Content

All meditation content (audio, video, links) you import into Mindra belongs to you and is stored on your local device. You are responsible for ensuring the legality of imported content and complying with the license terms of the content's source.

## 5. Disclaimer

The meditation content and features provided by this App are intended solely to assist with relaxation, focus, and sleep improvement. They **do not constitute medical advice or treatment**. If you have health concerns, please consult a qualified physician. The App is provided "as is", without warranty of any kind, express or implied, including merchantability or fitness for a particular purpose.

## 6. Limitation of Liability

To the maximum extent permitted by applicable law, we shall not be liable for any indirect, incidental, special, or consequential damages arising from the use of or inability to use the App.

## 7. Changes to These Terms

We may update these terms from time to time. When we do, we will post the new version on this page and update the effective date. Continued use of the App after changes means you accept the revised terms.

## 8. Contact Us

If you have any questions, please contact us at [support@mindra.gonewx.com](mailto:support@mindra.gonewx.com).
```

- [ ] **Step 3: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add about/ en/
git commit -m "服务条款页面:中英文新写(参照 mantra-docs 模板)"
```

---

### Task 5: FAQ / 支持页（中英，新写）

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/about/faq.md`
- Create: `/mnt/disk0/project/mindra/mindra-site/en/about/faq.md`

- [ ] **Step 1: 写入中文版**

`/mnt/disk0/project/mindra/mindra-site/about/faq.md`：

```markdown
# 常见问题（FAQ）

## Mindra 是什么？

Mindra 是一款专业的冥想与正念应用，帮助您在快节奏的生活中找到内心的平静与专注。支持导入本地或网络的音频、视频冥想内容，配合自然音效与练习统计。

## Mindra 支持哪些平台？

目前发布 Android、iOS 和 Linux 三个平台，其他平台视情况支持。

## Mindra 是免费的吗？

是，Mindra 完全免费使用。

## 我的数据存储在哪里？

您的所有数据（冥想内容、练习记录、设置）都存储在您的本地设备上。Mindra 不需要注册账号，不上传您的练习数据。

## 支持哪些冥想内容格式？

支持音频和视频两类内容，可以从本地文件导入，也可以添加网络 URL。

## 可以混搭背景音效吗？

可以。在播放冥想内容时可以叠加雨声、海浪等自然环境音效，音量可分别调节。

## 如何报告问题或提建议？

发送邮件到 [support@mindra.gonewx.com](mailto:support@mindra.gonewx.com)，我们会尽快回复。
```

- [ ] **Step 2: 写入英文版**

`/mnt/disk0/project/mindra/mindra-site/en/about/faq.md`：

```markdown
# FAQ

## What is Mindra?

Mindra is a professional meditation and mindfulness app that helps you find calm and focus in a fast-paced life. It supports importing meditation audio and video from local files or network URLs, with nature sound mixing and practice statistics.

## Which platforms does Mindra support?

Mindra is currently released on Android, iOS, and Linux. Other platforms may be supported in the future.

## Is Mindra free?

Yes, Mindra is completely free to use.

## Where is my data stored?

All your data (meditation content, session records, settings) is stored locally on your device. Mindra requires no account and does not upload your practice data.

## What content formats are supported?

Both audio and video are supported. You can import from local files or add network URLs.

## Can I mix ambient sounds?

Yes. While playing meditation content, you can overlay nature sounds such as rain or ocean waves, with individually adjustable volumes.

## How do I report issues or suggest features?

Email us at [support@mindra.gonewx.com](mailto:support@mindra.gonewx.com) and we will get back to you as soon as possible.
```

- [ ] **Step 3: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add about/ en/
git commit -m "FAQ/支持页:中英文新写"
```

---

### Task 6: 营销首页（中英）

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/index.md`
- Create: `/mnt/disk0/project/mindra/mindra-site/en/index.md`

- [ ] **Step 1: 写入中文首页**

`/mnt/disk0/project/mindra/mindra-site/index.md`：

```markdown
---
layout: home

hero:
  name: Mindra
  text: 冥想 · 正念 · 安眠
  tagline: 专业的冥想与正念应用。导入您喜爱的音视频内容，配合自然音效，随时开始一段静心时光。
  actions:
    - theme: brand
      text: 常见问题
      link: /about/faq
    - theme: alt
      text: 隐私政策
      link: /about/privacy-policy

features:
  - icon: 🧘
    title: 冥想练习
    details: 导入本地或网络的音频视频内容，专注计时，记录每一次练习。
  - icon: 🌿
    title: 自然音效
    details: 雨声、海浪等多种环境音混合叠加，营造专属的放松氛围。
  - icon: 📊
    title: 练习统计
    details: 跟踪练习时长与进度，见证自己在平静中的成长。
---
```

- [ ] **Step 2: 写入英文首页**

`/mnt/disk0/project/mindra/mindra-site/en/index.md`：

```markdown
---
layout: home

hero:
  name: Mindra
  text: Meditation · Mindfulness · Sleep
  tagline: A professional meditation and mindfulness app. Import your favorite audio and video content, blend in nature sounds, and start a moment of calm anytime.
  actions:
    - theme: brand
      text: FAQ
      link: /en/about/faq
    - theme: alt
      text: Privacy Policy
      link: /en/about/privacy-policy

features:
  - icon: 🧘
    title: Meditation Practice
    details: Import audio and video from local files or the network, focus timer, and record every session.
  - icon: 🌿
    title: Nature Sounds
    details: Mix and overlay ambient sounds like rain and ocean waves to create your own relaxing atmosphere.
  - icon: 📊
    title: Practice Statistics
    details: Track practice duration and progress, and witness your growth in calmness.
---
```

- [ ] **Step 3: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add index.md en/index.md
git commit -m "营销首页:中英文 home 布局"
```

---

### Task 7: policy markdown 同步脚本

**Files:**
- Create: `/mnt/disk0/project/mindra/mindra-site/scripts/sync-policy-md.sh`

package.json 的 `build` 脚本已在 Task 1 挂上 `sh scripts/sync-policy-md.sh &&`，本任务补脚本本体。

- [ ] **Step 1: 写入脚本**

`/mnt/disk0/project/mindra/mindra-site/scripts/sync-policy-md.sh`：

```bash
#!/usr/bin/env bash
# 同步法律文档 markdown 到 public/policy/，供 Mindra App 内拉取。
# 只在构建时运行；public/policy/ 加入 git 忽略，避免双份漂移。
set -euo pipefail

mkdir -p public/policy
cp about/privacy-policy.md public/policy/privacy_policy_zh.md
cp en/about/privacy-policy.md public/policy/privacy_policy_en.md
cp about/terms-of-service.md public/policy/terms_of_service_zh.md
cp en/about/terms-of-service.md public/policy/terms_of_service_en.md

echo "Synced policy markdown files to public/policy/"
```

- [ ] **Step 2: 把 public/policy/ 加入 .gitignore**

`/mnt/disk0/project/mindra/mindra-site/.gitignore` 追加一行：

```
public/policy/
```

- [ ] **Step 3: 验证脚本可执行**

```bash
cd /mnt/disk0/project/mindra/mindra-site
sh scripts/sync-policy-md.sh
ls -la public/policy/
```

Expected: 4 个文件（privacy_policy_zh/en.md、terms_of_service_zh/en.md）

- [ ] **Step 4: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add scripts/sync-policy-md.sh .gitignore
git commit -m "构建脚本:同步法律文档 md 到 public/policy 供应用内拉取"
```

---

### Task 8: 安装依赖并构建验证

**Files:** 无新增（产出 .vitepress/dist/，已 gitignore）

- [ ] **Step 1: 安装依赖**

```bash
cd /mnt/disk0/project/mindra/mindra-site
pnpm install
```

Expected: 安装成功，生成 pnpm-lock.yaml

- [ ] **Step 2: 构建**

```bash
cd /mnt/disk0/project/mindra/mindra-site
pnpm build
```

Expected: vitepress build 成功，输出到 `.vitepress/dist/`

- [ ] **Step 3: 验证 dist 结构**

```bash
cd /mnt/disk0/project/mindra/mindra-site
ls .vitepress/dist/ .vitepress/dist/about/ .vitepress/dist/en/ .vitepress/dist/en/about/ .vitepress/dist/policy/
```

Expected 包含：
- `dist/index.html`、`dist/about/index.html`（VitePress 会为 about/faq.md 等生成 `faq.html`）
- `dist/about/privacy-policy.html`、`dist/about/terms-of-service.html`、`dist/about/faq.html`
- `dist/en/index.html`、`dist/en/about/` 下三个对应 html
- `dist/policy/privacy_policy_zh.md`、`dist/policy/privacy_policy_en.md`、`dist/policy/terms_of_service_zh.md`、`dist/policy/terms_of_service_en.md`

- [ ] **Step 4: 本地预览抽查**

```bash
cd /mnt/disk0/project/mindra/mindra-site
npx vitepress preview --port 4173 &
sleep 3
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4173/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4173/about/privacy-policy
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4173/en/about/privacy-policy
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4173/policy/privacy_policy_zh.md
kill %1
```

Expected: 四个都是 200

- [ ] **Step 5: 提交 lockfile**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git add pnpm-lock.yaml
git commit -m "锁定站点依赖版本"
```

---

### Task 9: 创建 GitHub 远端仓库并推送

- [ ] **Step 1: 用 gh 创建仓库（务必排除代理）**

```bash
NO_PROXY="*" HTTP_PROXY="" HTTPS_PROXY="" gh repo create gonewx/mindra-site --public --description "Mindra official site - marketing, support, privacy policy, terms of service"
```

Expected: 输出仓库地址 `https://github.com/gonewx/mindra-site`

- [ ] **Step 2: 配置远端并推送（SSH 走 gonewx 别名，不受代理影响）**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git remote add origin git@gonewx:gonewx/mindra-site.git
git push -u origin main
```

Expected: 推送成功

---

### Task 10: Cloudflare Pages 首次部署

- [ ] **Step 1: 检查 wrangler 登录状态**

```bash
cd /mnt/disk0/project/mindra/mindra-site
npx wrangler whoami
```

Expected: 显示已登录的 Cloudflare 账号。若未登录，**停下请用户执行 `npx wrangler login`**（浏览器 OAuth 交互），完成后再继续。

- [ ] **Step 2: 创建 Pages 项目**

```bash
cd /mnt/disk0/project/mindra/mindra-site
npx wrangler pages project create mindra-site --production-branch=main
```

Expected: 项目创建成功。若提示项目已存在，直接继续。

- [ ] **Step 3: 部署**

```bash
cd /mnt/disk0/project/mindra/mindra-site
npx wrangler pages deploy .vitepress/dist --project-name=mindra-site --branch=main
```

Expected: 输出部署 URL `https://mindra-site.pages.dev`

- [ ] **Step 4: 验证 pages.dev 线上可访问**

```bash
for u in "https://mindra-site.pages.dev/" "https://mindra-site.pages.dev/about/privacy-policy" "https://mindra-site.pages.dev/en/about/privacy-policy" "https://mindra-site.pages.dev/about/terms-of-service" "https://mindra-site.pages.dev/about/faq" "https://mindra-site.pages.dev/policy/privacy_policy_zh.md" "https://mindra-site.pages.dev/policy/privacy_policy_en.md"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 20 "$u"); echo "$code  $u"
done
```

Expected: 全部 200

---

### Task 11: 绑定自定义域名 mindra.gonewx.com（含用户手动步骤）

- [ ] **Step 1: 请用户在 Cloudflare Dashboard 绑定域名**

这一步需要用户操作（或用户明确授权用 API）：

1. Cloudflare Dashboard → Workers & Pages → mindra-site 项目 → **Custom domains** → **Set up a custom domain**
2. 输入 `mindra.gonewx.com`，确认。gonewx.com zone 在同一账号，Cloudflare 会自动添加 CNAME 记录
3. 等待状态变为 Active（通常几分钟内）

- [ ] **Step 2: 验证 DNS 与线上访问**

```bash
nslookup mindra.gonewx.com
```

Expected: 解析到 Cloudflare IP（104.x 或 172.x 段），不再是 NXDOMAIN

```bash
for u in "https://mindra.gonewx.com/" "https://mindra.gonewx.com/about/faq" "https://mindra.gonewx.com/about/privacy-policy" "https://mindra.gonewx.com/about/terms-of-service" "https://mindra.gonewx.com/en/" "https://mindra.gonewx.com/policy/privacy_policy_zh.md" "https://mindra.gonewx.com/policy/privacy_policy_en.md"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 20 "$u"); echo "$code  $u"
done
```

Expected: 全部 200

- [ ] **Step 3: 提交阶段 A 收尾（若有未提交文件）**

```bash
cd /mnt/disk0/project/mindra/mindra-site
git status --short
```

Expected: 干净（dist/、node_modules/、public/policy/ 均被忽略）

---

## 阶段 B：mindra 主仓库切换

### Task 12: TDD 切换 app_config_service.dart 默认 URL

**Files:**
- Test: `/mnt/disk0/project/mindra/mindra_cc/mindra/test/app_config_urls_test.dart`（新建）
- Modify: `/mnt/disk0/project/mindra/mindra_cc/mindra/lib/core/config/app_config_service.dart:15-30`（`_defaultConfig`）

- [ ] **Step 1: 写失败测试**

`/mnt/disk0/project/mindra/mindra_cc/mindra/test/app_config_urls_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/config/app_config_service.dart';

void main() {
  group('AppConfigService 默认 URL（发布站点 mindra.gonewx.com）', () {
    test('默认隐私政策 URL 指向新站点英文版', () {
      expect(
        AppConfigService.getPrivacyPolicyUrl(),
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',
      );
    });

    test('隐私政策语言版本 URL 指向新站点', () {
      expect(
        AppConfigService.getConfig('privacy_policy_url_zh'),
        'https://mindra.gonewx.com/policy/privacy_policy_zh.md',
      );
      expect(
        AppConfigService.getConfig('privacy_policy_url_en'),
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',
      );
    });

    test('服务条款 URL 指向新站点', () {
      expect(
        AppConfigService.getTermsOfServiceUrl(),
        'https://mindra.gonewx.com/policy/terms_of_service_zh.md',
      );
    });
  });
}
```

说明：`getPrivacyPolicyUrl()` 在服务未初始化时忽略 locale 直接返回 `_defaultConfig['privacy_policy_url']`（见 `app_config_service.dart:119-122`），测试不触发网络与 SharedPreferences，行为确定。

- [ ] **Step 2: 运行测试确认失败**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
flutter test test/app_config_urls_test.dart
```

Expected: FAIL——实际值仍是 `https://ycmindra.oss-cn-shanghai.aliyuncs.com/...`

- [ ] **Step 3: 修改 _defaultConfig**

`/mnt/disk0/project/mindra/mindra_cc/mindra/lib/core/config/app_config_service.dart` 中将 `_defaultConfig`（第 15-30 行）替换为：

```dart
  // 默认配置
  static const Map<String, String> _defaultConfig = {
    // 默认隐私政策URL（英文版兜底）
    _privacyPolicyUrlKey:
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',
    // 中文隐私政策URL
    '${_privacyPolicyUrlKey}_zh':
        'https://mindra.gonewx.com/policy/privacy_policy_zh.md',
    // 英文隐私政策URL
    '${_privacyPolicyUrlKey}_en':
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',

    _termsOfServiceUrlKey:
        'https://mindra.gonewx.com/policy/terms_of_service_zh.md',
    _remoteConfigUrlKey:
        'https://raw.githubusercontent.com/mindra-app/mindra/main/config/app_config.json',
  };
```

注意：`_remoteConfigUrlKey` 有意保持原样（指向不存在地址，`_loadRemoteConfig` 静默失败无害，属既有行为，本次范围外）。

- [ ] **Step 4: 运行测试确认通过**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
flutter test test/app_config_urls_test.dart
```

Expected: PASS（3 个测试全绿）

- [ ] **Step 5: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
git add test/app_config_urls_test.dart lib/core/config/app_config_service.dart
git commit -m "应用内隐私政策/服务条款 URL 切换到 mindra.gonewx.com"
```

---

### Task 13: 更新发布文档中的 URL

**Files:**
- Modify: `/mnt/disk0/project/mindra/mindra_cc/mindra/docs/app_store_release_guide_ZH.md:209-212`
- Modify: `/mnt/disk0/project/mindra/mindra_cc/mindra/docs/app_store_release_guide.md`（对应英文版 Support URLs 节，约 209-211 行）
- Modify: `/mnt/disk0/project/mindra/mindra_cc/mindra/docs/ios_release_pipeline.md:342`

- [ ] **Step 1: 更新中文指南的三个 URL**

`docs/app_store_release_guide_ZH.md` 中：

```markdown
#### 支持 URL
- **营销网址**: https://mindra.gonewx.com
- **支持网址**: https://mindra.gonewx.com/support
- **隐私政策网址**: https://mindra.gonewx.com/privacy
```

替换为：

```markdown
#### 支持 URL
- **营销网址**: https://mindra.gonewx.com
- **支持网址**: https://mindra.gonewx.com/about/faq
- **隐私政策网址**: https://mindra.gonewx.com/about/privacy-policy
```

- [ ] **Step 2: 更新英文指南的三个 URL**

`docs/app_store_release_guide.md` 中对应 Support URLs 节：

```markdown
- **Support URL**: https://mindra.gonewx.com/support
```

所在段落替换为：

```markdown
- **Marketing URL**: https://mindra.gonewx.com
- **Support URL**: https://mindra.gonewx.com/about/faq
- **Privacy Policy URL**: https://mindra.gonewx.com/about/privacy-policy
```

以文件实际内容为准，保持原有的营销/隐私两行格式，仅替换 URL 与对应字段名。

- [ ] **Step 3: 更新 ios_release_pipeline.md 的表格行**

`docs/ios_release_pipeline.md:342`：

```markdown
| 营销/支持/隐私政策 URL | https://mindra.gonewx.com 等（见发布指南） |
```

替换为：

```markdown
| 营销/支持/隐私政策 URL | 营销 https://mindra.gonewx.com / 支持 https://mindra.gonewx.com/about/faq / 隐私 https://mindra.gonewx.com/about/privacy-policy（见 app_store_release_guide） |
```

- [ ] **Step 4: 提交**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
git add docs/app_store_release_guide_ZH.md docs/app_store_release_guide.md docs/ios_release_pipeline.md
git commit -m "发布文档:营销/支持/隐私政策 URL 更新为 mindra.gonewx.com 实际路径"
```

---

### Task 14: 主仓库全量验证

- [ ] **Step 1: 静态分析**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
flutter analyze
```

Expected: No issues found（或与改动前同等水平，无新增告警）

- [ ] **Step 2: 全量测试**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
flutter test
```

Expected: 全部通过（既有测试 + 新增 app_config_urls_test）

- [ ] **Step 3: 确认工作区干净**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
git status --short
git log --oneline -3
```

Expected: 干净，最近两条提交为 Task 12、13 的提交

---

## 阶段 C：应用内人工验证（可选，发布前做）

### Task 15: 应用内隐私政策页真机验证

- [ ] **Step 1: 运行应用进入隐私政策页**

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra
flutter run
```

应用内：设置 → 隐私政策。Expected: 正常加载并渲染 markdown 内容（此时来自 mindra.gonewx.com）。

- [ ] **Step 2: 切换语言验证英文版**

在系统设置中把语言切到英文（或应用内语言设置），重新进入隐私政策页。Expected: 加载英文版内容。

- [ ] **Step 3: 观察调试日志**

控制台应出现 `Trying to load from: https://mindra.gonewx.com/policy/privacy_policy_zh.md` 且随后 `Successfully loaded from: ...`。

---

## 验收标准（对照设计文档）

1. ✅ 站点 4 类页面（首页/隐私/条款/FAQ × 中英）线上 200（Task 11 Step 2）
2. ✅ `/policy/*.md` 直链 200 且与 HTML 版同源（Task 7 同步脚本保证，Task 11 验证）
3. ✅ 应用内切换后正常渲染（Task 15）
4. ✅ `nslookup mindra.gonewx.com` 解析到 Cloudflare（Task 11 Step 2）
5. ✅ 主仓库文档无死链（Task 13）
6. ✅ `mindra-site.pages.dev` 可访问（Task 10 Step 4）
