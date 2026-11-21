# cp-navigator-ios

OJ 助手的 iOS 版（SwiftUI）。当前 **0.2.0（P1）**：六站真实比赛抓取 + 本地缓存 + 开赛提醒（`UNUserNotificationCenter` 本地通知）。

## 功能

- **六站比赛**：洛谷、Codeforces、AtCoder、蓝桥、力扣、牛客；六路并行抓取，只保留「今天 0 点 ~ 未来 7 天」，按天分组。
- **缓存**：结果写到 `Application Support/contests.json`，冷启动先显示上次数据；前台恢复时 10 分钟内不重复请求。
- **容错**：单站失败不影响其它站，列表底部提示失败站点；全部失败保留旧数据。
- **提醒**：每场比赛的铃铛可选「开赛时 / 提前 5 / 10 / 15 分钟」，用系统本地通知（杀进程也会响）。

## 目录

```
project.yml              XcodeGen 工程定义（唯一的工程源）
OJHelper/
  App/                   OJHelperApp.swift、RootView.swift
  Model/                 Contest、ContestStore、DayGroup、SampleData
  Service/               ContestAPI（六站抓取）、ContestStore（缓存）、NotificationManager
  Views/                 ContestListView、ContestRow、SettingsView
  Resources/             Assets.xcassets
build_ipa.sh             macOS 本地构建未签名 IPA
.github/workflows/ios.yml  构建未签名 IPA 的 CI
```

`.xcodeproj` 由 `xcodegen generate` 生成，**不进仓库**。

## 构建

本地（macOS）：

```bash
brew install xcodegen
xcodegen generate
open OJHelper.xcodeproj
```

CI 每次 push 到 `main` 会自动构建未签名 IPA，产物在 Actions 的 `OJHelper-unsigned-ipa` artifact；打 `v*` tag 时自动发 Release。

## 安装（未签名）

未签名 IPA 不能直接双击安装，需要用 Sideloadly / AltStore / Xcode 自签（免费 Apple ID 签 7 天有效）。**上架 App Store 不在计划内。**

## 版本

版本号在 `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 维护；打 tag 前改成新版本并同步 tag。

## 抓取接口（与 Android 版一致）

| 站点 | 入口 |
| --- | --- |
| Codeforces | `codeforces.com/api/contest.list?gym=false` |
| 力扣 | `leetcode.cn/graphql`（contestUpcomingContests），失败回退 `/contest/api/list/` |
| 洛谷 | `luogu.com.cn/contest/list?_contentOnly=1`（需 `x-lentille-request: content-only`） |
| 蓝桥 | `lanqiao.cn/api/v2/contests/?status=not_finished&game_type_code=2` |
| AtCoder | `atcoder.jp/contests/` 的 SSR 表格 |
| 牛客 | `ac.nowcoder.com/acm/contest/vip-index` |

站点改版可能导致单站失败，属已知限制。

## 与 Android 版的关系

Android 源在另一个仓库 `cp-navigator`（源码摊平在根目录）。两端各自独立构建，共享的是比赛数据接口与交互约定，代码不共享。iOS 版不抓取 Android 的 SQLite，也不复用 Java 代码。