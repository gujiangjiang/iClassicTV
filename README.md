# 📺 iClassicTV (Native iOS 6 Edition)

**iClassicTV** 是一款专为怀旧党和老旧 iOS 设备（如 iPhone 4/4s、iPad 2/3）打造的 **纯原生** IPTV / M3U 直播源播放器。

本项目不仅是 [iClassicTV Web版](https://github.com/gujiangjiang/iclassictv) 的完全重构，更是一次针对 iOS 6 拟物化美学的深度致敬。它摒弃了现代 Web 容器的臃肿，直接基于 **Objective-C** 和 **UIKit** 构建，在“古董”设备上也能实现丝滑流畅的直播体验。

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
* **📂 强大的 M3U 管理与导入**:
    * **多维导入**: 支持网络 URL 下载、手动文本粘贴。
    * **iTunes 文件共享**: 可通过电脑 iTunes 软件直接将 `.m3u` 文件拖入应用，并在软件内一键扫描导入。
    * **系统关联支持**: 深度集成 iOS “Open In...” 机制，在 Safari 或邮件中下载的 M3U 文件可直接选择“使用 iClassicTV 打开”自动导入。
    * **网络源同步**: 支持一键从服务器刷新同步最新的网络直播源内容。
* **🏗️ 现代化的工程架构**:
    * **逻辑与视图分离**: 播放器采用 `PlayerControlView` 与 `PlayerViewController` 拆分架构，代码清晰，易于扩展 EPG、录屏等后续功能。
    * **动态图标模块**: 核心 UI 图标均通过 Core Graphics 动态绘制，无损适配不同分辨率，减少安装包体积。
    * **智能线路记忆**: 针对支持多线路的频道，系统会自动记忆您的线路偏好，并具备失效自动回退机制。

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
您可以点击 **【设置】->【我的直播源】->【+】**，选择：
* **网络导入**: 输入 M3U 链接，点击下载。
* **本地文本**: 直接粘贴 M3U 源代码。
* **iTunes 共享**: 将文件命名为 `.m3u` 通过 iTunes 导入 Documents 目录后点击扫描。

### 2. 播放交互
* **单击屏幕**: 显隐顶部/底部控制栏。
* **双击屏幕**: 快速切换全屏/窗口模式。
* **左侧锁头**: 点击锁定屏幕交互，再次点击解锁。
* **列表刷新**: 对于网络源，可在频道分组列表页右上角直接点击“刷新”图标同步服务器最新数据。

### 3. 推荐 M3U 格式
为了获得最佳的分组和线路聚合体验，建议源文件包含 `group-title` 和 `tvg-name`：

```m3u
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="logo.png" group-title="央视",CCTV-1 综合
http://source1.m3u8
#EXTINF:-1 tvg-name="CCTV1" group-title="央视",CCTV-1 综合
http://source2.m3u8
```

---

## 🤝 贡献与反馈

欢迎提交 Issue 或 Pull Request 来帮助完善项目。我们特别关注：
- 对 iOS 6.x 不同小版本（如 6.1.3 与 6.0）的 UI 微调适配。
- EPG (电子节目指南) 标签的解析逻辑增强。

---

## 📄 开源协议

本项目基于 **MIT License** 开源。
Copyright (c) 2026 gujiangjiang.