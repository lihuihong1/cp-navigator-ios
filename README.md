# cp-navigator-ios

OJ 助手的 iOS 版（SwiftUI）。当前 **1.1.0**：六站真实比赛 + 开赛提醒，界面按 Android 版重做。

## 功能

- **六站比赛**：洛谷、Codeforces、AtCoder、蓝桥、力扣、牛客；六路并行抓取，只保留「今天 0 点 ~ 未来 7 天」。
- **不自动查询**：进入比赛页先显示引导，点右上角「查询」才联网；结果只留在内存，退出应用即清空（与 Android 版一致）。
- **两种视图**：「按平台」分组（带站点 logo，可折叠）与「按日期」分组（今天起 7 天，可折叠）；平台可多选，至少一个。
- **行内操作**：☆ 收藏（本地保存）、铃铛设置提醒（开赛时 / 提前 5 / 10 / 15 分钟）。
- **收藏页**：只读本地，不联网；支持同样的提醒操作。
- **提醒**：`UNUserNotificationCenter` 本地通知，杀进程也会响。
- **容错**：单站失败不影响其它站，列表底部提示失败站点。

## 目录

```
project.yml              XcodeGen 工程定义（唯一的工程源）
OJHelper/
  App/                   OJHelperApp.swift、RootView.swift
  Design/                Theme.swift（与 Android 版同一套配色）
  Model/                 Contest.swift
  Service/               ContestAPI（六站抓取）、ContestStore、NotificationManager
  Views/                 ContestListView、ContestRow、FavoritesView、SourcesSheet、SettingsView、LogoView
  Resources/             Assets.xcassets（AppIcon、AccentColor、六站 logo）
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

CI 每次 push 到 `main` 会自动构建未签名 IPA，产物在 Actions 的 `OJHelper-unsigned-ipa` artifact；打 `v*` tag 时自动发 Release（只上传 IPA，不附 sha256）。

## 安装（未签名）

未签名 IPA 不能直接双击安装，需要用 Sideloadly / AltStore / Xcode 自签（免费 Apple ID 签 7 天有效）。**上架 App Store 不在计划内。**

首次使用「日历」会弹系统授权，选「允许添加事件」即可；设置里改主意了可在「设置 → 隐私与安全性 → 日历」重新打开。

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