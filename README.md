# cp-navigator-ios

OJ 助手的 iOS 版（SwiftUI）。当前 **1.4.5**：六站真实比赛 + 开赛提醒 + 日历写入 + 榜单 + 我的（成绩统计），界面按 Android 版重做。

## 功能

- **六站比赛**：洛谷、Codeforces、AtCoder、蓝桥、力扣、牛客；六路并行抓取，只保留「今天 0 点 ~ 未来 7 天」。
- **不自动查询**：进入比赛页先显示引导，点右上角「查询」才联网；结果只留在内存，退出应用即清空（与 Android 版一致）。
- **两种视图**：「按平台」分组（带站点 logo，可折叠）与「按日期」分组（今天起 7 天，可折叠）；平台可多选，至少一个。
- **行内操作**：☆ 收藏（本地保存）、铃铛设置提醒（开赛时 / 提前 5 / 10 / 15 分钟）、「日历」把比赛写进系统日历（EventKit，预填标题/描述/北京时间/提前 15 分钟提醒）。
- **收藏页**：只读本地，不联网；支持同样的提醒与日历操作。
- **提醒**：`UNUserNotificationCenter` 本地通知，杀进程也会响。
- **容错**：单站失败不影响其它站，列表底部提示失败站点。
- **榜单**：XCPCIO（ICPC / CCPC 实时榜与历史榜）、RankLand（400+ 赛事榜单合集）、CCPC 外榜（rank.iccpc.cn）、CPC Finder（选手成绩查询），应用内 WebView 打开；带进度条、7 秒慢加载提示，右上角「浏览器」可改用系统浏览器。
- **我的**：7 个站点（CF / AtCoder / 力扣 / 洛谷 / 牛客 / VJudge / HDU）用户名或 id 本地保存，逐站查询「解题数 + rating」，支持「全部查询」；「题解统计」用饼图汇总各站解题占比；「清空本地数据」一并清掉用户名、成绩、收藏与提醒。
- **1.4.5**：VJudge 图标换成官方 favicon（墨镜笑脸）。
- **1.4.4 调整**：比赛页头部把「日期」「平台」分两行显示；空态文案改为「暂无比赛信息，请点击右上角「查询」获取比赛信息。」
- **1.4.3 修复**：按平台分组时，每个平台内部的比赛统一按开赛时间升序（最近的排最前），不再受各站接口原始顺序影响。
- **1.4.1 修复**：牛客改用 ojhunt 的 `nowcoder` 路径取解题数，Rating 排名按页面结构就近取值（不再误取用户 id）；VJudge 改为兼容 `<script type="application/json" id="profile-header-data">` 的解析，用户不存在时给出明确提示。

## 目录

```
project.yml              XcodeGen 工程定义（唯一的工程源）
OJHelper/
  App/                   OJHelperApp.swift、RootView.swift
  Design/                Theme.swift（与 Android 版同一套配色）
  Model/                 Contest.swift、StatSite.swift
  Service/               ContestAPI（六站抓取）、ContestStore、NotificationManager、CalendarService、StatsService、StatsStore
  Views/                 ContestListView、ContestRow、FavoritesView、SourcesSheet、CalendarEditor、LogoView、BoardsView、BoardWebView、ProfileView、StatsSheet
  Resources/             Assets.xcassets（AppIcon、AccentColor、六站 logo）
.github/workflows/ios.yml  构建未签名 IPA 的 CI
```

`.xcodeproj` 由 `xcodegen generate` 生成，**不进仓库**。

## 获取源码

```bash
git clone https://github.com/lihuihong1/cp-navigator-ios.git
cd cp-navigator-ios

# 看有哪些发布版
git tag --sort=-v:refname | head -5

# 停在某个发布版（推荐）
git checkout v1.4.5

# 或者跟着最新开发进度
git pull origin main
```

不想装 git：在 [Releases](../../releases) 里展开最新版本，附件 `OJHelper-<版本>-<build>-src.zip` 与该 tag 的源码树一致，解压后同样按下面的「构建」生成工程。

## 构建

本地（macOS）：

```bash
brew install xcodegen
xcodegen generate
open OJHelper.xcodeproj
```

CI 每次 push 到 `main` 会自动构建未签名 IPA，产物在 Actions 的 `OJHelper-unsigned-ipa` artifact（IPA + 源码 zip）；打 `v*` tag 时自动发 Release（挂 IPA 与 src.zip，不附 sha256）。

## 安装（未签名）

未签名 IPA 不能直接双击安装，需要用 Sideloadly / AltStore / Xcode 自签（免费 Apple ID 签 7 天有效）。**上架 App Store 不在计划内。**

首次使用「日历」会弹系统授权，选「允许添加事件」即可；设置里改主意了可在「设置 → 隐私与安全性 → 日历」重新打开。

## 版本

版本号在 `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 维护；打 tag 前改成新版本并同步 tag。规则固定 `1.X.Y`，功能版第二位 +1 并换 `OJIPA/code/N` 目录。

## 与 Android 版的关系

Android 源在另一个仓库 `cp-navigator`（源码摊平在根目录）。两端各自独立构建，共享的是比赛数据接口与交互约定，代码不共享。iOS 版不抓取 Android 的 SQLite，也不复用 Java 代码。
