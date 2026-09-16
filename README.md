# TuckBar

> 项目状态：v0.8.6 品牌图标与菜单栏可读性 Alpha
> 创建日期：2026-09-07

TuckBar 是一个独立的 macOS 菜单栏图标管理工具。它解决的核心问题是：菜单栏图标太多，尤其在带刘海的 MacBook 上，部分图标被挤到不可见区域；用户需要把低频图标收起，并在菜单栏下方的聚合面板中随时查看和点击。

## 已确认边界

- 本项目不是 Notchly 的模块、插件或配套功能。
- Notchly 只是一条真实需求来源：开发和使用 Notchly 时发现菜单栏图标会被刘海或顶部界面遮挡。
- 产品的使用路径和 UI 交互以 iBar 聚合模式为翻版基准，并吸收 Ice 的分区、触发器和效率能力；不复制两者品牌资产或受许可约束的代码。
- 首版优先解决“图标不消失、收起后仍能点到”，不追求菜单栏美化、复杂自动化或云同步。

## 第一版目标

1. 用户可把指定菜单栏图标分成“常显”和“收起”两组。
2. 一键、悬停或快捷键打开菜单栏下方的聚合面板。
3. 聚合面板显示真实图标状态，并能可靠触发原图标。
4. 兼容带刘海 Mac、无刘海 Mac 和外接显示器。
5. 权限用途透明，所有配置保存在本机。

## 当前结论

v0.4.0 已加入原始菜单栏项目执行引擎：用户勾选具体项目后，可显式应用隐藏设置。工具通过 macOS 原生 Command 拖动规则把项目移动到内部不可见边界左侧，再扩展透明占位区将其收起；打开面板或点击项目时会临时展开、重新识别并转发点击。界面没有可见分割线，也不会使用所属应用图标冒充原始状态。

详细分析见 [竞品与技术立项分析](docs/01-竞品与技术立项分析-20260907.md)。

当前开发记录见 [v0.1.0 技术原型](docs/02-v0.1.0技术原型.md)。

聚合面板阶段记录见 [v0.2.0 聚合面板原型](docs/03-v0.2.0聚合面板原型.md)。

本次产品模型重构记录见 [v0.3.0 产品模型重构](docs/04-v0.3.0产品模型重构.md)。旧文档保留为历史原型记录，其中出现的分割线、应用图标列表和 fallback 不代表当前产品设计。

执行引擎记录见 [v0.4.0 原始项目执行引擎](docs/05-v0.4.0原始项目执行引擎.md)。

紧凑面板视觉重构见 [v0.4.1 第二行菜单栏视觉重构](docs/06-v0.4.1第二行菜单栏视觉重构.md)。

当前固定产品基准与执行顺序见 [iBar 主交互与 Ice 能力融合规格](docs/07-iBar主交互与Ice能力融合规格-20260909.md)。

三分区执行内核与单项临时显示见 [v0.6.0 三分区与单项临时显示](docs/08-v0.6.0三分区与单项临时显示.md)。

自动恢复隐藏、图标预缓存与设置页重构见 [v0.7.0 自动执行与设置页重构](docs/09-v0.7.0自动执行与设置页重构.md)。

macOS 26 启动崩溃原因与修复见 [v0.7.1 macOS 26 启动崩溃修复](docs/10-v0.7.1-macOS26启动崩溃修复.md)。

收纳面板重复图标、失效占位和并发开关修复见 [v0.8.5 收纳面板状态一致性修复](docs/14-v0.8.5收纳面板状态一致性修复.md)。

无尖角品牌图标、菜单栏图标放大和干净打包修复见 [v0.8.6 品牌图标可读性优化](docs/15-v0.8.6品牌图标可读性优化.md)。

## 本地构建

```bash
xcodegen generate
xcodebuild -project MenuBarOrganizer.xcodeproj -scheme MenuBarOrganizer -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

当前可运行产物位于 `build/Build/Products/Debug/MenuBarOrganizer.app`。

固定测试入口是 `dist/TuckBar.app`。请始终从这个路径启动并授权，避免 macOS 把不同路径的构建识别为不同的权限对象。交付物使用 ZIP 保存，项目目录只保留一个当前 `.app`。

仓库建议名：`tuckbar`  
仓库简介：`A macOS menu bar organizer inspired by iBar and Ice. TuckBar automatically tucks away third-party menu bar items and lets you reveal and activate them from a compact panel.`
