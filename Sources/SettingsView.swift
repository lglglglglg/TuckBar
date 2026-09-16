import SwiftUI

private enum PreferencesPage: String, CaseIterable, Identifiable {
    case general
    case layout
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "通用设置"
        case .layout: "菜单栏布局"
        case .about: "帮助与关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .layout: "menubar.rectangle"
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
                    .padding(.horizontal, 26)
                    .padding(.top, 32)
                    .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.10))
        }
        .frame(width: 780, height: 550)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.31, green: 0.23, blue: 0.55),
                    Color(red: 0.15, green: 0.49, blue: 0.52),
                    Color(red: 0.34, green: 0.19, blue: 0.48)
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
            PageTitle(symbol: "rocket.fill", title: "启动与显示")

            SettingsCard {
                Toggle("悬停 TuckBar 图标时展开收纳条", isOn: $model.openOnHover)
                Text("启动后自动收纳；点击菜单栏 TuckBar 图标即可展开。")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }

            PageTitle(symbol: "key.fill", title: "授权")

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

            SettingsCard {
                Text("运行状态").font(.headline)
                Text(model.operationMessage)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var layoutPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "menubar.rectangle", title: "菜单栏布局")

            Text("把每一个真实菜单栏项目放进常显、隐藏或始终隐藏区域。修改后会自动应用。")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))

            SettingsCard(padding: 0) {
                if manageableItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 32))
                        Text("没有发现可管理的菜单栏项目")
                        Button("重新扫描", action: refreshItems)
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

            HStack {
                Button("重新扫描", action: refreshItems)
                Button("重新整理", action: applyHiddenItems)
                    .disabled(model.managedItems.isEmpty || !model.hasAccessibilityPermission)
                Button("暂时展开全部", action: revealAllItems)
            }
            .buttonStyle(.bordered)
        }
    }

    private var guidePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "play.rectangle.fill", title: "使用教程")
            SettingsCard {
                GuideRow(number: "1", title: "完成授权", detail: "辅助功能负责操作原项目，屏幕录制负责显示原图标。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "2", title: "选择项目分区", detail: "隐藏项目进入聚合条；始终隐藏项目不会出现在聚合条。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "3", title: "打开聚合条", detail: "点击或悬停菜单栏双箭头，点击图标即可操作原生菜单。")
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
                StatusRow(title: "版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "系统要求", value: "macOS 14 或更高版本")
                Divider().overlay(.white.opacity(0.14))
                StatusRow(title: "数据", value: "全部保存在本机")
            }
        }
    }

    private var manageableItems: [MenuBarItemDescriptor] {
        model.discoveredItems.filter { !$0.identifier.hasPrefix("unidentified.") }
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
                    .fill(.white.opacity(0.10))
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.callout.weight(.medium))
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
        .padding(.vertical, 11)
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
