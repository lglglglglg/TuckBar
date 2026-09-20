import SwiftUI

private enum PreferencesPage: String, CaseIterable, Identifiable {
    case general
    case layout
    case guide
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "通用设置"
        case .layout: "菜单栏布局"
        case .guide: "使用教程"
        case .about: "帮助与关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .layout: "menubar.rectangle"
        case .guide: "play.rectangle.fill"
        case .about: "info.circle.fill"
        }
    }
}

private enum LayoutFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case visible = "常显"
    case hidden = "已收纳"
    case alwaysHidden = "始终隐藏"

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let refreshItems: () -> Void
    let applyHiddenItems: () -> Void
    let revealAllItems: () -> Void
    let showAggregatePanel: () -> Void
    let requestScreenRecordingPermission: () -> Void
    let requestAccessibilityPermission: () -> Void
    let quit: () -> Void

    @State private var selectedPage: PreferencesPage = .general
    @State private var searchKeyword = ""
    @State private var layoutFilter: LayoutFilter = .all

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 185)

            ScrollView {
                pageContent
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.10))
        }
        .frame(width: 860, height: 620)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.21, blue: 0.50),
                    Color(red: 0.14, green: 0.44, blue: 0.48),
                    Color(red: 0.30, green: 0.17, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(nsImage: brandIcon)
                    .resizable()
                    .frame(width: 68, height: 68)
                Text(Brand.name)
                    .font(.headline)
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(.top, 42)
            .padding(.bottom, 26)

            VStack(spacing: 5) {
                ForEach(PreferencesPage.allCases) { page in
                    SidebarButton(
                        title: page.title,
                        symbol: page.symbol,
                        isSelected: selectedPage == page
                    ) {
                        selectedPage = page
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            Button(action: quit) {
                Label("退出应用", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .padding(12)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.12))
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .layout:
            layoutPage
        case .guide:
            guidePage
        case .about:
            aboutPage
        }
    }

    private var brandIcon: NSImage {
        guard let url = Bundle.main.url(forResource: "TuckBarBrand", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else { return Brand.image(size: 136, colored: true) }
        return image
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageTitle(symbol: "rocket.fill", title: "启动与常规")

            SettingsCard {
                Toggle("登录时自动启动 TuckBar", isOn: $model.launchAtLogin)
            }

            PageTitle(symbol: "slider.horizontal.3", title: "显示与交互")

            SettingsCard {
                Text("收纳显示模式").font(.headline)
                Picker("收纳显示模式", selection: $model.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.displayMode.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                Divider().overlay(.white.opacity(0.14))

                Text("菜单栏图标样式").font(.headline)
                Picker("菜单栏图标样式", selection: $model.iconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Divider().overlay(.white.opacity(0.14))

                Toggle("鼠标悬停在 TuckBar 图标时自动展开", isOn: $model.openOnHover)

                Toggle("在菜单栏区域滑动滚轮/双指手势展开或收起", isOn: $model.triggerOnScroll)

                Toggle(isOn: $model.enableGlobalHotkey) {
                    HStack {
                        Text("启用全局快捷键展开/收起")
                        Spacer()
                        Text("⌥ B")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                if model.displayMode == .menuBar {
                    Divider().overlay(.white.opacity(0.14))
                    HStack {
                        Text("展开后自动收起延时")
                        Spacer()
                        Picker("", selection: $model.autoCollapseDelay) {
                            Text("5 秒").tag(5.0)
                            Text("8 秒").tag(8.0)
                            Text("15 秒").tag(15.0)
                            Text("手动点击（不自动收起）").tag(0.0)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    .font(.callout)
                }
            }

            PageTitle(symbol: "key.fill", title: "系统授权")

            SettingsCard {
                PermissionRow(
                    title: "辅助功能",
                    detail: "用于移动、隐藏和点击真实菜单栏项目",
                    isGranted: model.hasAccessibilityPermission,
                    grant: requestAccessibilityPermission
                )
                Divider().overlay(.white.opacity(0.14))
                PermissionRow(
                    title: "屏幕录制",
                    detail: "用于读取菜单栏项目位置和原始图标，不保存桌面录像",
                    isGranted: model.hasScreenRecordingPermission,
                    grant: requestScreenRecordingPermission
                )
            }

            if !model.hasAccessibilityPermission || !model.hasScreenRecordingPermission {
                SettingsCard {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("部分权限尚未授予，请在上方完成授权以确保收纳正常运行。")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
    }

    private var layoutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageTitle(symbol: "menubar.rectangle", title: "菜单栏布局")

            Text("管理每一个真实菜单栏项目：常显、隐藏或始终隐藏。修改后实时生效。")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("搜索菜单栏项目名称或 Bundle ID…", text: $searchKeyword)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                    if !searchKeyword.isEmpty {
                        Button(action: { searchKeyword = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Picker("", selection: $layoutFilter) {
                    ForEach(LayoutFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            SettingsCard(padding: 0) {
                if manageableItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 32))
                        Text(searchKeyword.isEmpty ? "没有发现可管理的菜单栏项目" : "没有找到匹配的项目")
                        if searchKeyword.isEmpty {
                            Button("重新扫描", action: refreshItems)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, minHeight: 210)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(manageableItems.enumerated()), id: \.element.id) { index, item in
                            LayoutItemRow(
                                item: item,
                                placement: Binding(
                                    get: { model.placement(for: item) },
                                    set: { newPlacement in
                                        model.setPlacement(newPlacement, for: item)
                                        applyHiddenItems()
                                    }
                                )
                            )
                            if index < manageableItems.count - 1 {
                                Divider().overlay(.white.opacity(0.12))
                            }
                        }
                    }
                }
            }

            Text(model.operationMessage)
                .font(.callout.weight(.medium))
                .foregroundStyle(model.isHidingApplied ? Color.green.opacity(0.92) : .white.opacity(0.68))

            HStack(spacing: 10) {
                Button("重新扫描", action: refreshItems)
                Button("全部移入收纳") {
                    model.setAllPlacement(.hidden, for: manageableItems)
                    applyHiddenItems()
                }
                .disabled(manageableItems.isEmpty)

                Button("重新整理", action: applyHiddenItems)
                    .disabled(model.managedItems.isEmpty || !model.hasAccessibilityPermission)

                Spacer()

                Button("暂时展开全部", action: revealAllItems)
            }
            .buttonStyle(.bordered)
        }
    }

    private var guidePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "play.rectangle.fill", title: "使用教程与技巧")
            SettingsCard {
                GuideRow(number: "1", title: "系统授权", detail: "首次使用需授予“辅助功能”以操作原生图标，授予“屏幕录制”以高清渲染原始菜单栏图标。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "2", title: "按需展开 / 收起", detail: "左键点击 TuckBar 图标、或悬停、或在菜单栏区域滑动滚轮/触控板双指，即可流畅展开或收起隐藏图标。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "3", title: "全局快捷键 ⌥ B", detail: "在任何应用全屏或专注状态下，直接按下 Option + B（⌥ B）即可瞬间呼出菜单栏收纳。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "4", title: "右键菜单与分区控制", detail: "右键 TuckBar 图标可唤出快捷功能；在布局设置或浮窗中可将图标设为常显、隐藏或始终隐藏。")
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "info.circle.fill", title: "帮助与关于")
            SettingsCard {
                Text("启动后自动收纳第三方图标。在“菜单栏布局”中选择常显、隐藏或始终隐藏，修改会自动应用。")
                Text("点击或悬停 TuckBar 图标展开收纳条，再点击图标打开原菜单。“始终隐藏”的项目不会出现在收纳条中。")
                    .foregroundStyle(.white.opacity(0.72))
            }
            SettingsCard {
                StatusRow(title: "软件名称", value: Brand.name)
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "当前版本", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.7") (Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "36"))")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "系统要求", value: "macOS 14 (Sonoma) 或更高版本")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "数据存储", value: "全部保存在本机沙盒，无需网络连接")
                Divider().overlay(.white.opacity(0.14))
                HStack {
                    Text("开源代码仓库")
                    Spacer()
                    Link(destination: URL(string: "https://github.com/lglglglglg/TuckBar")!) {
                        HStack(spacing: 4) {
                            Text("GitHub")
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                    }
                    .font(.callout.weight(.medium))
                }
            }
        }
    }

    private var manageableItems: [MenuBarItemDescriptor] {
        let base = model.discoveredItems.filter { !$0.identifier.hasPrefix("unidentified.") }
        let filteredByTab: [MenuBarItemDescriptor]
        switch layoutFilter {
        case .all:
            filteredByTab = base
        case .visible:
            filteredByTab = base.filter { model.placement(for: $0) == .visible }
        case .hidden:
            filteredByTab = base.filter { model.placement(for: $0) == .hidden }
        case .alwaysHidden:
            filteredByTab = base.filter { model.placement(for: $0) == .alwaysHidden }
        }

        let keyword = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return filteredByTab }
        return filteredByTab.filter {
            $0.displayName.lowercased().contains(keyword) ||
            $0.identifier.lowercased().contains(keyword)
        }
    }
}

private struct SidebarButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    isSelected ? .white.opacity(0.19) : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PageTitle: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }
}

private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

private struct ActionRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            trailing
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            if isGranted {
                Text("已授权")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("去授权", action: grant)
            }
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

private struct LayoutItemRow: View {
    let item: MenuBarItemDescriptor
    @Binding var placement: MenuBarItemPlacement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.12))
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.callout.weight(.medium))
                    if item.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .help("运行中")
                    }
                    placementBadge
                }
                Text(item.identifier)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }
            Spacer()
            Picker("分区", selection: $placement) {
                ForEach(MenuBarItemPlacement.allCases) { placement in
                    Text(placement.title).tag(placement)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 116)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var placementBadge: some View {
        switch placement {
        case .visible:
            Text("常显")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.green.opacity(0.9))
        case .hidden:
            Text("已收纳")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.orange.opacity(0.9))
        case .alwaysHidden:
            Text("始终隐藏")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.purple.opacity(0.9))
        }
    }
}

private struct GuideRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}
