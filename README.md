# 📺 iClassicTV (Native iOS 6 Edition)

**iClassicTV** 是一款专为怀旧党和老旧 iOS 设备（如 iPhone 4/4s、iPad 2/3）打造的 **纯原生** IPTV / M3U 直播源播放器。

本项目不仅是 iClassicTV Web版 的完全重构，更是一次针对 iOS 6 拟物化美学的深度致敬。它摒弃了现代 Web 容器的臃肿，直接基于 **Objective-C** 和 **UIKit** 构建，在“古董”设备上也能实现丝滑流畅的直播体验。

---

## ✨ 核心特性

* **🕰️ 纯正拟物化 UI**: 完美利用 iOS 6 原生 `UITableView` 和 `UINavigationController`。无需 CSS 模拟，即可获得最真实的蓝灰渐变导航栏和立体触感。
* **🚀 硬件级解码播放**: 采用系统原生的 `MPMoviePlayerController` 内核，支持 HLS (.m3u8) 硬件加速解码，比网页版更省电、发热更低。
* **🎧 全面的后台体验**:
    * **后台音频**: 支持在应用最小化或锁屏状态下继续播放直播声音。
    * **锁屏控制**: 集成 `MPNowPlayingInfoCenter`，在锁屏界面显示频道 Logo 及名称，并支持通过线控或系统控制中心切换播放/暂停。
* **🔒 深度优化的播放交互**:
    * **防误触锁定**: 播放器内置半透明锁定按钮，锁定后隐藏所有控制条，防止观看时的意外操作。
    * **智能状态反馈**: 自动识别并提示“纯音频/电台”模式，并针对缓冲、解析失败提供友好的 Emoji 提示。
* **📡 全方位电子节目指南 (EPG)**:
    * 内置高效的 `EPGParser`，支持 XMLTV 格式的节目单实时解析。
    * 播放器内部集成 `PlayerEPGView`，可在不中断播放的情况下随时调出当前及后续节目预告。
* **📂 强大的 M3U 管理与导入**:
    * **多维导入**: 支持网络 URL 下载、手动文本粘贴。
    * **iTunes 文件共享**: 可通过电脑 iTunes 软件直接将 `.m3u` 文件拖入应用，并在软件内一键扫描导入。
    * **系统关联支持**: 深度集成 iOS “Open In...” 机制，在 Safari 或邮件中下载的 M3U 文件可直接选择自动导入。
    * **网络源同步**: 支持一键从服务器刷新同步最新的网络直播源内容。
* **🧠 智能频道解析与线路记忆**:
    * 自动聚合相同频道名称的多条线路，具备失效自动回退机制并记忆您的线路偏好。
    * 精准的频道名清洗过滤逻辑，智能去除冗余分辨率标签，同时严格保留 `CCTV4K` 和 `CCTV8K` 等作为固定独立频道的原始标识，确保台标与 EPG 匹配无误。
* **🌐 老旧系统网络兼容增强**:
    * 针对 iOS 6 设备根证书过期导致无法播放现代 HTTPS (Let's Encrypt 等) 链接的问题，底层实现了 `SSLBypassHelper` 以保障网络源的畅通。
    * 内置 `UserAgentManager` (UA管理器)，支持自定义请求头，以绕过部分 IPTV 供应商的访问限制。
* **🌍 原生多语言支持 (i18n)**:
    * 架构已完整接入 `LanguageManager`，原生支持简体中文 (zh-CN) 与英文 (en-US) 的无缝切换。

---

## 📂 项目代码目录树

```text
iClassicTV-Project
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md
└── iClassicTV
    ├── iClassicTV.xcodeproj                 # Xcode 项目工程文件配置
    ├── iClassicTV
    │   ├── App                              # 应用生命周期与全局配置 (AppDelegate, main)
    │   ├── Core                             # 核心引擎层 
    │   │   ├── LanguageManager.[h/m]        # 国际化语言切换中心
    │   │   └── M3UParser.[h/m]              # M3U 播放列表核心解析器
    │   ├── Features                         # 核心业务逻辑模块
    │   │   ├── EPG                          # 电子节目指南 (数据模型、XMLTV解析、控制器)
    │   │   ├── Live                         # 直播模块 (频道列表、分组管理)
    │   │   ├── Player                       # 播放器组件 (覆盖交互层、EPG浮窗、核心播放控制)
    │   │   └── Settings                     # 设置中心 (UA管理、源导入/导出、播放偏好、数据管理)
    │   ├── Models                           # 数据模型实体 (Channel 频道定义)
    │   ├── Modules                          # 通用工具与系统扩展
    │   │   ├── AlertHelper / ToastHelper    # 拟物化风格的弹窗与提示组件
    │   │   ├── NetworkManager               # 轻量级网络请求封装
    │   │   ├── SSLBypassHelper              # [核心] iOS 6 根证书失效及 HTTPS 访问修复机制
    │   │   └── UIImage+*.h/m                # 动态图标绘制引擎与 Logo 处理辅助类
    │   ├── Resources                        # 静态资源 (Images.xcassets, Info.plist, PCH配置)
    │   └── i18n                             # 语言包定义配置 (en-US.json, zh-CN.json)
    └── iClassicTVTests                      # 单元测试用例目录
```

---

## 🛠️ 编译与部署

由于本项目致力于兼容“古董”设备，请遵循以下环境要求：

* **IDE**: 建议使用 **Xcode 5.1.1** (运行在 OS X 10.9 Mavericks 效果最佳)。
* **最低版本**: iOS 6.0 (Deployment Target: 6.0)。
* **架构**: 支持 `armv7` (iPhone 3GS/4/4s/5) 及模拟器 `i386`。
* **关键配置**:
    * 项目已配置 `UIBackgroundModes` 为 `audio` 以支持后台播放。
    * 项目已开启 `UIFileSharingEnabled` 以支持 iTunes 文件传输。
    * 建议真机配合越狱插件 `AppSync` 使用以简化调试安装。

---

## 📖 使用指南

### 1. 导入直播源
您可以点击 **【设置】->【直播源管理】->【+】**，选择：
* **网络导入**: 输入 M3U 链接，点击下载。
* **本地文本**: 直接粘贴 M3U 源代码。
* **iTunes 共享**: 将文件命名为 `.m3u` 通过 iTunes 导入 Documents 目录后点击系统内的扫描。

### 2. 播放交互
* **单击屏幕**: 显隐顶部/底部控制栏及 EPG 节目预告。
* **双击屏幕**: 快速切换全屏/等比缩放窗口模式。
* **左侧锁头**: 点击锁定屏幕交互（隐藏所有控件，防误触），再次点击对应位置解锁。
* **列表刷新**: 对于网络源，可在频道分组列表页右上角直接点击“刷新”图标同步服务器最新数据。

### 3. 高阶网络设置
* 若直播源存在限制访问情况，请前往 **【设置】->【用户代理 (UA) 管理】**，修改全局 User-Agent 以进行伪装。

### 4. 推荐 M3U 格式
为了获得最佳的分组、线路聚合以及 EPG 匹配体验，建议源文件包含 `group-title` 和 `tvg-name` 标签：

```m3u
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="logo.png" group-title="央视",CCTV-1 综合
http://source1.m3u8
#EXTINF:-1 tvg-name="CCTV1" group-title="央视",CCTV-1 综合
http://source2.m3u8
#EXTINF:-1 tvg-name="CCTV4K" group-title="央视",CCTV4K 超高清
http://source3.m3u8
```

---

## 🤝 贡献与反馈

欢迎提交 Issue 或 Pull Request 来帮助完善项目。我们特别关注：
- 对 iOS 6.x 不同小版本（如 6.1.3 与 6.0）底层 `MPMoviePlayerController` 的边界异常处理优化。
- EPG 数据缓存机制的进一步性能优化。

---

## 📄 开源协议

本项目基于 **MIT License** 开源。
Copyright (c) 2026 gujiangjiang.