# iOS 本地开发规则

> **本文件的「规则」部分与总规则（[`../README.md`](../README.md)）的 iOS 部分完全一致——不新增、不放松任何一条。**
>
> - **只做 iOS**：读本文件就够，不必回看总规则（上传/Release 规则也在这里复述过一遍）。
> - **两个平台一起改，或已经完整读过总规则**：本文件可以跳过，只在需要具体操作细节时才回来翻——XcodeGen 命令、`build_ipa.sh` 的写死路径、Info.plist 权限串、真机自签步骤。
> - 两份文档冲突时以总规则为准；发现冲突请改本文件，不要改总规则去迁就它。

---

## 1. 工作区与本仓库的关系

```
cp-navigator/                     ← 产品根（不是 git 仓库）
├── README.md                     总规则
├── OJIPA/                        iOS 开发工作区（不是 git 仓库）
│   ├── code/1 … code/3            源码：project.yml + OJHelper/（build_ipa.sh 仅本地保留）
│   ├── ipa/1 … ipa/3              未签名 IPA 归档（本地）
│   └── tools/                    脱敏打包、Release 发布脚本
├── cp-navigator-ios/             ← 本仓库（公开，远端 lihuihong1/cp-navigator-ios）
│   ├── project.yml               摊平后的源码
│   ├── OJHelper/
│   ├── .github/workflows/ios.yml 只在仓库里维护
│   ├── README.md                 用户视角
│   └── DEVELOPING.md             本文件
├── cp-navigator-ios-releases/    发布素材（每版本一个目录）
└── check/                        上传前自检清单（不进仓库）
```

**工作区才是"开发现场"，本仓库只是它的一份摊平投影。**
改代码永远在 `OJIPA/code/N` 里改，改完再同步过来；不要直接在本仓库里改完再往回拷（会造成两份分叉）。

---

## 2. 目录与版本：功能版换目录（与 Android 一致）

版本格式固定 **`1.X.Y`**：`X` 是功能位，`Y` 是修复位。

| 场景 | 示例 | 动作 |
| --- | --- | --- |
| 修复版（第三位 +1） | 1.0.0 → 1.0.1 | 原地改 `OJIPA/code/1`；`CURRENT_PROJECT_VERSION` 加 1 |
| 功能版（第二位 +1） | 1.0.x → 1.1.0 | **新建** `OJIPA/code/2` 与 `OJIPA/ipa/2`（`cp -r code/1 code/2`，删掉 `build/`、`out/`、`*.xcodeproj`、`Support/`） |
| 大版本（首位 +1） | 1.x → 2.0.0 | 接着本线最后一个目录往后排（如 1.x 用到 `code/7`，则 2.0 用 `code/8`） |

- **目录号 `N = X + 1`**：1.0→`code/1`，1.1→`code/2`，1.2→`code/3`，1.3→`code/4`，与 Android 的编号规则完全一致。
- 已按此规则重排过一次历史：P0=1.0.0→`code/1`，P1=1.1.0→`code/2`，P2=1.2.0→`code/3`；旧的 0.1.0/0.2.0 归档在 `backup/legacy-ios-releases/`，不再引用。
- `code/N` 里只保留这条线**最新**的源码；旧版本靠 git tag 追溯。
- `ipa/N` 里保留这条线**所有**发布过的 IPA，只增不删。

> ⚠️ `build_ipa.sh` 里的输出目录是**写死**的：
> ```bash
> OUTDIR="../../ipa/7"
> ```
> 进大版本、新建 `ipa/8` 之后必须同步改这一行，否则产物会落回旧目录。
>
> `build_ipa.sh` 是**本地开发脚本**，只留在 `OJIPA/code/N`，不进公开仓库。

---

## 3. 版本号

只有一处源头：`project.yml`

```yaml
settings:
  base:
    MARKETING_VERSION: "1.3.0"
    CURRENT_PROJECT_VERSION: "4"
```

- `Info.plist` 由 XcodeGen 从 `project.yml` 生成，**不要手改**。
- `CURRENT_PROJECT_VERSION` 必须比上一版大；同版本号的包覆盖安装时系统才认"更新"。
- tag 名与 `MARKETING_VERSION` 必须一致（打 `v1.3.0` 前先确认 `project.yml` 里就是 `1.3.0`）。查历史版本源码：`git show v1.0.0:project.yml | grep MARKETING`。
- **先定号，再动代码**：每次开发/更新，如果用户没说要发哪个版本，先问清「这次是 `1.X.Y` 的哪一版」，得到答复后再改 `project.yml`。不要自行推测版本号，也不要先改代码再补问。

---

## 4. 构建

### 4.1 Windows（日常路径）

本机不能编译 iOS，走 CI：

1. 在 `OJIPA/code/N` 改完，同步到本仓库（见第 6 节）；
2. **本机不能 `git push`**：本地 `git add/commit` 后，用 `python ../../test-artifacts/gh_push_api.py` 推 main，`python ../../test-artifacts/gh_tag.py vX.Y.Z` 打 tag（原因与脚本说明见总规则第 16 节）；
3. Actions 的 `build-ipa` 工作流在 `macos-15` 上跑：`brew install xcodegen` → `xcodegen generate` → `xcodebuild ... CODE_SIGNING_ALLOWED=NO` → 打 `OJHelper-<ver>-<build>-unsigned.ipa`；
4. 产物在 Actions artifact `OJHelper-unsigned-ipa`（`gh_wait2.py` 等结果、`gh_dl2.py` 下载）；打 tag 时 `softprops/action-gh-release` 会**自动建 Release**。

> CI 现在会同时打包 `OJHelper-<ver>-<build>-unsigned.ipa` 与 `OJHelper-<ver>-<build>-src.zip`（`git archive` 导出 + 脱敏 LICENSE），打 tag 时两个附件一起挂到 Release；**规则要求 Release 只有这两个附件，不放 `sha256.txt`**。

### 4.2 macOS（有 Mac 时）

```bash
cd OJIPA/code/N
brew install xcodegen        # 只需一次
bash build_ipa.sh            # 产物写到 ../../ipa/N/
```

`build_ipa.sh` 做的事：`xcodegen generate` → `xcodebuild`（Release / iphoneos / 不签名）→ 从 `Info.plist` 读版本号 → `Payload/` 打包成 ipa → 复制到 `ipa/N/` 并写 `sha256.txt`。

想在 Xcode 里调试：

```bash
xcodegen generate
open OJHelper.xcodeproj      # 这个 .xcodeproj 是生成物，不进仓库
```

---

## 5. 本地开发踩坑

| 坑 | 说明 |
| --- | --- |
| **日历权限串** | iOS 17+ 只要"写入"就用 `NSCalendarsWriteOnlyAccessUsageDescription`；本工程两者都写了（`NSCalendarsWriteOnlyAccessUsageDescription` + `NSCalendarsUsageDescription`） |
| **生成式 Info.plist 不认权限键** | 用 `GENERATE_INFOPLIST_FILE=YES` + `INFOPLIST_KEY_NSCalendars*` 时这些键会被吞掉，必须像现在这样用显式 `Support/Info.plist`（`GENERATE_INFOPLIST_FILE: NO`） |
| **deploymentTarget 17.0** | 低于 17 的 Calendar 权限 API 是另一套（`NSCalendarsUsageDescription` 单一权限），改 target 时权限代码要跟着改 |
| **bundle id 固定 `com.ojhelper.ios`** | 改 bundle id 等于新 App：旧数据、通知授权全丢，且不能覆盖安装 |
| **免费签名 7 天** | 过期后 App 直接打不开，之前设的本地通知全部失效；重新签一次即可（数据还在容器里） |
| **`.xcodeproj` 不要提交** | 它由 `project.yml` 生成，两个都提交必然冲突；`.gitignore` 已排除 |
| **`build/`、`DerivedData/`、`out/`** | 中间产物，`git status` 里出现就是漏了 `.gitignore` |
| **两处资源名必须对齐** | `Assets.xcassets` 里的 imageset 名（`logo_cf`、`logo_atcoder`、`logo_luogu`、`logo_lanqiao`、`logo_lc`、`logo_nowcoder`）必须与代码里 `Image("logo_...")` 字符串完全一致，否则不报错、只是空白 |
| **workflow 只在仓库里改** | `.github/workflows/ios.yml` 只存在于本仓库；工作区 `OJIPA/code/N` 里不留副本，避免两份漂移。要改 CI 直接改仓库里的文件 |
| **`Support/Info.plist` 不进仓库** | 它由 XcodeGen 按 `project.yml` 的 `info:` 段生成，属于构建产物，`git status` 里出现就是漏了忽略规则 |
| **本机 `git push` 不可用** | DNS 污染 + schannel 凭据失败 + 沙箱禁管道，直接用 `gh_push_api.py` / `gh_tag.py`，别反复重试 `git push`（详见总规则第 16 节） |

---

## 6. 同步到本仓库

本仓库只维护**一份摊平的源码**：

```bash
cd cp-navigator-ios
rm -rf OJHelper
cp -r ../OJIPA/code/N/OJHelper .
cp ../OJIPA/code/N/project.yml .
git add -A
git status --short          # 只应看到 OJHelper/** 与 project.yml
git commit -m "1.3.0：<一句话改动>"
python ../../test-artifacts/gh_push_api.py         # 本机不能 git push
python ../../test-artifacts/gh_tag.py v1.3.0       # 等 CI 绿后再打 tag
```

- **只同步 `OJHelper/` 与 `project.yml`**。`.github/workflows/ios.yml`、`README.md`、`DEVELOPING.md` 只在仓库里改；如果工作区里有多余副本，删掉工作区那份。
- `--tags` 不能漏，否则远端没有 tag，Release 也就选不到（用 `gh_tag.py` 时它负责在远端 HEAD 上建 tag）。
- tag 只追加：已发布的 tag 不删、不移动；打错了就重建仓库目录，**不要 `git tag -d`**（本环境的安全策略会拦下这种"重写历史"的操作）。
- Windows 上跨盘 `cd` 要写 `cd /d D:\...`。

---

## 7. Release 附件

每个 Release **只挂两个文件**：

| 附件 | 来源 | 说明 |
| --- | --- | --- |
| `OJHelper-<版本>-<build>-unsigned.ipa` | Actions artifact 或 `OJIPA/ipa/N/` | 需用户自签；正文写清签名方式与有效期 |
| `OJHelper-<版本>-<build>-src.zip` | 本地脚本生成 | **脱敏源码** |

生成脱敏源码 zip：

```bash
python ../OJIPA/tools/make_ios_src_zip.py --ref v1.0.0    # 生成 + 扫描
python ../OJIPA/tools/make_ios_src_zip.py --check         # 只扫描已有 zip
```

它做的事：`git archive` 导出被跟踪文件（所以**没有 `.git/`，提交作者邮箱不会泄露**）→ 把 `LICENSE` 版权人换成 `CP Navigator contributors` → 剔除 `build/`、`DerivedData/`、`*.xcodeproj`、`.DS_Store` → 整包再扫一遍令牌 / 邮箱 / 个人账号 / 本机绝对路径 / `DEVELOPMENT_TEAM`，命中即失败。

线上附件对齐（补 `-src.zip`、删历史遗留的 `sha256.txt`）：

```bash
python ../OJIPA/tools/publish_ios_assets.py            # dry-run
python ../OJIPA/tools/publish_ios_assets.py --yes      # 真跑，需要 GITHUB_TOKEN
```

❌ 不上传：`sha256.txt`（校验值写正文，附件条目本身就显示）、`*.p12`、`*.mobileprovision`、`*.cer`、`.git`。
**发布顺序从旧到新**：GitHub 按发布时间判定 `Latest`。

> 本机限制：`uploads.github.com` 在这里一律 404/400，`publish_ios_assets.py` **只能 dry-run**；真正补附件要在能连 GitHub 上传端点的机器上跑，或改成让 CI 一起产 `-src.zip`。无论用哪种方式，Release 最终必须只有 `ipa` + `-src.zip` 两个附件。

---

## 8. 本仓库的内容边界

✅ 上传：`OJHelper/**`、`project.yml`、`.github/workflows/ios.yml`、`README.md`、`DEVELOPING.md`、`LICENSE`、`.gitignore`、`.gitattributes`。

❌ 不上传：`*.xcodeproj` / `*.xcworkspace`（生成物）、`build/` / `DerivedData/` / `out/`、`*.ipa`、`*.p12` / `*.mobileprovision` / `*.cer`、`.DS_Store` / `xcuserdata/`、`build_ipa.sh`（本地脚本）、`Support/Info.plist`（生成物）、任何绝对路径、任何令牌。

提交前自检：

```bash
git status --short
git ls-files | grep -cE '(^|/)(build|out|DerivedData)/|^[^/]+\.xcodeproj/|\.(ipa|p12|mobileprovision|cer)$|build_ipa\.sh$'   # 必须是 0
git grep -nE 'D:(\\|/)aiwork'                                                    # 必须无输出
git grep -niE "ghp_[A-Za-z0-9]{20,}|/Users/[A-Za-z]"                             # 必须无输出
```

> 注意正则写法：单引号里的 `\\` 传给 grep 的是「一个反斜杠」，所以 `D:(\\|/)aiwork` 才能匹配 `D:\aiwork` 和 `D:/aiwork`；写成 `\\\\` 反而只匹配两个连续反斜杠，永远 0 命中。`.xcodeproj` 的检查要抓「目录」形式（`Foo.xcodeproj/project.pbxproj`），所以用 `^[^/]+\.xcodeproj/` 而不是 `\.xcodeproj$`。

令牌可以明文留在本地 `.git/config` 里（省得每次登录），但**不得出现在任何提交、md、脚本、截图里**；文档里一律写 `ghp_xxx` 占位。发现进过仓库就立刻吊销重发。

---

## 9. 发布 checklist

每次发版从 `check/README.md` 的清单逐项打勾，iOS 这边至少要过下面这些：

**版本与工程**

- [ ] 用户确认过版本号，`project.yml` 的 `MARKETING_VERSION` = `1.X.Y`、`CURRENT_PROJECT_VERSION` = 上一版 +1
- [ ] tag 名与 `MARKETING_VERSION` 一致（`v1.X.Y`）
- [ ] `project.yml`：`info: path: Support/Info.plist`、`GENERATE_INFOPLIST_FILE: NO`、bundle id 仍是 `com.ojhelper.ios`、deploymentTarget 17.0
- [ ] 生成的 `Info.plist` 里有 `NSCalendarsWriteOnlyAccessUsageDescription`（和 `NSCalendarsUsageDescription`）

**仓库**

- [ ] 只同步了 `OJHelper/**` 与 `project.yml`，`git status --short` 没有多余文件
- [ ] 没有 `build_ipa.sh`、`Support/Info.plist`、`*.xcodeproj`、`*.ipa`
- [ ] 绝对路径 / token 扫描 0 命中（第 8 节）
- [ ] `.github/workflows/ios.yml` 是在**仓库里**改的，工作区没有第二份

**CI 与产物**

- [ ] `gh_wait2.py` 显示最新 run 绿
- [ ] 下载的 IPA 名形如 `OJHelper-1.X.Y-<build>-unsigned.ipa`，解包后 Info.plist 的版本、bundle id、`MinimumOSVersion` 都对
- [ ] `Assets.car` 和 6 个 logo 都在包里（`unzip -l` 抽查）

**Release**

- [ ] Release 只有 `ipa` + `-src.zip` 两个附件，没有 `sha256.txt`
- [ ] 正文写清安装方式（Sideloadly）、7 天签名限制、本版改动
- [ ] Latest 指向本版（从旧到新发布）
- [ ] 本地归档 `OJIPA/ipa/7/` 与 `cp-navigator-ios-releases/vX.Y.Z/` 各存一份 IPA + `sha256.txt`

**真机**

- [ ] 安装后首次打开能弹通知权限
- [ ] 比赛页**不自动查询**；点「查询」后六站出结果或按站显示失败
- [ ] 铃铛设「提前 10 分钟」→ 到点收到通知且标题是「比赛将在 10 分钟后开始」
- [ ] 「日历」→ 系统日历确认页预填标题/备注/北京时间，保存后事件在日历里
- [ ] 收藏星标、按平台/按日期切换、下拉刷新都正常

**文档**

- [ ] `cp-navigator-ios/README.md` 版本/功能已更新
- [ ] `cp-navigator-ios-releases/README.md` 版本表已加本版
- [ ] 总规则或本文件如涉及流程变化，已同步

## 10. 真机安装（未签名 IPA）

1. Windows 上装 [Sideloadly](https://sideloadly.io/)（或 AltStore / 爱思助手）；
2. 数据线连 iPhone，把 ipa 拖进去，填 Apple ID，Start；
3. 首次运行到「设置 → 通用 → VPN 与设备管理」信任开发者证书；
4. iOS 16+ 还需要在「设置 → 隐私与安全性 → 开发者模式」打开开关并重启；
5. 免费 Apple ID **7 天到期**，到期重签一次；付费账号 1 年。

不签名的包不能直接装，这是 iOS 的硬约束；本 App 不上架 App Store，所以不需要审核。