# TuckBar

<p align="center">
  <img src="Resources/TuckBarBrand.png" alt="TuckBar Logo" width="128" height="128">
</p>

<p align="center">
  <b>轻量、可靠的 macOS 菜单栏收纳工具</b><br>
  收起暂时不用的菜单栏图标，并在需要时快速展开。
</p>

<p align="center">
  <a href="https://github.com/lglglglglg/TuckBar/releases">下载</a> ·
  <a href="https://github.com/lglglglglg/TuckBar/issues">问题反馈</a> ·
  <a href="PRIVACY.md">隐私政策</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-0.9.8-purple" alt="Version 0.9.8">
</p>

## 关于 TuckBar

TuckBar 用于整理 macOS 菜单栏，尤其适合菜单栏图标较多或使用刘海屏 MacBook 的场景。它直接操作真实菜单栏项目，不使用静态截图代替原应用的菜单与弹窗。

## 主要功能

- 提供原生菜单栏展开折叠和第二行紧凑浮窗两种展示模式。
- 将菜单栏项目分为“常显”“收纳”和“始终隐藏”三个区域。
- 调用真实菜单栏项目，保留宿主应用原有的点击、菜单和弹窗行为。
- 支持单击、悬停、滚轮、触控板手势和全局快捷键。
- 展开后可在鼠标停留期间暂停自动收起。
- 在设置中筛选项目、查看运行状态并批量调整分区。
- 可从浮窗右键调整项目分区，或在 Finder 中定位对应应用。

## 下载与安装

TuckBar 需要 macOS 14.0 或更高版本。

前往 [GitHub Releases](https://github.com/lglglglglg/TuckBar/releases) 下载最新版本：

- **DMG（推荐）**：打开安装镜像，将 `TuckBar.app` 拖入“应用程序”文件夹。
- **ZIP**：解压后，将 `TuckBar.app` 移入“应用程序”文件夹。

首次使用时，请按系统提示授予辅助功能和屏幕录制权限；这两项权限用于识别、操作和显示菜单栏项目。

## 快速使用

| 动作 | 操作方式 |
| --- | --- |
| 展开或收起菜单栏 | 单击 TuckBar 图标，或按 `⌥B` |
| 使用手势展开或收起 | 在菜单栏区域向上/向左滚动展开，向下/向右滚动收起 |
| 临时查看收纳项目 | 将鼠标悬停在 TuckBar 图标上方，可在设置中关闭 |
| 打开快捷菜单 | 右键点击 TuckBar 图标 |
| 调整浮窗项目分区 | 在聚合浮窗中右键点击项目 |
| 打开偏好设置 | 从右键菜单进入，或按 `⌘,` |

## 隐私与权限

TuckBar 不提供账号、遥测、广告或网络服务。菜单栏布局和偏好设置只保存在本机，详情见[隐私政策](PRIVACY.md)。

- **辅助功能**：识别菜单栏项目，并执行用户发起的点击、排序和收纳操作。
- **屏幕录制**：通过 `ScreenCaptureKit` 获取单个菜单栏图标的快照，用于浮窗和设置列表；不持续录制屏幕，也不保存桌面截图。

TuckBar 不监听键盘输入，不读取密码，也不上传菜单栏或应用信息。

## 开发构建

需要 macOS 14.0+、Xcode 15+、Swift 6 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
git clone https://github.com/lglglglglg/TuckBar.git
cd TuckBar
./scripts/package-stable.sh
```

构建产物位于 `dist/`，包括 `TuckBar.app`、`TuckBar-0.9.8.dmg` 和 `TuckBar-0.9.8.zip`。

## 开源与支持

- [问题反馈](https://github.com/lglglglglg/TuckBar/issues)
- [隐私政策](PRIVACY.md)
- 欢迎提交 Issue 和 Pull Request。

## 许可证与版权

TuckBar 基于 [MIT License](LICENSE) 开源。

© 2026 **Stephan Li** · 韩十久工作室（Hanshijiu Studio）
