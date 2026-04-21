# 📺 iClassicTV (Native iOS 6 Edition)

**iClassicTV** 是一款专为怀旧党和老旧 iOS 设备（如 iPhone 4/4s、iPad 2/3）打造的 **纯原生** IPTV / M3U 直播源播放器。

本项目是 [iClassicTV Web版](https://github.com/gujiangjiang/iclassictv) 的完全重构版本。它摒弃了浏览器容器，直接基于 **Objective-C** 和 **UIKit** 构建，旨在通过 iOS 6 标志性的拟物化（Skeuomorphism）界面，提供极致流畅的直播观影体验。

---

## ✨ 核心特性

* **🕰️ 纯正拟物化 UI**: 完美利用 iOS 6 原生 `UITableView` 和 `UINavigationController`。无需 CSS 模拟，即可获得最真实的蓝灰渐变导航栏和立体触感。
* **🚀 硬件级解码播放**: 采用系统原生的 `MPMoviePlayerViewController` 进行 HLS (.m3u8) 硬件加速解码，比网页版更省电、更流畅。
* **🔍 深度优化的 M3U 解析**:
    * **4K 保护逻辑**: 特别优化正则解析，确保 `CCTV 4K`、`576` 分辨率标识等频道名不会被错误裁剪。
    * **物理顺序对齐**: 频道列表严格遵循 M3U 文件中的原始物理顺序，不再出现乱序问题。
* **⚡️ GCD 异步架构**: 使用多线程后台解析海量直播源，即使导入数千个频道，主界面依然丝滑不卡顿。

---

## 🛠️ 编译与部署

由于本项目致力于兼容“古董”设备，请遵循以下环境要求：

* **IDE**: 建议使用 **Xcode 5.1.1**（运行在 OS X 10.9 Mavericks 效果最佳）。
* **最低版本**: iOS 6.0 (Deployment Target: 6.0)。
* **架构**: 支持 `armv7` (iPhone 4/4s) 及模拟器 `i386`。
* **关键配置**:
    * 需在 `Info.plist` 中配置 `App Transport Security`（若在较高系统运行）以允许 HTTP 流。
    * 建议真机配合越狱插件 `AppSync` 使用以简化调试。

---

## 📖 使用指南

### 1. 导入直播源
在“导入”标签页，你可以选择：
* **网络导入**: 输入 M3U 链接，点击“下载并载入”。
* **手动输入**: 直接粘贴 M3U 文本内容。

### 2. 交互逻辑
* **点击频道**: 直接播放。

### 3. 推荐 M3U 格式
为了获得最佳的分组和记忆体验，建议源文件包含 `group-title` 和 `tvg-name`：

```m3u
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="logo.png" group-title="央视",CCTV-1 综合
http://source1.m3u8
#EXTINF:-1 tvg-name="CCTV1" group-title="央视",CCTV-1 综合
http://source2.m3u8
```

---

## 🤝 贡献与反馈

欢迎提交 Issue 或 Pull Request 来帮助完善项目。我们特别欢迎关于：
- 修复在特定 iOS 6.x 小版本上的 UI 适配问题。
- 增强 M3U 标签（如 EPG 支持）的解析逻辑。

---

## 📄 开源协议

本项目基于 **MIT License** 开源。详见 [LICENSE](./LICENSE) 文件。