# cp-navigator-ios

OJ 助手的 iOS 版（SwiftUI）。当前 **0.1.0（P0 骨架）**：比赛列表（内置示例数据）、开赛提醒（`UNUserNotificationCenter` 本地通知）、测试通知。

## 目录

```
project.yml              XcodeGen 工程定义（唯一的工程源）
OJHelper/
  App/                   OJHelperApp.swift、RootView.swift
  Model/                 Contest、ContestStore、DayGroup、SampleData
  Service/               NotificationManager（本地通知）
  Views/                 ContestListView、ContestRow、SettingsView
  Resources/             Assets.xcassets
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

## 与 Android 版的关系

Android 源在另一个仓库 `cp-navigator`（源码摊平在根目录）。两端各自独立构建，共享的是比赛数据接口与交互约定，代码不共享。iOS 版不抓取 Android 的 SQLite，也不复用 Java 代码。