# iClassicTV

![Platform](https://img.shields.io/badge/Platform-iOS%206.0+-blue.svg)
![Language](https://img.shields.io/badge/Language-Objective--C-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**iClassicTV** 是一款专为 iOS 6 等拟物化老系统精心打造的 IPTV 直播流媒体播放器。它在极致还原经典拟物化 UI 视觉美感的同时，克服了老旧设备 SSL 证书过期、硬件解码性能受限等重重障碍，提供了媲美现代 App 的流畅直播体验。

---

## ✨ 核心特性 (Detailed Features)

### 🚀 极速直播流解析引擎
* **全格式兼容**：深度支持 `M3U`、`M3U8` 以及类 `TXT` 格式的直播源解析，内置 `M3UParser` 自动提取 `tvg-id`、`tvg-logo` 和 `group-title`。
* **智能源校验**：集成 `M3UValidator` 异步校验引擎，支持对直播源的有效性、连接延迟进行后台检测，自动过滤或标记失效线路。
* **层级化频道管理**：通过 `TVSearchManager` 实现秒级的全库搜索，支持按分组目录深度分类，让上千个频道也井然有序。

### 📅 全能型电子节目指南 (EPG System)
* **XMLTV 深度解析**：自研 `EPGParser` 逻辑，完美解析海量 XMLTV 数据，支持节目名称、简介、开始/结束时间的精确提取。
* **四级缓存架构**：依托 `EPGManager+Cache` 实现“内存-磁盘-网络”的高效同步。即便在离线状态下，也能快速呼出已缓存的节目单。
* **时间轴追踪**：播放界面实时显示“正在播放”进度条，支持 EPG 跨天查询与日期快速切换。

### ⭐ 闭环式片单管理 (WatchList)
* **❤️ 深度收藏系统**：支持对频道进行多维度的收藏管理，采用持久化存储保证数据在系统更新后不丢失。
* **🕒 精确播放历史**：自动记录最后观看的频道与线路，支持“继续观看”功能。
- **⏰ 智能预约提醒**：结合本地通知系统，对 EPG 中未来的节目进行预约。程序会自动计算时间，确保您不会错过重要赛事或节目。

### 🛠 针对旧设备的底层黑科技
* **🔒 SSL 证书绕过**：通过 `SSLBypassHelper` 动态处理握手协议，彻底修复老系统因根证书过期导致的 `NSURLErrorDomain -1202` 错误，支持所有 HTTPS 资源。
* **🎭 全局 UA 伪装**：内置 `UserAgentManager`，支持模拟各种现代浏览器、机顶盒或移动设备的请求头，轻松突破直播源的防盗链限制。
* **📱 极致性能优化**：针对 armv7 架构微调 `PlayerConfigManager` 缓冲区大小，优化 `UITableView` 的滑动重用逻辑，确保在 iPhone 4S/5 上依然纵滑丝滑。

---

## 📂 详尽代码目录树 (Project Structure)

```text
iClassicTV/
├── App/                          # 核心启动入口
│   ├── AppDelegate.h/m           # 应用生命周期管理、全局 UI 初始化
│   └── main.m                    # C 入口函数
├── Core/                         # 基础解析引擎
│   ├── LanguageManager.h/m       # 多语言动态切换逻辑
│   ├── M3UParser.h/m             # M3U 标准协议解析器
│   └── M3UValidator.h/m          # 直播源连接可用性校验工具
├── Features/                     # 核心业务功能模块
│   ├── EPG/                      # EPG 节目单全家桶
│   │   ├── EPGManager.h/m        # EPG 调度中心 (Query/Update/Sources)
│   │   ├── EPGParser.h/m         # XMLTV 格式解析核心
│   │   ├── EPGProgram.h/m        # 节目数据模型
│   │   └── ViewControllers...    # 节目单列表、源管理界面
│   ├── Live/                     # 直播逻辑
│   │   ├── GroupListVC.h/m       # 频道分组展示 (拟物化列表)
│   │   └── ChannelListVC.h/m     # 频道选择与筛选逻辑
│   ├── Player/                   # 播放器核心视图
│   │   ├── TVPlaybackVC.h/m      # 播放器主控制器 (Player/UI/EPG 分类)
│   │   ├── TVPlaybackOverlay.h/m # 播放控制层 (进度条、按钮组)
│   │   ├── PlayerEPGView.h/m     # 播放器内嵌节目单滑块视图
│   │   └── TVUIComponents.h/m    # 锁屏、比例切换等自定义 UI 控件
│   ├── Settings/                 # 系统设置与工具
│   │   ├── UAManager.h/m         # User-Agent 伪装配置
│   │   ├── SourceManager.h/m     # 多源管理与扫描
│   │   ├── DataManagement.h/m    # 缓存清理与存储统计
│   │   └── AboutVC.h/m           # 版本信息与致谢
│   └── WatchList/                # 个人数据管理
│       ├── WatchListManager.h/m  # 收藏、历史、预约的数据持久化
│       └── ViewControllers...    # 对应的收藏/历史/预约列表界面
├── Models/                       # 数据模型层
│   └── Channel.h/m               # 直播频道核心模型 (含多线路逻辑)
├── Modules/                      # 通用工具组件库
│   ├── NetworkManager.h/m        # 针对旧系统的网络请求封装
│   ├── SSLBypassHelper.h/m       # 安全传输协议降级与证书忽略助手
│   ├── PlayerConfigManager.h/m   # 播放内核参数调优 (Buffer/Cache)
│   ├── TVSearchManager.h/m       # 频道全局快速搜索引擎
│   ├── UIStyleHelper.h/m         # 拟物化风格样式库 (颜色、圆角)
│   └── Extensions...             # NSString/UIImage 等各种分类助手
├── Resources/                    # 静态资产
│   ├── Images.xcassets           # 拟物化图标、启动页、AppIcon
│   └── iClassicTV-Info.plist     # 系统配置文件
└── i18n/                         # 国际化本地化包
    ├── zh-CN.json                # 简体中文语言定义
    └── en-US.json                # 英文语言定义
```

---

## 📖 使用指南 (Usage Guide)

### 1. 导入直播源
您可以点击 **【设置】** -> **【直播源管理】** -> **【+】**，选择：
* **网络导入**: 输入 M3U 链接，点击下载，支持自动检测编码。
* **本地文本**: 直接粘贴 M3U 源代码，适合快速调试。
* **iTunes 共享**: 将文件命名为 `.m3u` 通过 iTunes 导入 Documents 目录后点击系统内的“扫描本地文件”。

### 2. 播放交互技巧
* **单击屏幕**: 唤起顶部/底部控制栏，左划或右划底部可查看前后节目。
* **双击屏幕**: 循环切换 `16:9`、`4:3` 以及 `全屏拉伸` 模式。
* **左侧锁头**: 一键锁定 UI，防止横屏观看时误触导致播放中断。
* **下拉刷新**: 在频道列表界面下拉，即可触发网络源的实时同步。

### 3. 高阶调试
若某些频道无法加载，请尝试：
1. 前往 **【设置】** -> **【UA 管理】** 切换为 `VLC` 或 `iPhone`。
2. 确认 **【网络设置】** 中的 SSL 绕过开关已开启。

### 4. 推荐 M3U 格式
为了获得最佳的分组、线路聚合以及 EPG 匹配体验，建议源文件包含 `group-title` 和 `tvg-name` 标签：
```text
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="logo.png" group-title="央视",CCTV-1 综合
http://source1.m3u8
#EXTINF:-1 tvg-name="CCTV1" group-title="央视",CCTV-1 综合
http://source2.m3u8
#EXTINF:-1 tvg-name="CCTV4K" group-title="央视",CCTV4K 超高清
http://source3.m3u8
```

---

## 🚀 编译运行 (Build)

1. 环境：**Xcode 5.x - 7.x**（推荐在 macOS High Sierra 或更早版本运行）。
2. 架构：确保项目的 Base SDK 指向 **iOS 6.0** 或以上，支持 `armv7/armv7s`。
3. 签名：真机运行需具备有效的开发证书，或在越狱设备上使用 `AppSync`。

---

## 📄 许可证 (License)

本项目基于 MIT 许可证开源。请在保留原作者版权信息的前提下进行二次开发。