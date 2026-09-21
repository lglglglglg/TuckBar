import SwiftUI

private enum PreferencesPage: String, CaseIterable, Identifiable {
    case general
    case guide
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "通用设置"
        case .guide: "使用教程"
        case .about: "帮助与关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .guide: "play.rectangle.fill"
        case .about: "info.circle.fill"
        }
    }
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
                GuideRow(number: "4", title: "快捷菜单与重新扫描", detail: "右键 TuckBar 图标可唤出快捷功能菜单，随时进行重新扫描、收起或暂时展开全部。")
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "info.circle.fill", title: "帮助与关于")
            SettingsCard {
                Text("启动后自动收纳第三方图标，无需繁琐配置，开箱即用。")
                Text("点击或悬停 TuckBar 图标展开收纳条，再次点击图标即可直接打开原应用菜单。")
                    .foregroundStyle(.white.opacity(0.72))
            }
            SettingsCard {
                StatusRow(title: "软件名称", value: Brand.name)
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "当前版本", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.7") (Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "36"))")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "工作室", value: "韩十久工作室 (Hanshijiu Studio)")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "主理人", value: "Stephan Li")
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
